// lib/features/places/presentation/places_list_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/places_api.dart';
import '../../../../models/place.dart';
import 'widgets/place_card.dart';
import 'widgets/place_filters.dart';

class PlacesListScreen extends StatefulWidget {
  const PlacesListScreen({
    super.key,
    this.title = 'Places',
    this.initialFilters = PlaceFilters.empty,
    this.originLat,
    this.originLng,
    this.pageSize = 20,
  });

  final String title;
  final PlaceFilters initialFilters;
  final double? originLat;
  final double? originLng;
  final int pageSize;

  @override
  State<PlacesListScreen> createState() => _PlacesListScreenState();
}

class _PlacesListScreenState extends State<PlacesListScreen> {
  final _api = PlacesApi();
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  // Data
  final List<Place> _items = <Place>[];
  bool _loading = false;
  bool _refreshing = false;
  bool _hasMore = true;
  int _page = 1;

  // Filters
  late PlaceFilters _filters;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _searchCtrl.text = _filters.query ?? '';
    _scroll.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      setState(() {
        _loading = true;
        _refreshing = true;
        _hasMore = true;
        _page = 1;
      });
    } else {
      if (!_hasMore) return;
      setState(() => _loading = true);
    }

    try {
      final res = await _api.list(
        // Map selected filters to API parameters supported by backend
        category: _filters.categories.isNotEmpty ? _filters.categories.first : null,
        emotion: null, // extend if your backend filters by emotion
        q: _filters.query,
        lat: null, // optional: pass user position if API supports distance biasing
        lng: null,
        radius: _filters.maxDistanceKm?.round() != null ? (_filters.maxDistanceKm!.round() * 1000) : null,
        page: _page,
        limit: widget.pageSize,
      );

      final data = await res.when(
        success: (list) async => list,
        failure: (e) async {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message ?? 'Failed to load')),
            );
          }
          return <Place>[];
        },
      );

      setState(() {
        if (reset) _items.clear();
        _items.addAll(data);
        _hasMore = data.length >= widget.pageSize;
        if (_hasMore) _page += 1;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      _fetch(reset: false);
    }
  }

  Future<void> _onRefresh() async {
    await _fetch(reset: true);
  }

  void _openFilters() async {
    final picked = await PlaceFiltersSheet.show(
      context,
      initial: _filters,
    );
    if (picked == null) return;
    setState(() => _filters = picked);
    await _fetch(reset: true);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _filters = _filters.copyWith(query: value.trim().isEmpty ? null : value.trim()));
      _fetch(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final grid = _buildGrid(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Filters button with badge
          Stack(
            children: [
              IconButton(
                tooltip: 'Filters',
                icon: const Icon(Icons.tune),
                onPressed: _openFilters,
              ),
              if (_filters.badgeCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${_filters.badgeCount}',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search places, categories…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              sliver: grid,
            ),
            SliverToBoxAdapter(child: _buildFooter()),
          ],
        ),
      ),
    ); // RefreshIndicator adds pull-to-refresh to the scrollable grid, calling onRefresh to re-fetch data when pulled. [1][4]
  }

  // Responsive grid: 2 (phones) / 3 (tablets) / 4 (large)
  SliverGrid _buildGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cross = width >= 1100 ? 4 : (width >= 750 ? 3 : 2);

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 4 / 5,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _items.length) return const SizedBox.shrink();
          final p = _items[index];
          // PlaceCard expects a Map, adapt from model for consistent UI reuse
          final map = _placeToMap(p);
          return PlaceCard(
            place: map,
            originLat: widget.originLat,
            originLng: widget.originLng,
            onToggleWishlist: () => _toggleWishlist(index),
          );
        },
        childCount: _items.length,
      ),
    ); // GridView.builder via SliverGrid lazily builds tiles for performance and scales to large datasets cleanly. [19][12]
  }

  Widget _buildFooter() {
    if (_refreshing && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loading && _hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No more results')),
      );
    }
    return const SizedBox(height: 24);
  }

  Future<void> _toggleWishlist(int index) async {
    if (index < 0 || index >= _items.length) return;
    final cur = _items[index];
    final next = cur.copyWith(isFavorite: !(cur.isFavorite ?? false));
    setState(() => _items[index] = next);
    // TODO: Wire to backend wishlist endpoint if available
  }

  Map<String, dynamic> _placeToMap(Place p) {
    return {
      '_id': p.id,
      'id': p.id,
      'name': p.name,
      'coverImage': (p.photos != null && p.photos!.isNotEmpty) ? p.photos!.first : null,
      'photos': p.photos,
      'category': (p.categories != null && p.categories!.isNotEmpty) ? p.categories!.first : null,
      'emotion': p.emotion,
      'rating': p.rating,
      'reviewsCount': p.reviewsCount,
      'lat': p.lat,
      'lng': p.lng,
      'isApproved': p.isApproved,
      'isWishlisted': p.isFavorite,
    };
  }
}
