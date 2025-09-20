// lib/features/trails/presentation/trails_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/widgets/trails_top_bar.dart';
import '../presentation/widgets/feed_card.dart';
import '../presentation/widgets/trail_map_view.dart';

// Alias the APIs and models to avoid type collisions.
import '../../trails/data/trails_api.dart' as api show TrailsApi;
import '../../trails/data/trail_location_api.dart' as loc show TrailSummary, GeoPoint;
import '../../../models/geo_point.dart' as model show GeoPoint;

/// DI injection point for the Trails domain API (override in app bootstrap).
final trailsApiProvider = Provider<api.TrailsApi>((ref) {
  throw UnimplementedError('Provide TrailsApi via override at app bootstrap');
});

/// Filters and view state for this screen.
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
  // API expects app-wide geo model here.
  final model.GeoPoint? center;
  final double? radiusKm;

  TrailsFilters copyWith({
    String? query,
    Set<String>? difficulties,
    TrailsViewMode? viewMode,
    model.GeoPoint? center,
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

final trailsFiltersProvider =
    StateProvider<TrailsFilters>((ref) => const TrailsFilters());

/// Simple paged state holder.
@immutable
class PagedState<T> {
  const PagedState(
      {required this.items,
      required this.cursor,
      required this.loading,
      this.error});
  final List<T> items;
  final String? cursor;
  final bool loading;
  final Object? error;

  PagedState<T> copy(
          {List<T>? items, String? cursor, bool? loading, Object? error}) =>
      PagedState<T>(
          items: items ?? this.items,
          cursor: cursor ?? this.cursor,
          loading: loading ?? this.loading,
          error: error);

  static PagedState<T> empty<T>() => PagedState<T>(
      items: const <dynamic>[] as List<T>, cursor: null, loading: false);
}

/// Controller that fetches and paginates Trails via TrailsApi using current filters.
class TrailsListController extends AsyncNotifier<PagedState<loc.TrailSummary>> {
  @override
  FutureOr<PagedState<loc.TrailSummary>> build() async {
    return PagedState.empty();
  }

  api.TrailsApi get _api => ref.read(trailsApiProvider);

  TrailsFilters get _filters => ref.read(trailsFiltersProvider);

  Future<void> refresh() async {
    state = const AsyncLoading();
    final f = _filters;
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
    // Coerce API items to location-domain summaries to avoid cross-library list type mismatch.
    final List<loc.TrailSummary> items =
        (page.items as List).cast<loc.TrailSummary>().toList(growable: false);
    state = AsyncData(PagedState<loc.TrailSummary>(
        items: items, cursor: page.nextCursor, loading: false));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? PagedState.empty<loc.TrailSummary>();
    if (current.loading || current.cursor == null) return;
    state = AsyncData(current.copy(loading: true));
    final f = _filters;
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
      final List<loc.TrailSummary> next =
          (page.items as List).cast<loc.TrailSummary>().toList(growable: false);
      state = AsyncData(current.copy(
          items: [...current.items, ...next],
          cursor: page.nextCursor,
          loading: false));
    } catch (e, st) {
      state = AsyncError(e, st);
      state = AsyncData(current.copy(loading: false, error: e));
    }
  }
}

final trailsListControllerProvider =
    AsyncNotifierProvider<TrailsListController, PagedState<loc.TrailSummary>>(
  TrailsListController.new,
);

/// The Trails screen composes search, filters, list/map, and pagination.
class TrailsScreen extends ConsumerStatefulWidget {
  const TrailsScreen({
    super.key,
    this.title = 'Trails',
    this.suggestions = const <String>[],
    this.onOpenTrail, // void Function(BuildContext context, TrailSummary trail)
  });

  final String title;
  final List<String> suggestions;
  final void Function(BuildContext context, loc.TrailSummary trail)? onOpenTrail;

  @override
  ConsumerState<TrailsScreen> createState() => _TrailsScreenState();
}

class _TrailsScreenState extends ConsumerState<TrailsScreen> {
  @override
  void initState() {
    super.initState();
    // Initial fetch
    unawaited(ref.read(trailsListControllerProvider.notifier).refresh());
  }

  Future<void> _onRefresh() =>
      ref.read(trailsListControllerProvider.notifier).refresh();

  void _applyQuery(String q) {
    final curr = ref.read(trailsFiltersProvider);
    ref.read(trailsFiltersProvider.notifier).state =
        curr.copyWith(query: q.trim());
    unawaited(ref.read(trailsListControllerProvider.notifier).refresh());
  }

  void _toggleDifficulty(String d, bool next) {
    final curr = ref.read(trailsFiltersProvider);
    final set = {...curr.difficulties};
    if (next) {
      set.add(d);
    } else {
      set.remove(d);
    }
    ref.read(trailsFiltersProvider.notifier).state =
        curr.copyWith(difficulties: set);
    unawaited(ref.read(trailsListControllerProvider.notifier).refresh());
  }

  void _changeView(TrailsViewMode m) {
    final curr = ref.read(trailsFiltersProvider);
    ref.read(trailsFiltersProvider.notifier).state = curr.copyWith(viewMode: m);
    // no refresh needed as list data is the same; only presentation changes
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filters = ref.watch(trailsFiltersProvider);
    final state = ref.watch(trailsListControllerProvider);
    final items = state.valueOrNull?.items ?? const <loc.TrailSummary>[];
    final loading = state.isLoading && items.isEmpty;
    final error = state.hasError ? 'Failed to load trails' : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // Top bar: search + view + filters
          TrailsTopBar(
            initialQuery: filters.query,
            suggestions: widget.suggestions,
            onQueryChanged: (q) => _applyQuery(q),
            onSubmitted: (q) => _applyQuery(q),
            viewMode: filters.viewMode,
            onViewModeChanged: (m) => _changeView(m),
            selectedDifficulties: filters.difficulties,
            onToggleDifficulty: (d, next) => _toggleDifficulty(d, next),
            onClearFilters: () => _onRefresh(),
            trailing: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _onRefresh,
              ),
            ],
            background: cs.surface,
          ),

          // Content
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: _onRefresh,
              child:
                  _buildBody(context, filters.viewMode, items, loading, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TrailsViewMode mode,
    List<loc.TrailSummary> items,
    bool loading,
    String? error,
  ) {
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: cs.onSurfaceVariant),
        ),
      );
    }

    if (error != null && items.isEmpty) {
      return _ErrorState(message: error, onRetry: _onRefresh);
    }

    if (mode == TrailsViewMode.map) {
      // Map view: render markers from centers; geometry is fetched on detail screen
      final List<loc.GeoPoint> markers =
          items.map((t) => t.center).toList(growable: false);
      return Stack(
        children: [
          TrailMapView(
            geometry: const <loc.GeoPoint>[],
            trailheads: const <loc.GeoPoint>[],
            markers: markers,
            padding: const EdgeInsets.all(24),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _MapOverlayList(
              items: items,
              onOpen: (trail) => _openTrail(context, trail),
            ),
          ),
        ],
      );
    }

    // List/grid view
    if (items.isEmpty) {
      return _EmptyState(onAddFilters: () {}, onRefresh: _onRefresh);
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final t = items[i];
                return FeedCard(
                  trailId: t.id,
                  title: t.name,
                  imageUrl: t.thumbnailUrl ?? '',
                  heroTag: 'trail-${t.id}',
                  rating: t.rating,
                  distanceKm: t.distanceKm,
                  elevationGainM: t.elevationGainM,
                  difficulty: t.difficulty,
                  tags: t.tags,
                  isFavorite: false,
                  onOpen: () => _openTrail(context, t),
                  onToggleFavorite: null,
                  onShare: null,
                  onNavigate: null,
                );
              },
              childCount: items.length,
            ),
          ),
        ),
        // Load more
        _LoadMoreSliver(
          hasMore:
              (ref.read(trailsListControllerProvider).valueOrNull?.cursor) !=
                  null,
          onLoadMore: () =>
              ref.read(trailsListControllerProvider.notifier).loadMore(),
        ),
      ],
    );
  }

  void _openTrail(BuildContext context, loc.TrailSummary trail) {
    if (widget.onOpenTrail != null) {
      widget.onOpenTrail!(context, trail);
      return;
    }
    // Fallback: push by route name if defined externally
    Navigator.of(context).pushNamed('/trail', arguments: trail.id);
  }
}

