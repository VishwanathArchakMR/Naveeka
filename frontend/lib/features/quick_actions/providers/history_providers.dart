// lib/features/quick_actions/providers/history_providers.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ---------------- Domain models (align with your backend DTOs) ----------------

@immutable
class HistoryFilterSelection {
  const HistoryFilterSelection({
    this.start, // inclusive UTC
    this.end, // exclusive UTC
    this.query,
    this.transportModes = const <String>{}, // e.g., walk, bike, car...
  });

  final DateTime? start;
  final DateTime? end;
  final String? query;
  final Set<String> transportModes;

  HistoryFilterSelection copyWith({
    DateTime? start,
    DateTime? end,
    String? query,
    Set<String>? transportModes,
  }) {
    return HistoryFilterSelection(
      start: start ?? this.start,
      end: end ?? this.end,
      query: query ?? this.query,
      transportModes: transportModes ?? this.transportModes,
    );
  }
}

/// Map point for HistoryMapView.
@immutable
class HistoryPoint {
  const HistoryPoint({
    required this.id,
    required this.lat,
    required this.lng,
    required this.title,
    this.subtitle,
    this.occurredAt,
  });

  final String id;
  final double lat;
  final double lng;
  final String title;
  final String? subtitle;
  final DateTime? occurredAt;
}

/// Route/timeline item.
@immutable
class RouteHistoryItem {
  const RouteHistoryItem({
    required this.id,
    required this.day, // local day bucket
    required this.label,
    this.notes,
    this.distanceKm,
    this.durationMin,
  });

  final DateTime day; // bucketed by local Y/M/D
  final String id;
  final String label;
  final String? notes;
  final double? distanceKm;
  final int? durationMin;
}

/// Transport segment (used by TransportHistory widget).
@immutable
class TransportSegment {
  const TransportSegment({
    required this.id,
    required this.mode, // one of: walk/bike/car/taxi/bus/metro/train/flight
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    this.co2Kg,
    this.from,
    this.to,
    this.notes,
  });

  final String id;
  final String mode;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final double? co2Kg;
  final String? from;
  final String? to;
  final String? notes;
}

/// Visited place row (used by VisitedPlaces widget).
@immutable
class VisitedPlaceRow {
  const VisitedPlaceRow({
    required this.placeId,
    required this.name,
    required this.lastVisited,
    required this.totalVisits,
    this.photos = const <String>[],
    this.lat,
    this.lng,
    this.priceFrom,
    this.isFavorite,
  });

  final String placeId;
  final String name;
  final DateTime lastVisited;
  final int totalVisits;
  final List<String> photos;
  final double? lat;
  final double? lng;
  final String? priceFrom;
  final bool? isFavorite;
}

/// ---------------- Repository contract ----------------

enum HistoryType { mapPoints, route, transport, places }

@immutable
class HistoryPage<T> {
  const HistoryPage({required this.items, this.nextCursor});
  final List<T> items;
  final String? nextCursor;

  HistoryPage<T> merge(HistoryPage<T> next) => HistoryPage<T>(items: [...items, ...next.items], nextCursor: next.nextCursor);
}

abstract class HistoryRepository {
  Future<HistoryPage<HistoryPoint>> listPoints({
    required HistoryFilterSelection filters,
    String? cursor,
    int limit = 200,
  });

  Future<HistoryPage<RouteHistoryItem>> listRoute({
    required HistoryFilterSelection filters,
    String? cursor,
    int limit = 100,
  });

  Future<HistoryPage<TransportSegment>> listTransport({
    required HistoryFilterSelection filters,
    String? cursor,
    int limit = 200,
  });

  Future<HistoryPage<VisitedPlaceRow>> listPlaces({
    required HistoryFilterSelection filters,
    String? cursor,
    int limit = 40,
  });

  Future<void> clearDay(DateTime dayLocal);
  Future<void> clearAll({DateTime? start, DateTime? end});
}

/// Inject your concrete implementation at app bootstrap with overrideWithValue.
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  throw UnimplementedError('Provide HistoryRepository via override');
}); // A repository Provider centralizes data access and is easily overridden for tests/app bootstrap. [15][21]

