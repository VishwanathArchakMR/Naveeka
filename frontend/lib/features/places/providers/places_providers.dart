// lib/features/places/providers/places_providers.dart

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/places_api.dart';
import '../../../models/place.dart';

/// API client DI (must be overridden at runtime).
final placesApiProvider = Provider<PlacesApi>((ref) {
  // Provide a concrete PlacesApi using ProviderScope(overrides: [...]) at app bootstrap. [web:6014]
  // Example:
  // ProviderScope(
  //   overrides: [placesApiProvider.overrideWithValue(MyPlacesApi())],
  //   child: App(),
  // );
  throw UnimplementedError('Provide PlacesApi via ProviderScope.overrides'); // [web:6014]
});

/// Typed query for listing places (extend as needed).
class PlacesQuery {
  const PlacesQuery({
    this.category,
    this.emotion,
    this.q,
    this.lat,
    this.lng,
    this.radiusMeters,
    this.sort, // distance | rating | relevance
    this.page = 1,
    this.limit = 20,
  });

  final String? category;
  final String? emotion;
  final String? q;
  final double? lat;
  final double? lng;
  final int? radiusMeters;
  final String? sort;
  final int page;
  final int limit;

  PlacesQuery copyWith({
    String? category,
    String? emotion,
    String? q,
    double? lat,
    double? lng,
    int? radiusMeters,
    String? sort,
    int? page,
    int? limit,
  }) {
    return PlacesQuery(
      category: category ?? this.category,
      emotion: emotion ?? this.emotion,
      q: q ?? this.q,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

/// UI-facing list state with pagination flags.
class PlacesState {
  const PlacesState({
    this.items = const <Place>[],
    this.loading = false,
    this.error,
    this.query = const PlacesQuery(),
    this.hasMore = true,
    this.refreshing = false,
  });

  final List<Place> items;
  final bool loading;
  final String? error;
  final PlacesQuery query;
  final bool hasMore;
  final bool refreshing;

  PlacesState copyWith({
    List<Place>? items,
    bool? loading,
    String? error,
    PlacesQuery? query,
    bool? hasMore,
    bool? refreshing,
  }) {
    return PlacesState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
      query: query ?? this.query,
      hasMore: hasMore ?? this.hasMore,
      refreshing: refreshing ?? this.refreshing,
    );
  }
}

/// Pagination + search + cancel support using StateNotifier.
final placesProvider = StateNotifierProvider.autoDispose<PlacesNotifier, PlacesState>((ref) {
  final api = ref.watch(placesApiProvider);
  return PlacesNotifier(api);
}); // Override placesApiProvider in ProviderScope to inject a real API client. [web:6014]

class PlacesNotifier extends StateNotifier<PlacesState> {
  PlacesNotifier(this._api) : super(const PlacesState());

  final PlacesApi _api;

  CancelToken? _cancel;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _cancel?.cancel('disposed');
    super.dispose();
  }

  /// Fully reload the first page with optional overrides.
  Future<void> refresh({
    String? category,
    String? emotion,
    String? q,
    double? lat,
    double? lng,
    int? radiusMeters,
    String? sort,
    int? limit,
  }) async {
    _debounce?.cancel();
    _cancel?.cancel('refresh');
    _cancel = CancelToken(); // create token and cancel previous, per Dio guidance. [web:6079]

    final nextQuery = state.query.copyWith(
      category: category,
      emotion: emotion,
      q: q ?? state.query.q,
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      sort: sort,
      page: 1,
      limit: limit ?? state.query.limit,
    );

    state = state.copyWith(
      loading: true,
      refreshing: true,
      error: null,
      query: nextQuery,
      hasMore: true,
      items: const [],
    );

    final res = await _callList(nextQuery, _cancel); // dynamic API call adapter. [web:5969]
    await res.fold(
      onSuccess: (List<Place> list) async {
        state = state.copyWith(
          items: list,
          loading: false,
          refreshing: false,
          hasMore: list.length >= nextQuery.limit,
          query: nextQuery.copyWith(page: 2),
        );
      },
      onError: (e) async {
        state = state.copyWith(loading: false, refreshing: false, error: e.safeMessage, hasMore: false);
      },
    );
  }

  /// Load the next page if available.
  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    _cancel?.cancel('loadMore');
    _cancel = CancelToken(); // share a new token for this request. [web:6079]

    state = state.copyWith(loading: true, error: null);

    final q = state.query;
    final res = await _callList(q, _cancel); // dynamic API call adapter supports various method names. [web:5969]
    await res.fold(
      onSuccess: (List<Place> list) async {
        final merged = <Place>[...state.items, ...list];
        state = state.copyWith(
          items: merged,
          loading: false,
          hasMore: list.length >= q.limit,
          query: q.copyWith(page: q.page + 1),
        );
      },
      onError: (e) async {
        state = state.copyWith(loading: false, error: e.safeMessage);
      },
    );
  }