// ----------------- Helpers/overlays -----------------

class _MapOverlayList extends StatelessWidget {
  const _MapOverlayList({required this.items, required this.onOpen});

  final List<loc.TrailSummary> items;
  final void Function(loc.TrailSummary trail) onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 1.0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final t = items[i];
            return InkWell(
              onTap: () => onOpen(t),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 240,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.primary),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.terrain, color: cs.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(t),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _subtitle(loc.TrailSummary t) {
    final parts = <String>[];
    if (t.rating != null) parts.add('${t.rating!.toStringAsFixed(1)}★');
    if (t.distanceKm != null) {
      parts.add(
          '${t.distanceKm!.toStringAsFixed(t.distanceKm! >= 10 ? 0 : 1)} km');
    }
    if (t.elevationGainM != null) {
      parts.add('${t.elevationGainM!.toStringAsFixed(0)} m');
    }
    return parts.join(' • ');
  }
}

class _LoadMoreSliver extends ConsumerWidget {
  const _LoadMoreSliver({required this.hasMore, required this.onLoadMore});
  final bool hasMore;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasMore) return const SliverToBoxAdapter(child: SizedBox(height: 12));
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.expand_more),
            label: const Text('Load more'),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddFilters, required this.onRefresh});
  final VoidCallback onAddFilters;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 48, 12, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.route_outlined, color: cs.primary, size: 36),
          ),
          const SizedBox(height: 12),
          Text('No trails found',
              style:
                  TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 6),
          Text('Try adjusting filters or refreshing',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                  onPressed: onAddFilters,
                  icon: const Icon(Icons.tune),
                  label: const Text('Filters')),
              const SizedBox(width: 8),
              FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 28),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface)),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry')),
        ],
      ),
    );
  }
}