/// ---------------- Filters and simple read-only providers ----------------

/// App-wide filters value; screens/widgets can watch or update this.
final historyFiltersProvider = StateProvider<HistoryFilterSelection>((ref) {
  return const HistoryFilterSelection();
}); // A StateProvider holds the current filters that downstream providers read from. [15][9]

/// First page read-only fetches (cacheable) per type.
final historyPointsFirstPageProvider = FutureProvider.autoDispose<HistoryPage<HistoryPoint>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  final f = ref.watch(historyFiltersProvider);
  return repo.listPoints(filters: f, cursor: null);
}); // FutureProvider is ideal for single-shot async fetches with caching and autoDispose lifecycles. [15][9]

final routeFirstPageProvider = FutureProvider.autoDispose<HistoryPage<RouteHistoryItem>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  final f = ref.watch(historyFiltersProvider);
  return repo.listRoute(filters: f, cursor: null);
}); // These per-type providers separate concerns and keep call-sites concise. [15][9]

final transportFirstPageProvider = FutureProvider.autoDispose<HistoryPage<TransportSegment>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  final f = ref.watch(historyFiltersProvider);
  return repo.listTransport(filters: f, cursor: null);
}); // Family modifiers are not needed here since filters are globally provided, but families are available if needed. [15][9]

final placesFirstPageProvider = FutureProvider.autoDispose<HistoryPage<VisitedPlaceRow>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  final f = ref.watch(historyFiltersProvider);
  return repo.listPlaces(filters: f, cursor: null);
}); // Reading filters inside keeps a single source of truth and consistent caching behavior. [15][9]

/// ---------------- Controllers for pagination and mutations ----------------

@immutable
class PagedState<T> {
  const PagedState({required this.items, required this.cursor, required this.loading, this.error});
  final List<T> items;
  final String? cursor;
  final bool loading;
  final Object? error;

  PagedState<T> copy({List<T>? items, String? cursor, bool? loading, Object? error}) =>
      PagedState<T>(items: items ?? this.items, cursor: cursor ?? this.cursor, loading: loading ?? this.loading, error: error);

  static PagedState<T> empty<T>() => PagedState<T>(items: const <T>[], cursor: null, loading: false);
}

/// Map points controller
class PointsController extends AsyncNotifier<PagedState<HistoryPoint>> {
  @override
  FutureOr<PagedState<HistoryPoint>> build() async {
    return PagedState.empty();
  } // AsyncNotifier is ideal for async-init and imperative methods with AsyncValue handling. [2][1]

  HistoryFilterSelection get _filters => ref.read(historyFiltersProvider);

  Future<void> refresh() async {
    final repo = ref.read(historyRepositoryProvider);
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() => repo.listPoints(filters: _filters, cursor: null));
    state = res.whenData((page) => AsyncData(PagedState<HistoryPoint>(items: page.items, cursor: page.nextCursor, loading: false)).value);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? PagedState.empty<HistoryPoint>();
    if (current.loading || current.cursor == null) return;
    final repo = ref.read(historyRepositoryProvider);
    state = AsyncData(current.copy(loading: true));
    final res = await AsyncValue.guard(() => repo.listPoints(filters: _filters, cursor: current.cursor));
    res.when(
      data: (page) => state = AsyncData(current.copy(items: [...current.items, ...page.items], cursor: page.nextCursor, loading: false)),
      loading: () => state = AsyncData(current.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        state = AsyncData(current.copy(loading: false, error: e));
      },
    );
  }
}

final pointsControllerProvider = AsyncNotifierProvider<PointsController, PagedState<HistoryPoint>>(PointsController.new); // Exposes a watchable AsyncValue for map points with paging. [2][4]

/// Route controller
class RouteController extends AsyncNotifier<PagedState<RouteHistoryItem>> {
  @override
  FutureOr<PagedState<RouteHistoryItem>> build() async {
    return PagedState.empty();
  } // Build returns initial state; methods mutate with AsyncValue transitions. [2][4]

  HistoryFilterSelection get _filters => ref.read(historyFiltersProvider);