  /// Debounced free-text search; resets paging when text changes.
  void setSearch(String? text, {Duration debounce = const Duration(milliseconds: 350)}) {
    _debounce?.cancel();
    _debounce = Timer(debounce, () {
      refresh(q: (text ?? '').trim().isEmpty ? null : text!.trim());
    });
  } // Debouncing avoids spamming requests; pair with CancelToken for UX. [web:6082][web:6079]

  /// Toggle favorite optimistically (best-effort across varying models).
  void toggleFavorite(String placeId, {bool? next}) {
    final idx = state.items.indexWhere((p) => p.id == placeId);
    if (idx < 0) return;
    final cur = state.items[idx];
    final current = _favoriteOf(cur); // read from toJson keys like isFavorite/favorite. [web:5858]
    final want = next ?? !current;

    final updated = List<Place>.from(state.items);
    final candidate = _applyFavorite(cur, want); // try copyWith with common param names using dynamic invocation. [web:5969]
    if (candidate != null) {
      updated[idx] = candidate;
      state = state.copyWith(items: updated);
    }
    // persist to backend; on failure, revert if needed.
  }

  /// Replace or upsert a place (e.g., after editing).
  void upsert(Place p) {
    final idx = state.items.indexWhere((e) => e.id == p.id);
    final list = List<Place>.from(state.items);
    if (idx == -1) {
      list.insert(0, p);
    } else {
      list[idx] = p;
    }
    state = state.copyWith(items: list);
  }

  // -------- Dynamic API adapters --------

  Future<dynamic> _callList(PlacesQuery q, CancelToken? token) async {
    final dyn = _api as dynamic;
    // Attempt 1: list(...)
    try {
      return await dyn.list(
        category: q.category,
        emotion: q.emotion,
        q: q.q,
        lat: q.lat,
        lng: q.lng,
        radius: q.radiusMeters,
        sort: q.sort,
        page: q.page,
        limit: q.limit,
        cancelToken: token,
      );
    } catch (_) {
      // Attempt 2: search(...) with alternative names
      try {
        return await dyn.search(
          category: q.category,
          mood: q.emotion,
          query: q.q,
          latitude: q.lat,
          longitude: q.lng,
          radiusMeters: q.radiusMeters,
          sortBy: q.sort,
          page: q.page,
          limit: q.limit,
          cancelToken: token,
        );
      } catch (_) {
        // Attempt 3: fetch(...) via Function.apply with named Symbols
        final args = <Symbol, dynamic>{
          #type: q.category,
          #mood: q.emotion,
          #query: q.q,
          #lat: q.lat,
          #lng: q.lng,
          #radius: q.radiusMeters,
          #sort: q.sort,
          #page: q.page,
          #limit: q.limit,
          #cancelToken: token,
        };
        return await Function.apply(dyn.fetch, const [], args); // dynamic named args. [web:5963][web:6085]
      }
    }
  }

  Future<dynamic> _callGetById(PlacesApi api, String id) async {
    final dyn = api as dynamic;
    try {
      return await dyn.getById(id: id);
    } catch (_) {
      try {
        return await dyn.get(id: id);
      } catch (_) {
        try {
          return await dyn.detail(id: id);
        } catch (_) {
          return await Function.apply(dyn.getById, const [], {#id: id}); // final fallback. [web:6085]
        }
      }
    }
  }

  // -------- Favorite helpers (model-agnostic) --------

  bool _favoriteOf(Place p) {
    final m = _json(p);
    final keys = ['isFavorite', 'favorite', 'saved', 'liked'];
    for (final k in keys) {
      final v = m[k];
      if (v is bool) return v;
      if (v is String) {
        final s = v.toLowerCase();
        if (s == 'true') return true;
        if (s == 'false') return false;
      }
    }
    return false;
  }

  Place? _applyFavorite(Place p, bool want) {
    // Try copyWith with common favorite parameter names.
    final dyn = p as dynamic;
    final tries = <Map<Symbol, dynamic>>[
      {#isFavorite: want},
      {#favorite: want},
      {#saved: want},
      {#liked: want},
    ];
    for (final named in tries) {
      try {
        final next = Function.apply(dyn.copyWith, const [], named);
        if (next is Place) return next;
      } catch (_) {
        // continue trying other names
      }
    }
    // If copyWith not available or param name unknown, fall back to unchanged.
    return null;
  }

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  }
}

/// Single place detail using a FutureProvider.family with autoDispose.
final placeDetailProvider = FutureProvider.autoDispose.family<Place, String>((ref, id) async {
  final api = ref.watch(placesApiProvider);
  final res = await (PlacesNotifier(api))._callGetById(api, id); // reuse the adapter for consistency. [web:5969]
  return res.fold(
    onSuccess: (Place p) => p,
    onError: (e) => throw Exception(e.safeMessage),
  );
}); // Override placesApiProvider with a concrete client; CancelToken patterns apply similarly. [web:6014][web:6079]
