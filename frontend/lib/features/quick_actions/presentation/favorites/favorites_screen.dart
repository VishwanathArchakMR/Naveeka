// lib/features/quick_actions/presentation/favorites/favorites_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../models/place.dart';

// Reused favorites widgets
import 'widgets/favorite_tags.dart';
import 'widgets/favorite_places_list.dart';
import 'widgets/favorite_places_grid.dart';
import 'widgets/favorites_map_view.dart';
import 'widgets/favorites_by_location.dart';

// Optional: shared map builder contract (Google/Mapbox) used across the app.
// Pass your concrete builder from the page that pushes this screen if needed.
typedef NearbyMapBuilder = Widget Function(BuildContext context, NearbyMapConfig config);

class NearbyMapConfig {
  NearbyMapConfig({
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
  NearbyMarker({
    required this.id,
    required this.lat,
    required this.lng,
    this.selected = false,
  });

  final String id;
  final double lat;
  final double lng;
  final bool selected;
}

enum _FavViewMode { list, grid, map, byLocation }

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    this.initialView = _FavViewMode.list,
    this.tags = const <String>[],
    this.selectedTags = const <String>{},
    this.countsByTag = const <String, int>{},
    this.mapBuilder, // Inject your Google/Mapbox builder here to enable map views
    this.originLat,
    this.originLng,
    this.initialUnit = UnitSystem.metric,
  });

  // Initial state
  final _FavViewMode initialView;
  final List<String> tags;
  final Set<String> selectedTags;
  final Map<String, int> countsByTag;

  final NearbyMapBuilder? mapBuilder;
  final double? originLat;
  final double? originLng;
  final UnitSystem initialUnit;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  _FavViewMode _mode = _FavViewMode.list;
  UnitSystem _unit = UnitSystem.metric;

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
    _unit = widget.initialUnit;
    _selected = {...widget.selectedTags};
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      // TODO: Load favorites and counts from FavoritesApi via providers.
      await Future.delayed(const Duration(milliseconds: 350));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    setState(() => _loading = true);
    try {
      // TODO: Load next page
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Callback for FavoriteButton toggles
  Future<bool> _toggleFavorite(Place p, bool next) async {
    try {
      // TODO: call FavoritesApi.addFavorite/removeFavorite
      await Future.delayed(const Duration(milliseconds: 200));
      // Optimistically update local item if you keep local state
      final idx = _favorites.indexWhere((e) => e.id == p.id);
      if (idx != -1) {
        final prev = _favorites[idx];
        _favorites[idx] = prev.copyWith(isFavorite: next, isWishlisted: next);
        if (mounted) setState(() {});
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onOpenPlace(Place p) {
    // TODO: Navigate to place details
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
              SegmentedButton<_FavViewMode>(
                segments: const [
                  ButtonSegment(value: _FavViewMode.list, label: Text('List'), icon: Icon(Icons.list_alt_outlined)),
                  ButtonSegment(value: _FavViewMode.grid, label: Text('Grid'), icon: Icon(Icons.grid_view_outlined)),
                  ButtonSegment(value: _FavViewMode.map, label: Text('Map'), icon: Icon(Icons.map_outlined)),
                  ButtonSegment(value: _FavViewMode.byLocation, label: Text('By location'), icon: Icon(Icons.place_outlined)),
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
      floatingActionButton: (_mode == _FavViewMode.map || _mode == _FavViewMode.byLocation)
          ? FloatingActionButton.extended(
              onPressed: () {
                // Reuse location filter in map-based views
                // The map widgets themselves expose location/radius pickers,
                // so this can also be used for opening a tag manager or global filters.
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
      case _FavViewMode.list:
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
      case _FavViewMode.grid:
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
      case _FavViewMode.map:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FavoritesMapView(
            places: _favorites,
            mapBuilder: widget.mapBuilder,
            originLat: widget.originLat,
            originLng: widget.originLng,
            unit: _unit,
            onOpenFilters: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open filters')));
            },
            onOpenPlace: _onOpenPlace,
            onToggleFavorite: _toggleFavorite,
            onDirections: (p) async {
              // TODO: Launch preferred directions handler
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening directions…')));
            },
          ),
        );
      case _FavViewMode.byLocation:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FavoritesByLocation(
            places: _favorites,
            mapBuilder: widget.mapBuilder,
            originLat: widget.originLat,
            originLng: widget.originLng,
            initialUnit: _unit,
            onOpenPlace: _onOpenPlace,
            onToggleFavorite: _toggleFavorite,
            sectionTitle: 'Favorites by location',
          ),
        );
    }
  }
}

// Minimal Place extension for optimistic updates; adapt to your real Place model’s API.
extension on Place {
  Place copyWith({
    bool? isFavorite,
    bool? isWishlisted,
  }) {
    return Place(
      id: id,
      name: name,
      photos: photos,
      categories: categories,
      emotion: emotion,
      rating: rating,
      reviewsCount: reviewsCount,
      lat: lat,
      lng: lng,
      isApproved: isApproved,
      isFavorite: isFavorite ?? this.isFavorite,
      isWishlisted: isWishlisted ?? this.isWishlisted,
      address: address,
      city: city,
      region: region,
      country: country,
    );
  }
}