  Future<void> refresh() async {
    final repo = ref.read(historyRepositoryProvider);
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() => repo.listRoute(filters: _filters, cursor: null));
    state = res.whenData((page) => AsyncData(PagedState<RouteHistoryItem>(items: page.items, cursor: page.nextCursor, loading: false)).value);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? PagedState.empty<RouteHistoryItem>();
    if (current.loading || current.cursor == null) return;
    final repo = ref.read(historyRepositoryProvider);
    state = AsyncData(current.copy(loading: true));
    final res = await AsyncValue.guard(() => repo.listRoute(filters: _filters, cursor: current.cursor));
    res.when(
      data: (page) => state = AsyncData(current.copy(items: [...current.items, ...page.items], cursor: page.nextCursor, loading: false)),
      loading: () => state = AsyncData(current.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        state = AsyncData(current.copy(loading: false, error: e));
      },
    );
  }

  /// Optimistic day clear: remove local items for the day, call repo, revert on error.
  Future<void> clearDay(DateTime dayLocal) async {
    final current = state.valueOrNull ?? PagedState.empty<RouteHistoryItem>();
    final key = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final kept = current.items.where((e) {
      final d = DateTime(e.day.year, e.day.month, e.day.day);
      return d != key;
    }).toList();
    state = AsyncData(current.copy(items: kept));
    final repo = ref.read(historyRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.clearDay(dayLocal));
    if (res.hasError) {
      state = AsyncData(current); // revert
    }
  }

  Future<void> clearAll({DateTime? start, DateTime? end}) async {
    final prev = state.valueOrNull ?? PagedState.empty<RouteHistoryItem>();
    state = const AsyncData(PagedState<RouteHistoryItem>(items: <RouteHistoryItem>[], cursor: null, loading: false));
    final repo = ref.read(historyRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.clearAll(start: start, end: end));
    if (res.hasError) {
      state = AsyncData(prev); // revert on failure
    }
  }
}

final routeControllerProvider = AsyncNotifierProvider<RouteController, PagedState<RouteHistoryItem>>(RouteController.new); // Controller for RouteHistory list with pagination and clear actions. [2][7]

/// Transport controller
class TransportController extends AsyncNotifier<PagedState<TransportSegment>> {
  @override
  FutureOr<PagedState<TransportSegment>> build() async {
    return PagedState.empty();
  } // AsyncNotifier keeps transport list logic encapsulated and testable. [2][8]

  HistoryFilterSelection get _filters => ref.read(historyFiltersProvider);

  Future<void> refresh() async {
    final repo = ref.read(historyRepositoryProvider);
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() => repo.listTransport(filters: _filters, cursor: null));
    state = res.whenData((page) => AsyncData(PagedState<TransportSegment>(items: page.items, cursor: page.nextCursor, loading: false)).value);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? PagedState.empty<TransportSegment>();
    if (current.loading || current.cursor == null) return;
    final repo = ref.read(historyRepositoryProvider);
    state = AsyncData(current.copy(loading: true));
    final res = await AsyncValue.guard(() => repo.listTransport(filters: _filters, cursor: current.cursor));
    res.when(
      data: (page) => state = AsyncData(current.copy(items: [...current.items, ...page.items], cursor: page.nextCursor, loading: false)),
      loading: () => state = AsyncData(current.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        state = AsyncData(current.copy(loading: false, error: e));
      },
    );
  }

  Future<void> clearDay(DateTime dayLocal) async {
    final current = state.valueOrNull ?? PagedState.empty<TransportSegment>();
    final key = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final kept = current.items.where((s) {
      final t = s.startTime.toLocal();
      final d = DateTime(t.year, t.month, t.day);
      return d != key;
    }).toList();
    state = AsyncData(current.copy(items: kept));
    final repo = ref.read(historyRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.clearDay(dayLocal));
    if (res.hasError) state = AsyncData(current);
  }

  Future<void> clearAll({DateTime? start, DateTime? end}) async {
    final prev = state.valueOrNull ?? PagedState.empty<TransportSegment>();
    state = const AsyncData(PagedState<TransportSegment>(items: <TransportSegment>[], cursor: null, loading: false));
    final repo = ref.read(historyRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.clearAll(start: start, end: end));
    if (res.hasError) state = AsyncData(prev);
  }
}

