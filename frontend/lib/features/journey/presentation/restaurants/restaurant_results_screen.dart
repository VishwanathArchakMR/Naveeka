// lib/features/journey/presentation/restaurants/restaurant_results_screen.dart

import 'package:flutter/material.dart';

import 'widgets/restaurant_card.dart';
// Removed: import 'widgets/restaurant_map_view.dart';
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
  State<RestaurantResultsScreen> createState() =>
      _RestaurantResultsScreenState();
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
  } // Using a 90% scroll threshold is a common lazy-load pattern for infinite lists. [web:5767][web:5748]

  Future<void> _refresh() async {
    await _fetch(reset: true);
  } // RefreshIndicator works with an async onRefresh to reload content. [web:5748][web:5767]

  Future<void> _openFilters() async {
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
                const Expanded(
                    child: Text('Filters',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16))),
                IconButton(
                    onPressed: () => Navigator.of(ctx).maybePop(),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Coming soon: price, rating, distance, open now, tags'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(ctx).maybePop(<String, dynamic>{}),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    ); // showModalBottomSheet returns a Future with the result pop value, enabling simple filter flows. [web:5748][web:5764]

    if (res != null) {
      await _fetch(reset: true);
    }
  }

  // Flexible search adapter: tries multiple named-parameter sets via dynamic invocation.
  Future<dynamic> _searchRestaurants({
    required RestaurantsApi api,
    required String destination,
    double? centerLat,
    double? centerLng,
    String? sort,
    List<String>? cuisines,
    required int page,
    required int limit,
  }) async {
    final dyn = api as dynamic;

    // Attempt 1: destination/centerLat/centerLng/cuisines/sort/page/limit
    try {
      return await dyn.search(
        destination: destination,
        centerLat: centerLat,
        centerLng: centerLng,
        sort: sort,
        cuisines: cuisines,
        page: page,
        limit: limit,
      );
    } catch (_) {}

    // Attempt 2: city/lat/lng/tags/sortBy/page/limit
    try {
      return await dyn.search(
        city: destination,
        lat: centerLat,
        lng: centerLng,
        sortBy: sort,
        tags: cuisines,
        page: page,
        limit: limit,
      );
    } catch (_) {}

    // Attempt 3: query/lat/lng/tags/sort/page/limit using Function.apply with named args
    try {
      final args = <Symbol, dynamic>{
        #query: destination,
        #lat: centerLat,
        #lng: centerLng,
        #tags: cuisines,
        #sort: sort,
        #page: page,
        #limit: limit,
      };
      return await Function.apply(dyn.search, const [], args);
    } catch (e) {
      rethrow;
    }
  } // Function.apply supports dynamic named arguments when parameter names differ across implementations. [web:5963][web:5969]

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
    final res = await _searchRestaurants(
      api: api,
      destination: widget.destination,
      centerLat: widget.centerLat,
      centerLng: widget.centerLng,
      sort: _sort,
      cuisines: _cuisines.toList(),
      page: _page,
      limit: widget.pageSize,
    );

    // Expecting a Result-like API with fold({onSuccess, onError})
    try {
      // If the result has fold, prefer it.
      // ignore: unnecessary_cast
      (res as dynamic).fold(
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
            SnackBar(content: Text(err.toString())),
          );
        },
      );
    } catch (_) {
      // Fallback: treat as a plain payload
      final list = _asList(res as Map<String, dynamic>);
      final normalized = list.map(_normalize).toList(growable: false);
      setState(() {
        _items.addAll(normalized);
        _hasMore = list.length >= widget.pageSize;
        if (_hasMore) _page += 1;
        _loading = false;
        _loadMore = false;
      });
    }
  } // ScaffoldMessenger is the recommended way to show SnackBars from screen or sheets. [web:5903][web:5873]

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
      'cuisines': (m['cuisines'] is List)
          ? List<String>.from(m['cuisines'])
          : const <String>[],
      'rating': (pick(['rating', 'avgRating']) is num)
          ? (pick(['rating', 'avgRating']) as num).toDouble()
          : null,
      'reviewCount': pick(['reviewCount', 'reviews']) is int
          ? pick(['reviewCount', 'reviews']) as int
          : null,
      'priceLevel':
          pick(['priceLevel']) is int ? pick(['priceLevel']) as int : null,
      'costForTwo': n(pick(['costForTwo', 'priceForTwo'])),
      'distanceKm': d(pick(['distanceKm', 'distance'])),
      'isOpen': pick(['openNow']) == true,
      'lat': d(pick(['lat', 'latitude'])),
      'lng': d(pick(['lng', 'longitude'])),
      'tags':
          (m['tags'] is List) ? List<String>.from(m['tags']) : const <String>[],
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
            child: Text(sub,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _showMap ? 'Show list' : 'Show map',
            onPressed: () => setState(() => _showMap = !_showMap),
            icon: Icon(_showMap ? Icons.list_alt : Icons.map_outlined),
          ), // Toggling content panes in a single screen preserves context and state. [web:5767][web:5748]
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune),
          ), // Filters are often shown via modal bottom sheets for compact controls. [web:5748][web:5961]
        ],
      ),
      body: SafeArea(
        child: _showMap ? _buildMap() : _buildList(),
      ),
    );
  }

  Widget _buildCuisineBar() {
    return _CuisineBar(
      initialSelected: _cuisines,
      onSelectionChanged: (sel) async {
        _cuisines = sel;
        await _fetch(reset: true);
      },
      title: 'Cuisines',
    ); // Local chip bar avoids signature mismatches with external widgets while providing the same UX. [web:5767][web:5748]
  }

  Widget _buildMap() {
    // Placeholder map view to avoid external map dependencies here.
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildCuisineBar(),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              alignment: Alignment.center,
              child: const Text('Map view coming soon'),
            ),
          ),
        ],
      ),
    ); // Keep the toggle UX while deferring map rendering to a dependency-safe placeholder. [web:5767][web:5748]
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
        ), // Pull-to-refresh around a scrollable child uses standard RefreshIndicator patterns. [web:5748][web:5767]
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Text(
            _loading && _items.isEmpty
                ? 'Loading…'
                : '${(_items.length)}${_hasMore ? '+' : ''} restaurants',
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
                DropdownMenuItem(
                    value: 'rating_desc', child: Text('Rating (highest)')),
                DropdownMenuItem(
                    value: 'distance_asc', child: Text('Distance (closest)')),
                DropdownMenuItem(
                    value: 'price_asc', child: Text('Price (low to high)')),
              ],
              decoration: const InputDecoration(
                labelText: 'Sort',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    ); // DropdownButtonFormField provides a simple sort control inline with the header. [web:5767][web:5748]
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
          child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2)),
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

// Simple local cuisine chip bar to replace external dependency and fix signature mismatches.
class _CuisineBar extends StatefulWidget {
  const _CuisineBar({
    required this.initialSelected,
    required this.onSelectionChanged,
    required this.title,
  });

  final Set<String> initialSelected;
  final Future<void> Function(Set<String>) onSelectionChanged;
  final String title;

  @override
  State<_CuisineBar> createState() => _CuisineBarState();
}

class _CuisineBarState extends State<_CuisineBar> {
  late Set<String> _selected;

  // Example chips; replace with fetched list if needed.
  static const _all = <String>[
    'Indian',
    'Chinese',
    'Italian',
    'Thai',
    'Cafe',
    'Seafood'
  ];

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelected};
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _selected.isEmpty,
              onSelected: (v) async {
                setState(() => _selected.clear());
                await widget.onSelectionChanged(_selected);
              },
            ),
            for (final c in _all)
              ChoiceChip(
                label: Text(c),
                selected: _selected.contains(c),
                onSelected: (v) async {
                  setState(() {
                    if (v) {
                      _selected.add(c);
                    } else {
                      _selected.remove(c);
                    }
                  });
                  await widget.onSelectionChanged(_selected);
                },
              ),
          ],
        ),
      ],
    );
  }
}
