// lib/features/trails/providers/trails_providers.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/trails_api.dart' as trails;
import '../data/trail_location_api.dart' as location;
import '../../../models/geo_point.dart'; // models.GeoPoint with latitude/longitude

/// ---------------- Dependency injection ----------------

/// Provide a concrete TrailsApi (override at app bootstrap).
final trailsApiProvider = Provider<trails.TrailsApi>((ref) {
  throw UnimplementedError('Override trailsApiProvider with a real TrailsApi');
});

/// Provide a concrete TrailLocationApi (override at app bootstrap).
final trailLocationApiProvider = Provider<location.TrailLocationApi>((ref) {
  throw UnimplementedError('Override trailLocationApiProvider with a real TrailLocationApi');
});

/// ---------------- Filters and shared view state ----------------

@immutable
class TrailsFilters {
  const TrailsFilters({
    this.query = '',
    this.difficulties = const <String>{}, // 'easy' | 'moderate' | 'hard'
    this.viewMode = TrailsViewMode.list,
    this.center,
    this.radiusKm,
  });

  final String query;
  final Set<String> difficulties;
  final TrailsViewMode viewMode;
  final GeoPoint? center; // models.GeoPoint
  final double? radiusKm;

  TrailsFilters copyWith({
    String? query,
    Set<String>? difficulties,
    TrailsViewMode? viewMode,
    GeoPoint? center,
    double? radiusKm,
  }) {
    return TrailsFilters(
      query: query ?? this.query,
      difficulties: difficulties ?? this.difficulties,
      viewMode: viewMode ?? this.viewMode,
      center: center ?? this.center,
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }
}

/// Mirrors the UI enum for list/map toggle (kept here for provider-only reuse).
enum TrailsViewMode { list, map }

/// Single source of truth for filters; screens/widgets read/write this to coordinate.
final trailsFiltersProvider = StateProvider<TrailsFilters>((ref) => const TrailsFilters());

/// ---------------- Generic paged state ----------------

@immutable
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.cursor,
    required this.loading,
    this.error,
  });

  final List<T> items;
  final String? cursor;
  final bool loading;
  final Object? error;

  PagedState<T> copy({List<T>? items, String? cursor, bool? loading, Object? error}) => PagedState<T>(
        items: items ?? this.items,
        cursor: cursor ?? this.cursor,
        loading: loading ?? this.loading,
        error: error,
      );

  static PagedState<T> empty<T>() => PagedState<T>(
        items: List<T>.empty(growable: false),
        cursor: null,
        loading: false,
      );
}

/// ---------------- Trails list controller (filters -> paged list) ----------------

class TrailsListController extends AsyncNotifier<PagedState<trails.TrailSummary>> {
  trails.TrailsApi get _api => ref.read(trailsApiProvider);

