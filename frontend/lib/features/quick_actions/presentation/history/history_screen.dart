// lib/features/quick_actions/presentation/history/history_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

// Filters and sections (prefixed to reference types explicitly)
import 'widgets/history_filters.dart' as hf;
import 'widgets/history_map_view.dart' as hmap;
import 'widgets/route_history.dart' as rh;
import 'widgets/transport_history.dart' as th;
import 'widgets/visited_places.dart' as vp;

// Public enum to avoid exposing a private type in a public API. [web:6155]
enum HistoryTab { map, route, transport, places }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.initialTab = HistoryTab.map,
    this.mapBuilder,

    // Preloaded selections/data (replace with providers in production)
    this.initialFilters = const hf.HistoryFilterSelection(),
    this.initialPoints = const <hmap.HistoryPoint>[],
    this.initialRouteItems = const <rh.RouteHistoryItem>[],
    this.initialSegments = const <th.TransportSegment>[],
    this.initialVisited = const <vp.VisitedPlaceRow>[],

    // Loading/pagination flags
    this.loading = false,
    this.hasMoreRoute = false,
    this.hasMoreTransport = false,
    this.hasMoreVisited = false,
  });

  final HistoryTab initialTab;
  final hmap.NearbyMapBuilder? mapBuilder;

  final hf.HistoryFilterSelection initialFilters;
  final List<hmap.HistoryPoint> initialPoints;
  final List<rh.RouteHistoryItem> initialRouteItems;
  final List<th.TransportSegment> initialSegments;
  final List<vp.VisitedPlaceRow> initialVisited;

  final bool loading;
  final bool hasMoreRoute;
  final bool hasMoreTransport;
  final bool hasMoreVisited;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryTab _tab = HistoryTab.map;

  // Filter state
  hf.HistoryFilterSelection _filters = const hf.HistoryFilterSelection();

  // Data mirrors (wire these to providers/APIs)
  bool _loading = false;
  bool _hasMoreRoute = false;
  bool _hasMoreTransport = false;
  bool _hasMoreVisited = false;

  List<hmap.HistoryPoint> _points = <hmap.HistoryPoint>[];
  List<rh.RouteHistoryItem> _routeItems = <rh.RouteHistoryItem>[];
  List<th.TransportSegment> _segments = <th.TransportSegment>[];
  List<vp.VisitedPlaceRow> _visited = <vp.VisitedPlaceRow>[];

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
      // Simulated concurrent refresh; replace with HistoryApi.list(_filters) and split. [web:6167]
      final results = await Future.wait(<Future<dynamic>>[
        _fetchPoints(filter: _filters),
        _fetchRouteItems(filter: _filters, page: 1),
        _fetchTransportSegments(filter: _filters, page: 1),
        _fetchVisitedPlaces(filter: _filters, page: 1),
      ]);
      if (!mounted) return;
      setState(() {
        _points = (results[0] as List<hmap.HistoryPoint>);
        _routeItems = (results[1] as List<rh.RouteHistoryItem>);
        _segments = (results[2] as List<th.TransportSegment>);
        _visited = (results[3] as List<vp.VisitedPlaceRow>);
        _hasMoreRoute = _routeItems.isNotEmpty;
        _hasMoreTransport = _segments.isNotEmpty;
        _hasMoreVisited = _visited.length >= 12;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  } // Using Future.wait consolidates async work and simplifies state updates. [web:6167]

  // Loaders for paginated sections (if you split lists)
  Future<void> _loadMoreRoute() async {
    if (!_hasMoreRoute || _loading) return;
    setState(() => _loading = true);
    try {
      final next = await _fetchRouteItems(filter: _filters, page: 2);
      if (!mounted) return;
      setState(() {
        _routeItems = [..._routeItems, ...next];
        _hasMoreRoute = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreTransport() async {
    if (!_hasMoreTransport || _loading) return;
    setState(() => _loading = true);
    try {
      final next = await _fetchTransportSegments(filter: _filters, page: 2);
      if (!mounted) return;
      setState(() {
        _segments = [..._segments, ...next];
        _hasMoreTransport = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreVisited() async {
    if (!_hasMoreVisited || _loading) return;
    setState(() => _loading = true);
    try {
      final next = await _fetchVisitedPlaces(filter: _filters, page: 2);
      if (!mounted) return;
      setState(() {
        _visited = [..._visited, ...next];
        _hasMoreVisited = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Clear handlers
  Future<void> _clearDay(DateTime day) async {
    // Simulate HistoryApi.clearRange(day..day) then refetch. [web:6167]
    await Future.delayed(const Duration(milliseconds: 250));
    await _refreshAll();
  }

  Future<void> _clearAll() async {
    // Simulate HistoryApi.clearRange(fullRange) then refetch. [web:6167]
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
              SegmentedButton<HistoryTab>(
                segments: const [
                  ButtonSegment(value: HistoryTab.map, label: Text('Map'), icon: Icon(Icons.map_outlined)),
                  ButtonSegment(value: HistoryTab.route, label: Text('Route'), icon: Icon(Icons.alt_route_outlined)),
                  ButtonSegment(value: HistoryTab.transport, label: Text('Transport'), icon: Icon(Icons.train_outlined)),
                  ButtonSegment(value: HistoryTab.places, label: Text('Places'), icon: Icon(Icons.place_outlined)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ],
          ),
        ),
      ), // Public enum ensures clean public API. [web:6155]

      // Filters
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: hf.HistoryFilters(
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
      ),
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
      case HistoryTab.map:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: hmap.HistoryMapView(
            points: _points,
            mapBuilder: widget.mapBuilder, // typedef matches file’s NearbyMapBuilder. [web:6120]
            onOpenFilters: () {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(const SnackBar(content: Text('Adjust filters above')));
            },
            onOpenPoint: (hmap.HistoryPoint p) {
              // Open place or history detail via named route; fallback SnackBar. [web:6143]
              try {
                Navigator.pushNamed(context, '/history_point', arguments: {'point': p});
              } catch (_) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(const SnackBar(content: Text('Open history point')));
              }
            },
            onDirections: (hmap.HistoryPoint p) async {
              // Launch directions (simulated); guard context after await. [web:6182]
              final messenger = ScaffoldMessenger.of(context);
              await Future.delayed(const Duration(milliseconds: 150));
              if (!mounted) return;
              messenger.showSnackBar(const SnackBar(content: Text('Launching directions…')));
            },
          ),
        );

      case HistoryTab.route:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              rh.RouteHistory(
                items: _routeItems,
                sectionTitle: 'Route history',
                onOpenItem: (it) {
                  // Open route item detail via named route; fallback SnackBar. [web:6143]
                  try {
                    Navigator.pushNamed(context, '/route_item', arguments: {'item': it});
                  } catch (_) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(const SnackBar(content: Text('Open route item')));
                  }
                },
                onClearDay: _clearDay,
                onClearAll: _clearAll,
              ),
              const SizedBox(height: 8),
              if (_hasMoreRoute)
                OutlinedButton.icon(
                  onPressed: _loadMoreRoute,
                  icon: const Icon(Icons.more_horiz),
                  label: const Text('Load more'),
                ),
            ],
          ),
        );

      case HistoryTab.transport:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              th.TransportHistory(
                segments: _segments,
                sectionTitle: 'Transport history',
                onOpenSegment: (s) {
                  // Open segment detail via named route; fallback SnackBar. [web:6143]
                  try {
                    Navigator.pushNamed(context, '/transport_segment', arguments: {'segment': s});
                  } catch (_) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(const SnackBar(content: Text('Open transport segment')));
                  }
                },
                onDirections: (s) async {
                  // Launch directions (simulated). [web:6143]
                  final messenger = ScaffoldMessenger.of(context);
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (!mounted) return;
                  messenger.showSnackBar(const SnackBar(content: Text('Launching directions…')));
                },
                onShare: (s) {
                  // Share (simulated). [web:6155]
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(const SnackBar(content: Text('Shared segment')));
                },
                onClearDay: _clearDay,
                onClearAll: _clearAll,
              ),
              const SizedBox(height: 8),
              if (_hasMoreTransport)
                OutlinedButton.icon(
                  onPressed: _loadMoreTransport,
                  icon: const Icon(Icons.more_horiz),
                  label: const Text('Load more'),
                ),
            ],
          ),
        );

      case HistoryTab.places:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              vp.VisitedPlaces(
                items: _visited,
                loading: _loading,
                hasMore: _hasMoreVisited,
                onRefresh: _refreshAll,
                onLoadMore: _loadMoreVisited,
                onOpenPlace: (p) {
                  // Open place details via named route; fallback SnackBar. [web:6143]
                  try {
                    Navigator.pushNamed(context, '/place_details', arguments: {'place': p});
                  } catch (_) {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(const SnackBar(content: Text('Open place details')));
                  }
                },
                onToggleFavorite: (p, next) async {
                  // Call favorites API (simulated). [web:6167]
                  await Future.delayed(const Duration(milliseconds: 150));
                  return true;
                },
                onRebook: (p) async {
                  // Call booking API or deep link (simulated). [web:6143]
                  await Future.delayed(const Duration(milliseconds: 200));
                  return true;
                },
                sectionTitle: 'Visited places',
              ),
            ],
          ),
        );
    }
  }

  // ---------------- Demo fetchers (replace with HistoryApi) ----------------

  Future<List<hmap.HistoryPoint>> _fetchPoints({required hf.HistoryFilterSelection filter}) async {
    await Future.delayed(const Duration(milliseconds: 120));
    return _points;
  } // Keep existing demo points to avoid model coupling. [web:6155]

  Future<List<rh.RouteHistoryItem>> _fetchRouteItems({required hf.HistoryFilterSelection filter, required int page}) async {
    await Future.delayed(const Duration(milliseconds: 140));
    return _routeItems.isNotEmpty && page > 1 ? _routeItems.take((_routeItems.length / 2).ceil()).toList() : _routeItems;
  } // Simple paging demo; replace with server paging. [web:6167]

  Future<List<th.TransportSegment>> _fetchTransportSegments({required hf.HistoryFilterSelection filter, required int page}) async {
    await Future.delayed(const Duration(milliseconds: 140));
    return _segments.isNotEmpty && page > 1 ? _segments.take((_segments.length / 2).ceil()).toList() : _segments;
  } // Simple paging demo. [web:6167]

  Future<List<vp.VisitedPlaceRow>> _fetchVisitedPlaces({required hf.HistoryFilterSelection filter, required int page}) async {
    await Future.delayed(const Duration(milliseconds: 160));
    return _visited.isNotEmpty && page > 1 ? _visited.take((_visited.length / 2).ceil()).toList() : _visited;
  } // Simple paging demo. [web:6167]
}
