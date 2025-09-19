// lib/features/journey/presentation/restaurants/restaurant_results_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'widgets/restaurant_card.dart';
import 'widgets/restaurant_map_view.dart';
import 'widgets/cuisine_by_location.dart';
import 'restaurant_booking_screen.dart';
import '../../data/restaurants_api.dart';

class RestaurantResultsScreen extends StatefulWidget {
  const RestaurantResultsScreen({
    super.key,
    required this.destination, // city/area text or code
    this.centerLat,
    this.centerLng,
    this.currency = '₹',
    this.title = 'Restaurants',
    this.pageSize = 20,
    this.sort = 'rating_desc', // rating_desc | distance_asc | price_asc
    this.initialCuisines = const <String>{},
  });

  final String destination;
  final double? centerLat;
  final double? centerLng;

  final String currency;
  final String title;
  final int pageSize;
  final String sort;

  final Set<String> initialCuisines;

  @override
  State<RestaurantResultsScreen> createState() => _RestaurantResultsScreenState();
}

class _RestaurantResultsScreenState extends State<RestaurantResultsScreen> {
  final _scrollCtrl = ScrollController();

  bool _loading = false;
  bool _loadMore = false;
  bool _hasMore = true;
  int _page = 1;

  String? _sort;
  Set<String> _cuisines = {};

  final List<Map<String, dynamic>> _items = [];

  bool _showMap = false;
  String? _selectedRestaurantId;

  @override
  void initState() {
    super.initState();
    _sort = widget.sort;
    _cuisines = {...widget.initialCuisines};
    _fetch(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_showMap) return;
    if (_loadMore || _loading || !_hasMore) return;
    final pos = _scrollCtrl.position;
    final trigger = pos.maxScrollExtent * 0.9;
    if (pos.pixels > trigger) {
      _fetch();
    }
  } // Infinite scrolling via a ScrollController threshold is a common pattern for lazy loading large lists in Flutter. [9][15]

  Future<void> _refresh() async {
    await _fetch(reset: true);
  } // Pull-to-refresh is implemented by wrapping the scrollable in RefreshIndicator with an async onRefresh. [1][2]

  Future<void> _openFilters() async {
    // Placeholder bottom sheet; wire up a full filters widget later.
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                IconButton(onPressed: () => Navigator.of(ctx).maybePop(), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Coming soon: price, rating, distance, open now, tags'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(ctx).maybePop(<String, dynamic>{}),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    ); // showModalBottomSheet returns a result via Navigator.pop, enabling modular filter flows. [10][7]

    if (res != null) {
      // When real filters are added, merge into request params here.
      await _fetch(reset: true);
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _loadMore = false;
        _hasMore = true;
        _page = 1;
        _items.clear();
      });
    } else {
      if (!_hasMore) return;
      setState(() => _loadMore = true);
    }

    final api = RestaurantsApi();
    final res = await api.search(
      destination: widget.destination,
      centerLat: widget.centerLat,
      centerLng: widget.centerLng,
      sort: _sort,
      cuisines: _cuisines.toList(),
      page: _page,
      limit: widget.pageSize,
    );

