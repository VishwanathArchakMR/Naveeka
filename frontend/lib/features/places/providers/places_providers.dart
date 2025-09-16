// lib/features/places/providers/places_providers.dart

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/places_api.dart';
import '../../../models/place.dart';

/// API client DI
final placesApiProvider = Provider<PlacesApi>((ref) => PlacesApi()); // State is injected once and used across notifiers. [2]

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
/// autoDispose ensures the notifier is disposed when the screen goes away. [20]
final placesProvider = StateNotifierProvider.autoDispose<PlacesNotifier, PlacesState>((ref) {
  final api = ref.watch(placesApiProvider);
  return PlacesNotifier(ref, api);
}); // StateNotifierProvider is suited for immutable state with business logic centralized in methods. [1][2]

class PlacesNotifier extends StateNotifier<PlacesState> {
  PlacesNotifier(this._ref, this._api) : super(const PlacesState());

  final Ref _ref;
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
  Future<void> refresh({String? category, String? emotion, String? q, double? lat, double? lng, int? radiusMeters, String? sort, int? limit}) async {
    _debounce?.cancel();
    _cancel?.cancel('refresh');
    _cancel = CancelToken();

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

    state = state.copyWith(loading: true, refreshing: true, error: null, query: nextQuery, hasMore: true, items: const []);
    final res = await _api.list(
      category: nextQuery.category,
      emotion: nextQuery.emotion,
      q: nextQuery.q,
      lat: nextQuery.lat,
      lng: nextQuery.lng,
      radius: nextQuery.radiusMeters,
      page: nextQuery.page,
      limit: nextQuery.limit,
      cancelToken: _cancel,
    ); // Paged list reads params from query and forwards CancelToken to enable cancellation on dispose. [2]

    await res.fold(
      onSuccess: (list) async {
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
    _cancel = CancelToken();

    state = state.copyWith(loading: true, error: null);

    final q = state.query;
    final res = await _api.list(
      category: q.category,
      emotion: q.emotion,
      q: q.q,
      lat: q.lat,
      lng: q.lng,
      radius: q.radiusMeters,
      page: q.page,
      limit: q.limit,
      cancelToken: _cancel,
    ); // Continuation calls next page from the stored query; results are appended on success. [7]

    await res.fold(
      onSuccess: (list) async {
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
  } // Debouncing search input avoids firing excess API calls as the user types. [7][18]

  /// Toggle favorite optimistically.
  void toggleFavorite(String placeId, {bool? next}) {
    final idx = state.items.indexWhere((p) => p.id == placeId);
    if (idx < 0) return;
    final cur = state.items[idx];
    final want = next ?? !(cur.isFavorite ?? false);
    final updated = List<Place>.from(state.items);
    updated[idx] = cur.copyWith(isFavorite: want);
    state = state.copyWith(items: updated);
    // TODO: call backend to persist; on error, revert and set error string.
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
}

/// Single place detail using a FutureProvider.family with autoDispose.
/// This caches per-id and disposes when unobserved. [15][17]
final placeDetailProvider = FutureProvider.autoDispose.family<Place, String>((ref, id) async {
  final api = ref.watch(placesApiProvider);
  final res = await api.getById(id);
  return res.fold(
    onSuccess: (p) => p,
    onError: (e) => throw Exception(e.safeMessage),
  );
}); // Family lets providers parameterize by id, with per-argument caching and cleanup when no longer needed. [12][17]