  @override
  FutureOr<PagedState<trails.TrailSummary>> build() async {
    // Rebuild automatically when filters change; this sets up the dependency.
    final f = ref.watch(trailsFiltersProvider);
    final page = await _api.list(
      query: f.query.isEmpty ? null : f.query,
      center: f.center, // models.GeoPoint expected by TrailsApi
      radiusKm: f.radiusKm,
      tags: null,
      difficulty: f.difficulties.isEmpty ? null : f.difficulties.join(','),
      minRating: null,
      limit: 20,
      cursor: null,
    );
    return PagedState<trails.TrailSummary>(
      items: page.items,
      cursor: page.nextCursor,
      loading: false,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final f = ref.read(trailsFiltersProvider);
    final page = await _api.list(
      query: f.query.isEmpty ? null : f.query,
      center: f.center,
      radiusKm: f.radiusKm,
      tags: null,
      difficulty: f.difficulties.isEmpty ? null : f.difficulties.join(','),
      minRating: null,
      limit: 20,
      cursor: null,
    );
    state = AsyncData(
      PagedState<trails.TrailSummary>(
        items: page.items,
        cursor: page.nextCursor,
        loading: false,
      ),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? PagedState.empty<trails.TrailSummary>();
    if (current.loading || current.cursor == null) return;
    state = AsyncData(current.copy(loading: true));
    final f = ref.read(trailsFiltersProvider);
    try {
      final page = await _api.list(
        query: f.query.isEmpty ? null : f.query,
        center: f.center,
        radiusKm: f.radiusKm,
        tags: null,
        difficulty: f.difficulties.isEmpty ? null : f.difficulties.join(','),
        minRating: null,
        limit: 20,
        cursor: current.cursor,
      );
      state = AsyncData(
        current.copy(
          items: [...current.items, ...page.items],
          cursor: page.nextCursor,
          loading: false,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      state = AsyncData(current.copy(loading: false, error: e));
    }
  }
}

final trailsListControllerProvider =
    AsyncNotifierProvider<TrailsListController, PagedState<trails.TrailSummary>>(TrailsListController.new);

/// ---------------- Trail detail & geometry ----------------

/// Fetch full detail for a trail by id; simple FutureProvider is sufficient.
final trailDetailProvider = FutureProvider.family<trails.TrailDetail, String>((ref, trailId) async {
  final api = ref.watch(trailsApiProvider);
  return api.getTrail(trailId);
});

/// Fetch geometry points for a trail; uses TrailLocationApi if a separate geometry endpoint is preferred.
final trailGeometryProvider = FutureProvider.family<List<GeoPoint>, String>((ref, trailId) async {
  final loc = ref.watch(trailLocationApiProvider);
  final pts = await loc.getGeometry(trailId); // List<location.GeoPoint>
  return pts.map((p) => GeoPoint(latitude: p.lat, longitude: p.lng)).toList(growable: false);
});

/// Fetch aggregated stats for a trail (review count, rating, favorites).
final trailStatsProvider = FutureProvider.family<trails.TrailStats, String>((ref, trailId) async {
  final api = ref.watch(trailsApiProvider);
  return api.getStats(trailId);
});

/// ---------------- Reviews pagination per trail ----------------

class TrailReviewsController extends FamilyAsyncNotifier<PagedState<trails.TrailReview>, String> {
  trails.TrailsApi get _api => ref.read(trailsApiProvider);

  @override
  FutureOr<PagedState<trails.TrailReview>> build(String trailId) async {
    return PagedState.empty<trails.TrailReview>();
  }

  Future<void> refresh({String? sort}) async {
    state = const AsyncLoading();
    final page = await _api.getReviews(trailId: arg, limit: 20, cursor: null, sort: sort);
    state = AsyncData(
      PagedState<trails.TrailReview>(
        items: page.items,
        cursor: page.nextCursor,
        loading: false,
      ),
    );
  }

  Future<void> loadMore({String? sort}) async {
    final current = state.valueOrNull ?? PagedState.empty<trails.TrailReview>();
    if (current.loading || current.cursor == null) return;
    state = AsyncData(current.copy(loading: true));
    try {
      final page = await _api.getReviews(trailId: arg, limit: 20, cursor: current.cursor, sort: sort);
      state = AsyncData(
        current.copy(
          items: [...current.items, ...page.items],
          cursor: page.nextCursor,
          loading: false,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      state = AsyncData(current.copy(loading: false, error: e));
    }
  }
}

final trailReviewsControllerProvider =
    AsyncNotifierProvider.family<TrailReviewsController, PagedState<trails.TrailReview>, String>(
        TrailReviewsController.new);

/// ---------------- Nearby trails ----------------

/// Quick nearby lookup around a center within radius; returns a sorted, truncated list.
final nearbyTrailsProvider =
    FutureProvider.family<List<location.TrailSummary>, ({GeoPoint center, double radiusKm, List<String>? tags})>(
  (ref, args) async {
    final loc = ref.watch(trailLocationApiProvider);
    // Convert models.GeoPoint -> location.GeoPoint; models uses named latitude/longitude
    final centerPoint = location.GeoPoint(args.center.latitude, args.center.longitude);
    // Return the native location summaries to avoid field mismatches
    return loc.nearby(
      center: centerPoint,
      radiusKm: args.radiusKm,
      limit: 50,
      tags: args.tags,
    );
  },
);

/// ---------------- Quick actions (favorite, helpful, post review) ----------------

/// Toggle favorite for a trail; returns final favorite state.
final toggleFavoriteProvider =
    FutureProvider.family.autoDispose<bool, ({String trailId, bool next})>((ref, args) async {
  final api = ref.watch(trailsApiProvider);
  return api.toggleFavorite(trailId: args.trailId, nextValue: args.next);
});

/// Mark/unmark a review as helpful; returns server-accepted state (true if helpful).
final toggleReviewHelpfulProvider =
    FutureProvider.family.autoDispose<bool, ({String trailId, String reviewId, bool next})>(
  (ref, args) async {
    final api = ref.watch(trailsApiProvider);
    return api.toggleReviewHelpful(
      trailId: args.trailId,
      reviewId: args.reviewId,
      nextValue: args.next,
    );
  },
);

/// Post a text/rating review (photos handled by higher-level screen if needed).
final postReviewProvider =
    FutureProvider.family.autoDispose<trails.TrailReview, ({String trailId, int rating, String text})>(
  (ref, args) async {
    final api = ref.watch(trailsApiProvider);
    return api.postReview(
      trailId: args.trailId,
      rating: args.rating,
      text: args.text,
      photoFiles: null,
    );
  },
);

/// ---------------- Facade for widgets/screens ----------------

typedef Reader = T Function<T>(ProviderListenable<T> provider);

class TrailsActions {
  TrailsActions(this._read);
  final Reader _read;

  // Filters
  void setQuery(String q) {
    final curr = _read(trailsFiltersProvider);
    _read(trailsFiltersProvider.notifier).state = curr.copyWith(query: q.trim());
  }

  void toggleDifficulty(String key, bool next) {
    final curr = _read(trailsFiltersProvider);
    final set = <String>{...curr.difficulties};
    if (next) {
      set.add(key);
    } else {
      set.remove(key);
    }
    _read(trailsFiltersProvider.notifier).state = curr.copyWith(difficulties: set);
  }

  void setViewMode(TrailsViewMode m) {
    final curr = _read(trailsFiltersProvider);
    _read(trailsFiltersProvider.notifier).state = curr.copyWith(viewMode: m);
  }

  void setCenter(GeoPoint? c, {double? radiusKm}) {
    final curr = _read(trailsFiltersProvider);
    _read(trailsFiltersProvider.notifier).state =
        curr.copyWith(center: c, radiusKm: radiusKm ?? curr.radiusKm);
  }

  // List
  Future<void> refreshList() => _read(trailsListControllerProvider.notifier).refresh();
  Future<void> loadMoreList() => _read(trailsListControllerProvider.notifier).loadMore();

  // Reviews (family controller)
  Future<void> initReviews(String trailId) => _read(trailReviewsControllerProvider(trailId).notifier).refresh();
  Future<void> refreshReviews(String trailId, {String? sort}) =>
      _read(trailReviewsControllerProvider(trailId).notifier).refresh(sort: sort);
  Future<void> loadMoreReviews(String trailId, {String? sort}) =>
      _read(trailReviewsControllerProvider(trailId).notifier).loadMore(sort: sort);

  // Actions
  Future<bool> toggleFavorite(String trailId, bool next) =>
      _read(toggleFavoriteProvider((trailId: trailId, next: next)).future);
  Future<bool> toggleReviewHelpful(String trailId, String reviewId, bool next) =>
      _read(toggleReviewHelpfulProvider((trailId: trailId, reviewId: reviewId, next: next)).future);
  Future<trails.TrailReview> postReview(String trailId, int rating, String text) =>
      _read(postReviewProvider((trailId: trailId, rating: rating, text: text)).future);
}

final trailsActionsProvider = Provider<TrailsActions>((ref) => TrailsActions(ref.read));
