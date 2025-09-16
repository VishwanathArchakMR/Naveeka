// lib/features/quick_actions/presentation/history/history_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Filters and sections
import 'widgets/history_filters.dart';
import 'widgets/history_map_view.dart';
import 'widgets/route_history.dart';
import 'widgets/transport_history.dart';
import 'widgets/visited_places.dart';

// Example map builder typedef (reuse your project-wide builder if available).
typedef NearbyMapBuilder = Widget Function(BuildContext context, NearbyMapConfig config);

class NearbyMapConfig {
  const NearbyMapConfig({
    required this.centerLat,
    required this.centerLng,
    required this.markers,
    this.initialZoom = 12,
    this.onMarkerTap,
    this.onRecenter,
  });

  final double centerLat;
  final double centerLng;
  final List<NearbyMarker> markers;
  final double initialZoom;
  final void Function(String id)? onMarkerTap;
  final VoidCallback? onRecenter;
}

class NearbyMarker {
  const NearbyMarker({
    required this.id,
    required this.lat,
    required this.lng,
    this.selected = false,
    this.icon,
  });

  final String id;
  final double lat;
  final double lng;
  final bool selected;
  final String? icon;
}

enum _HistoryTab { map, route, transport, places }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.initialTab = _HistoryTab.map,
    this.mapBuilder,

    // Preloaded selections/data (replace with providers in production)
    this.initialFilters = const HistoryFilterSelection(),
    this.initialPoints = const <HistoryPoint>[],
    this.initialRouteItems = const <RouteHistoryItem>[],
    this.initialSegments = const <TransportSegment>[],
    this.initialVisited = const <VisitedPlaceRow>[],

    // Loading/pagination flags
    this.loading = false,
    this.hasMoreRoute = false,
    this.hasMoreTransport = false,
    this.hasMoreVisited = false,
  });

  final _HistoryTab initialTab;
  final NearbyMapBuilder? mapBuilder;

  final HistoryFilterSelection initialFilters;
  final List<HistoryPoint> initialPoints;
  final List<RouteHistoryItem> initialRouteItems;
  final List<TransportSegment> initialSegments;
  final List<VisitedPlaceRow> initialVisited;

  final bool loading;
  final bool hasMoreRoute;
  final bool hasMoreTransport;
  final bool hasMoreVisited;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryTab _tab = _HistoryTab.map;

  // Filter state
  HistoryFilterSelection _filters = const HistoryFilterSelection();

  // Data mirrors (wire these to providers/APIs)
  bool _loading = false;
  bool _hasMoreRoute = false;
  bool _hasMoreTransport = false;
  bool _hasMoreVisited = false;

  List<HistoryPoint> _points = <HistoryPoint>[];
  List<RouteHistoryItem> _routeItems = <RouteHistoryItem>[];
  List<TransportSegment> _segments = <TransportSegment>[];
  List<VisitedPlaceRow> _visited = <VisitedPlaceRow>[];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _filters = widget.initialFilters;
    _points = [...widget.initialPoints];
    _routeItems = [...widget.initialRouteItems];
    _segments = [...widget.initialSegments];
    _visited = [...widget.initialVisited];
    _loading = widget.loading;
    _hasMoreRoute = widget.hasMoreRoute;
    _hasMoreTransport = widget.hasMoreTransport;
    _hasMoreVisited = widget.hasMoreVisited;
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      // TODO: call HistoryApi.list with _filters; split into points/route/transport/places as needed.
      await Future.delayed(const Duration(milliseconds: 350));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Loaders for paginated sections (if you split lists)
  Future<void> _loadMoreRoute() async {
    if (!_hasMoreRoute || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: fetch next page of route items
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreTransport() async {
    if (!_hasMoreTransport || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: fetch next page of transport segments
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreVisited() async {
    if (!_hasMoreVisited || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: fetch next page of visited places
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Clear handlers
  Future<void> _clearDay(DateTime day) async {
    // TODO: call HistoryApi.clearRange for that day and refetch
    await Future.delayed(const Duration(milliseconds: 250));
    await _refreshAll();
  }

  Future<void> _clearAll() async {
    // TODO: call HistoryApi.clearRange over a broad range and refetch
    await Future.delayed(const Duration(milliseconds: 250));
    await _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final slivers = <Widget>[
      // Header: title + segmented tabs
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              SegmentedButton<_HistoryTab>(
                segments: const [
                  ButtonSegment(value: _HistoryTab.map, label: Text('Map'), icon: Icon(Icons.map_outlined)),
                  ButtonSegment(value: _HistoryTab.route, label: Text('Route'), icon: Icon(Icons.alt_route_outlined)),
                  ButtonSegment(value: _HistoryTab.transport, label: Text('Transport'), icon: Icon(Icons.train_outlined)),
                  ButtonSegment(value: _HistoryTab.places, label: Text('Places'), icon: Icon(Icons.place_outlined)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ],
          ),
        ),
      ), // CustomScrollView organizes mixed sections efficiently with slivers for complex layouts. [1][2]

      // Filters
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: HistoryFilters(
            value: _filters,
            onChanged: (next) async {
              setState(() => _filters = next);
              await _refreshAll();
            },
            compact: true,
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 8)),

      // Body per tab
      SliverToBoxAdapter(child: _buildTabBody()),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _refreshAll,
        child: CustomScrollView(slivers: slivers),
      ), // RefreshIndicator.adaptive applies platform-appropriate pull-to-refresh visuals. [6][12]
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _refreshAll,
        icon: const Icon(Icons.sync),
        label: const Text('Sync'),
        backgroundColor: cs.primary.withValues(alpha: 1.0),
        foregroundColor: cs.onPrimary.withValues(alpha: 1.0),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_tab) {
      case _HistoryTab.map:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: HistoryMapView(
            points: _points,
            mapBuilder: widget.mapBuilder,
            onOpenFilters: () async {
              // Focus filters section
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adjust filters above')));
            },
            onOpenPoint: (p) {
              // TODO: open place or history detail
            },
            onDirections: (p) async {
              // TODO: launch directions
              await Future.delayed(const Duration(milliseconds: 150));
            },
          ),
        ); // Map view embeds a pluggable map and a peek card for selected points. [1]

      case _HistoryTab.route:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: RouteHistory(
            items: _routeItems,
            sectionTitle: 'Route history',
            onOpenItem: (it) {
              // TODO: open route item detail
            },
            onClearDay: _clearDay,
            onClearAll: _clearAll,
          ),
        ); // Route history uses an expandable day timeline with a custom rail and actions. [1]

      case _HistoryTab.transport:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TransportHistory(
            segments: _segments,
            sectionTitle: 'Transport history',
            onOpenSegment: (s) {
              // TODO: open segment detail
            },
            onDirections: (s) async {
              // TODO: launch directions
              await Future.delayed(const Duration(milliseconds: 150));
            },
            onShare: (s) {
              // TODO: share
            },
            onClearDay: _clearDay,
            onClearAll: _clearAll,
          ),
        ); // Transport history shows filterable modes and per-segment metadata with actions. [21]

      case _HistoryTab.places:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: VisitedPlaces(
            items: _visited,
            loading: _loading,
            hasMore: _hasMoreVisited,
            onRefresh: _refreshAll,
            onLoadMore: _loadMoreVisited,
            onOpenPlace: (p) {
              // TODO: open place details
            },
            onToggleFavorite: (p, next) async {
              // TODO: call favorites API
              await Future.delayed(const Duration(milliseconds: 150));
              return true;
            },
            onRebook: (p) async {
              // TODO: call booking API or partner deep link
              await Future.delayed(const Duration(milliseconds: 200));
              return true;
            },
            sectionTitle: 'Visited places',
          ),
        ); // Places grid renders visited items with favorite/rebook quick actions in accessible cards. [22][23]
    }
  }
}