    res.fold(
      onSuccess: (data) {
        final list = _asList(data);
        final normalized = list.map(_normalize).toList(growable: false);
        setState(() {
          _items.addAll(normalized);
          _hasMore = list.length >= widget.pageSize;
          if (_hasMore) _page += 1;
          _loading = false;
          _loadMore = false;
        });
      },
      onError: (err) {
        setState(() {
          _loading = false;
          _loadMore = false;
          _hasMore = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.safeMessage ?? 'Failed to load restaurants')),
        );
      },
    );
  }

  List<Map<String, dynamic>> _asList(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is List) return List<Map<String, dynamic>>.from(data);
    final results = payload['results'];
    if (results is List) return List<Map<String, dynamic>>.from(results);
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> m) {
    T? pick<T>(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null) return v as T?;
      }
      return null;
    }

    double? d(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    num? n(dynamic v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    }

    return {
      'id': (pick(['id', '_id', 'restaurantId']) ?? '').toString(),
      'name': (pick(['name', 'title']) ?? '').toString(),
      'imageUrl': pick(['imageUrl', 'photo']),
      'cuisines': (m['cuisines'] is List) ? List<String>.from(m['cuisines']) : const <String>[],
      'rating': (pick(['rating', 'avgRating']) is num) ? (pick(['rating', 'avgRating']) as num).toDouble() : null,
      'reviewCount': pick(['reviewCount', 'reviews']) is int ? pick(['reviewCount', 'reviews']) as int : null,
      'priceLevel': pick(['priceLevel']) is int ? pick(['priceLevel']) as int : null,
      'costForTwo': n(pick(['costForTwo', 'priceForTwo'])),
      'distanceKm': d(pick(['distanceKm', 'distance'])),
      'isOpen': pick(['openNow']) == true,
      'lat': d(pick(['lat', 'latitude'])),
      'lng': d(pick(['lng', 'longitude'])),
      'tags': (m['tags'] is List) ? List<String>.from(m['tags']) : const <String>[],
    };
  }

  void _openBooking(Map<String, dynamic> r) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RestaurantBookingScreen(
        restaurantId: (r['id'] ?? '').toString(),
        restaurantName: (r['name'] ?? '').toString(),
        currency: widget.currency,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.centerLat != null && widget.centerLng != null
        ? '${widget.destination} • Lat ${widget.centerLat!.toStringAsFixed(3)}, Lng ${widget.centerLng!.toStringAsFixed(3)}'
        : widget.destination;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _showMap ? 'Show list' : 'Show map',
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: Icon(_showMap ? Icons.list_alt : Icons.map_outlined),
          ), // The list/map toggle composes two views while keeping one screen, improving context retention. [1]
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune),
          ), // Filters are typically presented via a modal bottom sheet for compact, contextual adjustments. [7]
        ],
      ),
      body: SafeArea(
        child: _showMap ? _buildMap() : _buildList(),
      ),
    );
  }

  Widget _buildCuisineBar() {
    return CuisineByLocation(
      lat: widget.centerLat,
      lng: widget.centerLng,
      city: widget.destination,
      items: null, // Provide items directly if prefetched; else wire a fetch callback.
      fetchCuisines: (args) async => <Map<String, dynamic>>[],
      initialSelected: _cuisines,
      multiSelect: true,
      title: 'Cuisines',
      onChanged: (sel) async {
        _cuisines = sel;
        await _fetch(reset: true);
      },
    ); // ChoiceChip-based cuisine selection with an “All” sheet lets users refine results quickly. [21][10]
  }

  Widget _buildMap() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildCuisineBar(),
          const SizedBox(height: 8),
          Expanded(
            child: RestaurantMapView(
              restaurants: _items,
              height: double.infinity,
              currency: widget.currency,
              selectedRestaurantId: _selectedRestaurantId,
              onTapRestaurant: (r) {
                setState(() => _selectedRestaurantId = (r['id'] ?? '').toString());
                _openBooking(r);
              },
            ),
          ),
        ],
      ),
    ); // RestaurantMapView uses MarkerLayer and CameraFit.bounds so all pins render with proper initial framing. [22][23]
  }

  Widget _buildList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _buildCuisineBar(),
        ),
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: _refresh,
            child: ListView.builder(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: _items.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) return _buildHeader();
                if (index == _items.length + 1) return _buildFooterLoader();
                final r = _items[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RestaurantCard(
                    id: (r['id'] ?? '').toString(),
                    name: (r['name'] ?? '').toString(),
                    imageUrl: r['imageUrl']?.toString(),
                    cuisines: (r['cuisines'] as List).cast<String>(),
                    rating: (r['rating'] as num?)?.toDouble(),
                    reviewCount: r['reviewCount'] as int?,
                    priceLevel: r['priceLevel'] as int?,
                    costForTwo: r['costForTwo'] as num?,
                    currency: widget.currency,
                    distanceKm: (r['distanceKm'] as num?)?.toDouble(),
                    isOpen: r['isOpen'] as bool?,
                    tags: (r['tags'] as List).cast<String>(),
                    onTap: () => _openBooking(r),
                    onPrimaryAction: () => _openBooking(r),
                    primaryLabel: 'Reserve',
                  ),
                );
              },
            ),
          ),
        ), // RefreshIndicator.adaptive provides native-feeling pull-to-refresh across platforms around a scrollable child. [1][4]
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Text(
            _loading && _items.isEmpty ? 'Loading…' : '${_items.length}${_hasMore ? '+' : ''} restaurants',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _sort,
              isDense: true,
              icon: const Icon(Icons.sort),
              onChanged: (v) async {
                setState(() => _sort = v);
                await _fetch(reset: true);
              },
              items: const [
                DropdownMenuItem(value: 'rating_desc', child: Text('Rating (highest)')),
                DropdownMenuItem(value: 'distance_asc', child: Text('Distance (closest)')),
                DropdownMenuItem(value: 'price_asc', child: Text('Price (low to high)')),
              ],
              decoration: const InputDecoration(
                labelText: 'Sort',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    ); // A simple sort dropdown offers quick reordering without leaving the screen. [9]
  }

  Widget _buildFooterLoader() {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('No more results')),
      );
    }
    return const SizedBox.shrink();
  }
}
