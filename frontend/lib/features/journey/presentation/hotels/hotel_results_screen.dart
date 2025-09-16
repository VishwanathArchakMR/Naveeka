// lib/features/journey/presentation/hotels/hotel_results_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'widgets/hotel_card.dart';
import 'widgets/hotel_filters.dart';
import 'widgets/hotel_map_view.dart';
import 'hotel_booking_screen.dart';
import '../../data/hotels_api.dart';

class HotelResultsScreen extends StatefulWidget {
  const HotelResultsScreen({
    super.key,
    required this.destination, // city/area name or code for API
    required this.checkInIso,  // YYYY-MM-DD
    required this.checkOutIso, // YYYY-MM-DD
    this.rooms = 1,
    this.adults = 2,
    this.children = 0,
    this.childrenAges = const <int>[],
    this.currency = '₹',
    this.title = 'Hotels',
    this.pageSize = 20,
    this.sort = 'price_asc', // price_asc | rating_desc | distance_asc
    this.centerLat,
    this.centerLng,
  });

  final String destination;
  final String checkInIso;
  final String checkOutIso;

  final int rooms;
  final int adults;
  final int children;
  final List<int> childrenAges;

  final String currency;
  final String title;
  final int pageSize;
  final String sort;

  /// Optional map center hint (e.g., city center) for distance and map fit.
  final double? centerLat;
  final double? centerLng;

  @override
  State<HotelResultsScreen> createState() => _HotelResultsScreenState();
}

class _HotelResultsScreenState extends State<HotelResultsScreen> {
  final _scrollCtrl = ScrollController();

  bool _loading = false;
  bool _loadMore = false;
  bool _hasMore = true;
  int _page = 1;

  String? _sort;
  Map<String, dynamic> _filters = {}; // normalized from HotelFilters.show

  final List<Map<String, dynamic>> _items = [];

  bool _showMap = false;
  String? _selectedHotelId; // highlight marker

  @override
  void initState() {
    super.initState();
    _sort = widget.sort;
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
    if (_showMap) return; // list paging only in list mode
    if (_loadMore || _loading || !_hasMore) return;
    final pos = _scrollCtrl.position;
    final trigger = pos.maxScrollExtent * 0.9;
    if (pos.pixels > trigger) {
      _fetch();
    }
  }

  Future<void> _refresh() async {
    await _fetch(reset: true);
  }

