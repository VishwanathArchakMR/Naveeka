// lib/features/journey/presentation/buses/bus_results_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/buses_api.dart';
import 'widgets/bus_card.dart';
import 'widgets/bus_route_map.dart';
import 'bus_booking_screen.dart';

class BusResultsScreen extends StatefulWidget {
  const BusResultsScreen({
    super.key,
    required this.fromCode,
    required this.toCode,
    required this.date, // YYYY-MM-DD
    this.returnDate,
    this.operators,
    this.classes,
    this.q,
    this.minPrice,
    this.maxPrice,
    this.sort = 'price_asc', // price_asc | departure_asc | rating_desc
    this.pageSize = 20,
    this.title = 'Buses',
    this.currency = '₹',
  });

  final String fromCode;
  final String toCode;
  final String date;
  final String? returnDate;

  final List<String>? operators;
  final List<String>? classes;
  final String? q;

  final double? minPrice;
  final double? maxPrice;

  final String sort;
  final int pageSize;
  final String title;
  final String currency;

  @override
  State<BusResultsScreen> createState() => _BusResultsScreenState();
}

class _BusResultsScreenState extends State<BusResultsScreen> {
  final _scrollCtrl = ScrollController();

  bool _loading = false;
  bool _loadMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _sort;

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
  }

  Future<void> _refresh() async {
    await _fetch(reset: true);
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

    final api = BusesApi();
    final res = await api.search(
      fromCode: widget.fromCode,
      toCode: widget.toCode,
      date: widget.date,
      returnDate: widget.returnDate,
      operators: widget.operators,
      classes: widget.classes,
      q: widget.q,
      minPrice: widget.minPrice,
      maxPrice: widget.maxPrice,
      sort: _sort,
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
          SnackBar(content: Text(err.safeMessage ?? 'Failed to load buses')),
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

    return <String, dynamic>{
      'id': (pick(['id', '_id', 'tripId']) ?? '').toString(),
      'operator': (pick(['operator', 'operatorName']) ?? '').toString(),
      'fromCity': (pick(['fromCity', 'sourceName']) ?? widget.fromCode).toString(),
      'toCity': (pick(['toCity', 'destinationName']) ?? widget.toCode).toString(),
      'dep': pick(['departureTime', 'depTime', 'startTime']),
      'arr': pick(['arrivalTime', 'arrTime', 'endTime']),
      'busType': pick(['busType', 'class', 'category']),
      'features': (m['features'] is List) ? List<String>.from(m['features']) : const <String>[],
      'rating': d(pick(['rating', 'avgRating'])),
      'ratingCount': pick(['ratingCount', 'reviews']),
      'seatsLeft': pick(['seatsLeft', 'availableSeats']),
      'fareFrom': pick(['fareFrom', 'priceFrom', 'minFare']),
      'stops': (m['stops'] is List) ? List<Map<String, dynamic>>.from(m['stops']) : const <Map<String, dynamic>>[],
      'routePoints': (m['routePoints'] is List)
          ? List<Map<String, dynamic>>.from(m['routePoints'])
          : const <Map<String, dynamic>>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${widget.fromCode} → ${widget.toCode} • ${widget.date} • ${df.format(DateTime.parse(widget.date))}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () {
              // TODO: Present filters bottom sheet; update _sort/params then _fetch(reset:true)
            },
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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
          final bus = _items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BusCard(
              id: (bus['id'] ?? '').toString(),
              operatorName: (bus['operator'] ?? '').toString(),
              departureTime: bus['dep'],
              arrivalTime: bus['arr'],
              fromCity: (bus['fromCity'] ?? '').toString(),
              toCity: (bus['toCity'] ?? '').toString(),
              busType: bus['busType'] as String?,
              features: (bus['features'] as List).cast<String>(),
              rating: (bus['rating'] as num?)?.toDouble(),
              ratingCount: bus['ratingCount'] as int?,
              seatsLeft: bus['seatsLeft'] is int ? bus['seatsLeft'] as int : null,
              fareFrom: bus['fareFrom'] is num ? bus['fareFrom'] as num : null,
              currency: widget.currency,
              onTap: () => _openBooking(bus),
              onViewSeats: () => _openBooking(bus),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Text(
            _loading && _items.isEmpty ? 'Loading…' : '${_items.length}${_hasMore ? '+' : ''} buses',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          SizedBox(
            width: 200,
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
                DropdownMenuItem(value: 'departure_asc', child: Text('Departure')),
                DropdownMenuItem(value: 'rating_desc', child: Text('Rating')),
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

  void _openBooking(Map<String, dynamic> bus) {
    final operatorName = (bus['operator'] ?? '').toString();
    final fromCity = (bus['fromCity'] ?? widget.fromCode).toString();
    final toCity = (bus['toCity'] ?? widget.toCode).toString();
    final title = '$operatorName • $fromCity → $toCity';

    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BusBookingScreen(
        busId: (bus['id'] ?? '').toString(),
        title: title,
        date: widget.date,
        fromCode: widget.fromCode,
        toCode: widget.toCode,
        currency: widget.currency,
      ),
    ));
  }

  void _openRoutePreview(Map<String, dynamic> bus) {
    // Optional route preview bottom sheet (hook this from an icon/action if desired)
    final stops = (bus['stops'] as List<Map<String, dynamic>>?) ?? const <Map<String, dynamic>>[];
    final pts = (bus['routePoints'] as List<Map<String, dynamic>>?) ?? const <Map<String, dynamic>>[];

    // Try building a polyline if route points exist
    final poly = pts
        .map((p) {
          final lat = p['lat'];
          final lng = p['lng'];
          double? d(dynamic v) {
            if (v is double) return v;
            if (v is int) return v.toDouble();
            if (v is String) return double.tryParse(v);
            return null;
          }

          final la = d(lat), ln = d(lng);
          if (la == null || ln == null) return null;
          return LatLng(la, ln);
        })
        .whereType<LatLng>()
        .toList(growable: false);

    // Origin/destination fallbacks from first/last stop if known
    double? dval(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final double? oLat = stops.isNotEmpty ? dval(stops.first['lat']) : null;
    final double? oLng = stops.isNotEmpty ? dval(stops.first['lng']) : null;
    final double? dLat = stops.isNotEmpty ? dval(stops.last['lat']) : null;
    final double? dLng = stops.isNotEmpty ? dval(stops.last['lng']) : null;

    if (oLat == null || oLng == null || dLat == null || dLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route preview not available')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 4, width: 40, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
              Text('Route preview', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              BusRouteMap(
                originLat: oLat,
                originLng: oLng,
                destinationLat: dLat,
                destinationLng: dLng,
                stops: stops,
                routePoints: poly.isEmpty ? null : poly,
                height: 300,
              ),
            ],
          ),
        );
      },
    );
  }
}
