// lib/features/places/presentation/places_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';

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
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  // Data
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
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
      final data = await _mockList(
        category: _filters.categories.isNotEmpty ? _filters.categories.first : null,
        q: _filters.query,
        radiusMeters: _filters.maxDistanceKm?.round() != null ? (_filters.maxDistanceKm!.round() * 1000) : null,
        page: _page,
        limit: widget.pageSize,
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
    if (_loading || !_hasMore) return;
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
    );
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
          final map = _items[index];
          return PlaceCard(
            place: map,
            originLat: widget.originLat,
            originLng: widget.originLng,
            onToggleWishlist: () => _toggleWishlist(index),
          );
        },
        childCount: _items.length,
      ),
    );
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
    final next = Map<String, dynamic>.from(cur)
      ..['isWishlisted'] = !(cur['isWishlisted'] as bool? ?? false);
    setState(() => _items[index] = next);
    // Hook up to backend wishlist API here if available.
  }

  // Mock API list to avoid missing backend and model fields
  Future<List<Map<String, dynamic>>> _mockList({
    String? category,
    String? q,
    int? radiusMeters,
    required int page,
    required int limit,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final count = page >= 3 ? (limit ~/ 2) : limit;
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < count; i++) {
      final id = 'PLC-$page-${i + 1}';
      final name = '${category ?? 'Place'} ${q?.isNotEmpty == true ? '• $q ' : ''}$page-${i + 1}';
      out.add({
        'id': id,
        '_id': id,
        'name': name,
        'coverImage': null,
        'photos': <String>[],
        'category': category ?? (i % 2 == 0 ? 'Nature' : 'Culture'),
        'emotion': i % 3 == 0 ? 'peaceful' : (i % 3 == 1 ? 'energizing' : 'awe'),
        'rating': 3.5 + (i % 3) * 0.4,
        'reviewsCount': 20 + i * 3,
        'lat': 28.61 + (i - count / 2) * 0.01,
        'lng': 77.20 + (i - count / 2) * 0.01,
        'isApproved': i % 4 != 0,
        'isWishlisted': i % 5 == 0,
      });
    }
    return out;
  }
}
