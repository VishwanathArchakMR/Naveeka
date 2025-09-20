// lib/features/quick_actions/presentation/favorites/favorites_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '/../../models/place.dart';

// Shared map builder contract (prefixed to avoid name clashes).
import '/../../features/places/presentation/widgets/nearby_places_map.dart' as pmap;

// Favorites widgets
import 'widgets/favorite_tags.dart';
import 'widgets/favorite_places_list.dart';
import 'widgets/favorite_places_grid.dart';
import 'widgets/favorites_map_view.dart';
import 'widgets/favorites_by_location.dart' as favs;

// Import BOTH unit enums and alias them to resolve type differences.
import '/../../features/places/presentation/widgets/distance_indicator.dart' as di show UnitSystem;
import '/../../features/quick_actions/presentation/booking/widgets/booking_location_filter.dart' as bk show UnitSystem;

enum FavViewMode { list, grid, map, byLocation }

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    this.initialView = FavViewMode.list,
    this.tags = const <String>[],
    this.selectedTags = const <String>{},
    this.countsByTag = const <String, int>{},
    this.mapBuilder,
    this.originLat,
    this.originLng,
    this.initialUnit = bk.UnitSystem.metric, // booking unit as input
  });

  // Initial state
  final FavViewMode initialView;
  final List<String> tags;
  final Set<String> selectedTags;
  final Map<String, int> countsByTag;

  // NOTE: use places' map builder typedef (namespaced).
  final pmap.NearbyMapBuilder? mapBuilder;
  final double? originLat;
  final double? originLng;
  final bk.UnitSystem initialUnit; // booking UnitSystem

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  FavViewMode _mode = FavViewMode.list;

  // Keep booking UnitSystem internally (matches FavoritesMapView)
  bk.UnitSystem _unitBk = bk.UnitSystem.metric;

  // Adapter to places UnitSystem (used by FavoritesByLocation)
  di.UnitSystem get _unitDi =>
      _unitBk == bk.UnitSystem.imperial ? di.UnitSystem.imperial : di.UnitSystem.metric;

  // Data state — wire these to your Riverpod providers or controllers
  bool _loading = false;
  final bool _hasMore = false;
  final List<Place> _favorites = <Place>[];

  // Tag selection (local mirror)
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialView;
    _unitBk = widget.initialUnit;
    _selected = {...widget.selectedTags};
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      // Load favorites and counts from FavoritesApi via providers.
      await Future.delayed(const Duration(milliseconds: 350));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    setState(() => _loading = true);
    try {
      // Load next page
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Best-effort optimistic toggle using dynamic copyWith fallbacks (no direct constructor).
  Future<bool> _toggleFavorite(Place p, bool next) async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final idx = _favorites.indexWhere((e) => e.id == p.id);
      if (idx != -1) {
        final prev = _favorites[idx];
        final updated = _applyFavorite(prev, next) ?? prev;
        _favorites[idx] = updated;
        if (mounted) setState(() {});
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Place? _applyFavorite(Place p, bool value) {
    final dyn = p as dynamic;
    final tries = <Map<Symbol, dynamic>>[
      {#isFavorite: value},
      {#favorite: value},
      {#saved: value},
      {#liked: value},
      {#isWishlisted: value},
      {#wishlisted: value},
    ];
    for (final named in tries) {
      try {
        final next = Function.apply(dyn.copyWith, const [], named);
        if (next is Place) return next;
      } catch (_) {}
    }
    return null;
  }

  void _onOpenPlace(Place p) {
    // Navigate to place details
  }

  // Adapter: convert places' builder into favorites' builder signature.
  favs.NearbyMapBuilder? _adaptBuilder(pmap.NearbyMapBuilder? b) {
    if (b == null) return null;
    return (context, favCfg) {
      // Map favorites config to places config
      final markers = favCfg.markers
          .map<pmap.NearbyMarker>((m) => pmap.NearbyMarker(
                id: m.id,
                lat: m.lat,
                lng: m.lng,
                selected: m.selected,
              ))
          .toList(growable: false);
      final pcfg = pmap.NearbyMapConfig(
        centerLat: favCfg.centerLat,
        centerLng: favCfg.centerLng,
        markers: markers,
        initialZoom: favCfg.initialZoom,
        onMarkerTap: favCfg.onMarkerTap ?? (_) {}, // non-null adapter
        onRecenter: favCfg.onRecenter ?? () {}, // non-null adapter
      );
      return b(context, pcfg);
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final slivers = <Widget>[
      // Top header: title and view switcher
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text('Favorites', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              SegmentedButton<FavViewMode>(
                segments: const [
                  ButtonSegment(value: FavViewMode.list, label: Text('List'), icon: Icon(Icons.list_alt_outlined)),
                  ButtonSegment(value: FavViewMode.grid, label: Text('Grid'), icon: Icon(Icons.grid_view_outlined)),
                  ButtonSegment(value: FavViewMode.map, label: Text('Map'), icon: Icon(Icons.map_outlined)),
                  ButtonSegment(value: FavViewMode.byLocation, label: Text('By location'), icon: Icon(Icons.place_outlined)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ],
          ),
        ),
      ),

      // Tags section
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FavoriteTags(
            tags: widget.tags,
            selected: _selected,
            counts: widget.countsByTag,
            onChanged: (next) async {
              setState(() => _selected = next);
              await _refresh();
            },
            sectionTitle: 'Tags',
            compact: true,
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 8)),

      // Main content per view mode
      SliverToBoxAdapter(child: _buildView(context, cs)),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: slivers,
        ),
      ),
      floatingActionButton: (_mode == FavViewMode.map || _mode == FavViewMode.byLocation)
          ? FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Open filters')),
                );
              },
              icon: const Icon(Icons.tune),
              label: const Text('Filters'),
              backgroundColor: cs.primary.withValues(alpha: 1.0),
              foregroundColor: cs.onPrimary.withValues(alpha: 1.0),
            )
          : null,
    );
  }

  Widget _buildView(BuildContext context, ColorScheme cs) {
    switch (_mode) {
      case FavViewMode.list:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FavoritePlacesList(
            items: _favorites,
            loading: _loading,
            hasMore: _hasMore,
            onRefresh: _refresh,
            onLoadMore: _loadMore,
            onOpenPlace: _onOpenPlace,
            onToggleFavorite: _toggleFavorite,
            originLat: widget.originLat,
            originLng: widget.originLng,
            sectionTitle: 'All favorites',
          ),
        );
      case FavViewMode.grid:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FavoritePlacesGrid(
            items: _favorites,
            loading: _loading,
            hasMore: _hasMore,
            onRefresh: _refresh,
            onLoadMore: _loadMore,
            onOpenPlace: _onOpenPlace,
            onToggleFavorite: _toggleFavorite,
            originLat: widget.originLat,
            originLng: widget.originLng,
            sectionTitle: 'All favorites',
          ),
        );
      case FavViewMode.map:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FavoritesMapView(
            places: _favorites,
            mapBuilder: widget.mapBuilder,
            originLat: widget.originLat,
            originLng: widget.originLng,
            unit: _unitBk, // booking UnitSystem expected by FavoritesMapView
            onOpenFilters: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open filters')));
            },
            onOpenPlace: _onOpenPlace,
            onToggleFavorite: _toggleFavorite,
            onDirections: (p) async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening directions…')));
            },
          ),
        );
      case FavViewMode.byLocation:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: favs.FavoritesByLocation(
            places: _favorites,
            mapBuilder: _adaptBuilder(widget.mapBuilder), // bridge typedefs
            originLat: widget.originLat,
            originLng: widget.originLng,
            initialUnit: _unitDi, // places UnitSystem expected by FavoritesByLocation
            onOpenPlace: _onOpenPlace,
            onToggleFavorite: _toggleFavorite,
            sectionTitle: 'Favorites by location',
          ),
        );
    }
  }
}
