// lib/features/journey/presentation/places/place_results_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'widgets/place_booking_card.dart';
import 'place_booking_screen.dart';
import '../../data/places_api.dart';
// Optional: once created
// import 'widgets/place_filters.dart'; // exposes PlaceFilters.show(...)

class PlaceResultsScreen extends StatefulWidget {
  const PlaceResultsScreen({
    super.key,
    required this.destination, // city/region string or code
    this.dateIso, // YYYY-MM-DD (optional prefilter for availability)
    this.category, // e.g., "Attractions" | "Experiences"
    this.currency = '₹',
    this.title = 'Things to do',
    this.pageSize = 20,
    this.sort = 'price_asc', // price_asc | rating_desc | distance_asc | next_slot_asc
    this.centerLat,
    this.centerLng,
  });

  final String destination;
  final String? dateIso;
  final String? category;

  final String currency;
  final String title;
  final int pageSize;
  final String sort;

  final double? centerLat;
  final double? centerLng;

  @override
  State<PlaceResultsScreen> createState() => _PlaceResultsScreenState();
}

class _PlaceResultsScreenState extends State<PlaceResultsScreen> {
  final _scrollCtrl = ScrollController();

  bool _loading = false;
  bool _loadMore = false;
  bool _hasMore = true;
  int _page = 1;

  String? _sort;
  Map<String, dynamic> _filters = {}; // normalized map from a PlaceFilters sheet

  final List<Map<String, dynamic>> _items = [];

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
    if (_loadMore || _loading || !_hasMore) return;
    final pos = _scrollCtrl.position;
    final trigger = pos.maxScrollExtent * 0.9;
    if (pos.pixels > trigger) {
      _fetch();
    }
  } // Infinite scrolling via ScrollController at ~90% scroll extent is a common lazy-load pattern in Flutter lists [6][19]

  Future<void> _refresh() async {
    await _fetch(reset: true);
  } // Pull-to-refresh is implemented by RefreshIndicator wrapping the scrollable list with an async onRefresh [1][2]

  Future<void> _openFilters() async {
    // Plug in when PlaceFilters is added; meanwhile keep a placeholder map structure.
    // final res = await PlaceFilters.show(context, ...);
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // Minimal placeholder for now; replace with a real PlaceFilters widget.
        return Padding(
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
              const Text('Coming soon: categories, price, rating, distance, duration, open now.'),
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
        );
      },
    ); // showModalBottomSheet returns a Future that resolves to the chosen filters via Navigator.pop [10][18]

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

    final api = PlacesApi();
    final res = await api.search(
      destination: widget.destination,
      date: widget.dateIso,
      category: widget.category,
      sort: _sort,
      page: _page,
      limit: widget.pageSize,
      centerLat: widget.centerLat,
      centerLng: widget.centerLng,
      // Example pass-through for filters; wire these when PlaceFilters is in place.
      priceMin: (_filters['price']?['min'] as num?)?.toDouble(),
      priceMax: (_filters['price']?['max'] as num?)?.toDouble(),
      ratingMin: (_filters['rating']?['min'] as num?)?.toDouble(),
      ratingMax: (_filters['rating']?['max'] as num?)?.toDouble(),
      distanceMaxKm: (_filters['distanceKm']?['max'] as num?)?.toDouble(),
      durationMaxMin: (_filters['durationMin']?['max'] as int?),
      openNow: _filters['openNow'] as bool?,
      tags: (_filters['tags'] as Set?)?.cast<String>().toList(),
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
          SnackBar(content: Text(err.safeMessage ?? 'Failed to load places')),
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

    DateTime? dt(dynamic v) {
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return {
      'id': (pick(['id', '_id', 'placeId']) ?? '').toString(),
      'title': (pick(['title', 'name']) ?? '').toString(),
      'category': pick(['category', 'type'])?.toString(),
      'city': pick(['city', 'location'])?.toString(),
      'imageUrl': pick(['imageUrl', 'photo']),
      'rating': (pick(['rating', 'avgRating']) is num) ? (pick(['rating', 'avgRating']) as num).toDouble() : null,
      'reviewCount': pick(['reviewCount', 'reviews']) is int ? pick(['reviewCount', 'reviews']) as int : null,
      'priceFrom': n(pick(['priceFrom', 'amount', 'price'])),
      'durationMinutes': (pick(['durationMinutes', 'durationMin']) as int?) ?? (n(pick(['duration']))?.toInt()),
      'nextSlot': dt(pick(['nextSlotIso', 'nextSlot'])),
      'freeCancellation': pick(['freeCancellation']) == true,
      'instantConfirmation': pick(['instantConfirmation']) == true,
      'distanceKm': d(pick(['distanceKm', 'distance'])),
    };
  }

  void _openBooking(Map<String, dynamic> p) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlaceBookingScreen(
        placeId: (p['id'] ?? '').toString(),
        title: (p['title'] ?? '').toString(),
        currency: widget.currency,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    final sub = widget.dateIso == null
        ? '${widget.destination}${widget.category != null ? ' • ${widget.category}' : ''}'
        : '${widget.destination}${widget.category != null ? ' • ${widget.category}' : ''} • ${widget.dateIso} • ${df.format(DateTime.parse(widget.dateIso!))}';
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
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: _refresh,
          child: ListView.builder(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: _items.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return _buildHeader();
              if (index == _items.length + 1) return _buildFooterLoader();
              final p = _items[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PlaceBookingCard(
                  id: (p['id'] ?? '').toString(),
                  title: (p['title'] ?? '').toString(),
                  category: p['category']?.toString(),
                  city: p['city']?.toString(),
                  imageUrl: p['imageUrl']?.toString(),
                  rating: (p['rating'] as num?)?.toDouble(),
                  reviewCount: p['reviewCount'] as int?,
                  priceFrom: p['priceFrom'] as num?,
                  currency: widget.currency,
                  durationMinutes: p['durationMinutes'] as int?,
                  nextSlot: p['nextSlot'],
                  freeCancellation: p['freeCancellation'] == true,
                  instantConfirmation: p['instantConfirmation'] == true,
                  distanceKm: (p['distanceKm'] as num?)?.toDouble(),
                  onTap: () => _openBooking(p),
                  onBook: () => _openBooking(p),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Text(
            _loading && _items.isEmpty ? 'Loading…' : '${_items.length}${_hasMore ? '+' : ''} results',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              initialValue: _sort,
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
                DropdownMenuItem(value: 'next_slot_asc', child: Text('Next slot (earliest)')),
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