final transportControllerProvider = AsyncNotifierProvider<TransportController, PagedState<TransportSegment>>(TransportController.new); // Mirrors RouteController with segment-specific date handling. [2][7]

/// Places controller
class PlacesController extends AsyncNotifier<PagedState<VisitedPlaceRow>> {
  @override
  FutureOr<PagedState<VisitedPlaceRow>> build() async {
    return PagedState.empty();
  } // A simple paged controller for visited places history. [2][1]

  HistoryFilterSelection get _filters => ref.read(historyFiltersProvider);

  Future<void> refresh() async {
    final repo = ref.read(historyRepositoryProvider);
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() => repo.listPlaces(filters: _filters, cursor: null));
    state = res.whenData((page) => AsyncData(PagedState<VisitedPlaceRow>(items: page.items, cursor: page.nextCursor, loading: false)).value);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? PagedState.empty<VisitedPlaceRow>();
    if (current.loading || current.cursor == null) return;
    final repo = ref.read(historyRepositoryProvider);
    state = AsyncData(current.copy(loading: true));
    final res = await AsyncValue.guard(() => repo.listPlaces(filters: _filters, cursor: current.cursor));
    res.when(
      data: (page) => state = AsyncData(current.copy(items: [...current.items, ...page.items], cursor: page.nextCursor, loading: false)),
      loading: () => state = AsyncData(current.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        state = AsyncData(current.copy(loading: false, error: e));
      },
    );
  }

  Future<void> clearAll({DateTime? start, DateTime? end}) async {
    final prev = state.valueOrNull ?? PagedState.empty<VisitedPlaceRow>();
    state = const AsyncData(PagedState<VisitedPlaceRow>(items: <VisitedPlaceRow>[], cursor: null, loading: false));
    final repo = ref.read(historyRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.clearAll(start: start, end: end));
    if (res.hasError) state = AsyncData(prev);
  }
}

final placesControllerProvider = AsyncNotifierProvider<PlacesController, PagedState<VisitedPlaceRow>>(PlacesController.new); // Controller for visited places with paging and clear-all. [2][7]

/// ---------------- Facade for widgets/screens ----------------

class HistoryActions {
  HistoryActions(this._read);
  final Ref _read;

  HistoryFilterSelection get filters => _read(historyFiltersProvider);

  void setFilters(HistoryFilterSelection next) => _read(historyFiltersProvider.notifier).state = next;

  // Points
  Future<void> refreshPoints() => _read(pointsControllerProvider.notifier).refresh();
  Future<void> loadMorePoints() => _read(pointsControllerProvider.notifier).loadMore();

  // Route
  Future<void> refreshRoute() => _read(routeControllerProvider.notifier).refresh();
  Future<void> loadMoreRoute() => _read(routeControllerProvider.notifier).loadMore();
  Future<void> clearRouteDay(DateTime day) => _read(routeControllerProvider.notifier).clearDay(day);
  Future<void> clearRouteAll({DateTime? start, DateTime? end}) =>
      _read(routeControllerProvider.notifier).clearAll(start: start, end: end);

  // Transport
  Future<void> refreshTransport() => _read(transportControllerProvider.notifier).refresh();
  Future<void> loadMoreTransport() => _read(transportControllerProvider.notifier).loadMore();
  Future<void> clearTransportDay(DateTime day) => _read(transportControllerProvider.notifier).clearDay(day);
  Future<void> clearTransportAll({DateTime? start, DateTime? end}) =>
      _read(transportControllerProvider.notifier).clearAll(start: start, end: end);

  // Places
  Future<void> refreshPlaces() => _read(placesControllerProvider.notifier).refresh();
  Future<void> loadMorePlaces() => _read(placesControllerProvider.notifier).loadMore();
  Future<void> clearPlacesAll({DateTime? start, DateTime? end}) =>
      _read(placesControllerProvider.notifier).clearAll(start: start, end: end);
}

final historyActionsProvider = Provider<HistoryActions>((ref) => HistoryActions(ref.read)); // A small facade reduces UI boilerplate and centralizes controller access. [15][1]