  Future<void> _openFilters() async {
    final res = await HotelFilters.show(
      context,
      title: 'Filters',
      minPrice: 0,
      maxPrice: 250000,
      initialPriceMin: (_filters['price']?['min'] as num?)?.toDouble(),
      initialPriceMax: (_filters['price']?['max'] as num?)?.toDouble(),
      initialStars: (_filters['stars'] as Set?)?.cast<int>() ?? const <int>{},
      initialGuestRatingMin: (_filters['guestRating']?['min'] as int?) ?? 0,
      initialGuestRatingMax: (_filters['guestRating']?['max'] as int?) ?? 10,
      minDistanceKm: 0,
      maxDistanceKm: 50,
      initialDistanceMinKm: (_filters['distanceKm']?['min'] as num?)?.toDouble(),
      initialDistanceMaxKm: (_filters['distanceKm']?['max'] as num?)?.toDouble(),
      amenities: const <String>[], // optionally feed from prefetch
      initialAmenities: (_filters['amenities'] as Set?)?.cast<String>() ?? const <String>{},
      propertyTypes: const ['Hotel', 'Apartment', 'Resort', 'Villa', 'Hostel'],
      initialPropertyTypes: (_filters['propertyTypes'] as Set?)?.cast<String>() ?? const <String>{},
      chains: const <String>[], // optionally feed from prefetch
      initialChains: (_filters['chains'] as Set?)?.cast<String>() ?? const <String>{},
      initialRefundable: _filters['refundable'] as bool?,
      initialPayAtHotel: _filters['payAtHotel'] as bool?,
      initialBreakfast: _filters['breakfastIncluded'] as bool?,
      currency: widget.currency,
    ); // Presented as a modal bottom sheet; returns a normalized map on pop for easy downstream use [2][3]
    if (res != null) {
      setState(() => _filters = res);
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

    final api = HotelsApi();
    final res = await api.search(
      destination: widget.destination,
      checkIn: widget.checkInIso,
      checkOut: widget.checkOutIso,
      rooms: widget.rooms,
      adults: widget.adults,
      children: widget.children,
      childrenAges: widget.childrenAges,
      sort: _sort,
      page: _page,
      limit: widget.pageSize,
      centerLat: widget.centerLat,
      centerLng: widget.centerLng,
      // Filters (optional)
      priceMin: (_filters['price']?['min'] as num?)?.toDouble(),
      priceMax: (_filters['price']?['max'] as num?)?.toDouble(),
      stars: (_filters['stars'] as Set?)?.cast<int>().toList(),
      guestRatingMin: (_filters['guestRating']?['min'] as int?),
      guestRatingMax: (_filters['guestRating']?['max'] as int?),
      distanceMinKm: (_filters['distanceKm']?['min'] as num?)?.toDouble(),
      distanceMaxKm: (_filters['distanceKm']?['max'] as num?)?.toDouble(),
      amenities: (_filters['amenities'] as Set?)?.cast<String>().toList(),
      propertyTypes: (_filters['propertyTypes'] as Set?)?.cast<String>().toList(),
      chains: (_filters['chains'] as Set?)?.cast<String>().toList(),
      refundable: _filters['refundable'] as bool?,
      payAtHotel: _filters['payAtHotel'] as bool?,
      breakfastIncluded: _filters['breakfastIncluded'] as bool?,
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
          SnackBar(content: Text(err.safeMessage ?? 'Failed to load hotels')),
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
      'id': (pick(['id', '_id', 'hotelId']) ?? '').toString(),
      'name': (pick(['name', 'title']) ?? '').toString(),
      'city': pick(['city'])?.toString(),
      'area': pick(['area', 'neighbourhood'])?.toString(),
      'imageUrl': pick(['imageUrl', 'coverUrl', 'photo']),
      'rating': (pick(['rating', 'guestRating']) is num) ? (pick(['rating', 'guestRating']) as num).toDouble() : null,
      'reviewCount': pick(['reviewCount', 'reviews']) is int ? pick(['reviewCount', 'reviews']) as int : null,
      'pricePerNight': n(pick(['pricePerNight', 'price', 'amount'])),
      'lat': d(pick(['lat', 'latitude'])),
      'lng': d(pick(['lng', 'longitude'])),
      'distanceKm': d(pick(['distanceKm', 'distance'])),
      'freeCancellation': pick(['freeCancellation']) == true,
      'payAtHotel': pick(['payAtHotel']) == true,
      'amenities': (m['amenities'] is List) ? List<String>.from(m['amenities']) : const <String>[],
    };
  }

  void _openBooking(Map<String, dynamic> h) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HotelBookingScreen(
        hotelId: (h['id'] ?? '').toString(),
        hotelName: (h['name'] ?? '').toString(),
        checkInIso: widget.checkInIso,
        checkOutIso: widget.checkOutIso,
        currency: widget.currency,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    final sub = '${widget.destination} • ${widget.checkInIso} → ${widget.checkOutIso} • '
        '${df.format(DateTime.parse(widget.checkInIso))} → ${df.format(DateTime.parse(widget.checkOutIso))}';
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
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: _showMap ? _buildMap() : _buildList(),
      ),
    );
  }

  Widget _buildMap() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: HotelMapView(
        hotels: _items,
        height: MediaQuery.of(context).size.height - 160,
        currency: widget.currency,
        selectedHotelId: _selectedHotelId,
        onTapHotel: (h) {
          setState(() => _selectedHotelId = (h['id'] ?? '').toString());
          _openBooking(h);
        },
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return _buildHeader();
          if (index == _items.length + 1) return _buildFooterLoader();
          final h = _items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HotelCard(
              id: (h['id'] ?? '').toString(),
              name: (h['name'] ?? '').toString(),
              city: h['city']?.toString(),
              area: h['area']?.toString(),
              imageUrl: h['imageUrl']?.toString(),
              rating: (h['rating'] as num?)?.toDouble(),
              reviewCount: h['reviewCount'] as int?,
              pricePerNight: h['pricePerNight'] as num?,
              currency: widget.currency,
              distanceKm: (h['distanceKm'] as num?)?.toDouble(),
              freeCancellation: h['freeCancellation'] == true,
              payAtHotel: h['payAtHotel'] == true,
              amenities: (h['amenities'] as List).cast<String>(),
              onTap: () => _openBooking(h),
              onViewRooms: () => _openBooking(h),
            ),
          );
        },
      ),
    ); // Pull-to-refresh wraps the scrollable list via RefreshIndicator for standard swipe-to-refresh UX [1]
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Text(
            _loading && _items.isEmpty ? 'Loading…' : '${_items.length}${_hasMore ? '+' : ''} hotels',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _sort,
              isDense: true,
              icon: const Icon(Icons.sort),
              onChanged: (v) async {
                setState(() => _sort = v);
                await _fetch(reset: true);
              },
              items: const [
                DropdownMenuItem(value: 'price_asc', child: Text('Price (low to high)')),
                DropdownMenuItem(value: 'rating_desc', child: Text('Rating (highest)')),
                DropdownMenuItem(value: 'distance_asc', child: Text('Distance (closest)')),
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
    );
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
