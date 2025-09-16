// lib/features/journey/presentation/flights/flight_results_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/flight_card.dart';
import '../widgets/flight_filters.dart';
import '../flight_booking_screen.dart';
import '../../data/flights_api.dart';

class FlightResultsScreen extends StatefulWidget {
  const FlightResultsScreen({
    super.key,
    required this.fromCode,
    required this.toCode,
    required this.date, // YYYY-MM-DD
    this.returnDate, // optional for round-trip browsing
    this.cabin, // "Economy" | "Premium" | "Business" | "First"
    this.adults = 1,
    this.children = 0,
    this.infants = 0,
    this.currency = '₹',
    this.title = 'Flights',
    this.pageSize = 20,
    this.sort = 'price_asc', // price_asc | duration_asc | dep_asc
  });

  final String fromCode;
  final String toCode;
  final String date;
  final String? returnDate;

  final String? cabin;
  final int adults;
  final int children;
  final int infants;

  final String currency;
  final String title;
  final int pageSize;
  final String sort;

  @override
  State<FlightResultsScreen> createState() => _FlightResultsScreenState();
}

class _FlightResultsScreenState extends State<FlightResultsScreen> {
  final _scrollCtrl = ScrollController();

  bool _loading = false;
  bool _loadMore = false;
  bool _hasMore = true;
  int _page = 1;

  String? _sort;
  Map<String, dynamic> _filters = {}; // normalized shape from FlightFilters.show

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

  Future<void> _openFilters() async {
    final res = await FlightFilters.show(
      context,
      title: 'Filters',
      minPrice: 0,
      maxPrice: 150000,
      initialPriceMin: (_filters['price']?['min'] as num?)?.toDouble(),
      initialPriceMax: (_filters['price']?['max'] as num?)?.toDouble(),
      initialDepartStartHour: (_filters['depart']?['startHour'] as int?) ?? 0,
      initialDepartEndHour: (_filters['depart']?['endHour'] as int?) ?? 24,
      initialStops: (_filters['stops'] as Set?)?.cast<String>() ?? const <String>{},
      cabins: const ['Economy', 'Premium', 'Business', 'First'],
      initialCabins: (_filters['cabins'] as Set?)?.cast<String>() ?? (widget.cabin != null ? {widget.cabin!} : const <String>{}),
      airlines: const <String>[], // optionally pass known airlines from search prefetch
      initialAirlines: (_filters['airlines'] as Set?)?.cast<String>() ?? const <String>{},
      initialRefundable: _filters['refundable'] as bool?,
      currency: widget.currency,
    ); // showModalBottomSheet returns the chosen filters via Navigator.pop result [13][7]

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

    final api = FlightsApi();
    final res = await api.search(
      from: widget.fromCode,
      to: widget.toCode,
      date: widget.date,
      returnDate: widget.returnDate,
      cabin: widget.cabin,
      adults: widget.adults,
      children: widget.children,
      infants: widget.infants,
      sort: _sort,
      page: _page,
      limit: widget.pageSize,
      // Filters normalization: pass-through popular constraints when available
      priceMin: (_filters['price']?['min'] as num?)?.toDouble(),
      priceMax: (_filters['price']?['max'] as num?)?.toDouble(),
      departStartHour: (_filters['depart']?['startHour'] as int?),
      departEndHour: (_filters['depart']?['endHour'] as int?),
      stops: (_filters['stops'] as Set?)?.cast<String>().toList(),
      cabins: (_filters['cabins'] as Set?)?.cast<String>().toList(),
      airlines: (_filters['airlines'] as Set?)?.cast<String>().toList(),
      refundable: _filters['refundable'] as bool?,
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
          SnackBar(content: Text(err.safeMessage ?? 'Failed to load flights')),
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

    DateTime? dt(dynamic v) {
      if (v is DateTime) return v;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    num? n(dynamic v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    }

    return {
      'id': (pick(['id', 'offerId', 'fareId']) ?? '').toString(),
      'airline': (pick(['airline', 'marketingCarrierName']) ?? '').toString(),
      'flightNumber': (pick(['flightNumber', 'marketingCarrierCode']) ?? '').toString(),
      'airlineLogoUrl': pick(['airlineLogoUrl']),
      'fromCode': (pick(['from', 'origin']) ?? widget.fromCode).toString(),
      'toCode': (pick(['to', 'destination']) ?? widget.toCode).toString(),
      'dep': dt(pick(['departureTime', 'dep', 'start'])),
      'arr': dt(pick(['arrivalTime', 'arr', 'end'])),
      'stops': (pick(['stops']) ?? 0) as int,
      'layovers': (m['layovers'] is List) ? List<String>.from(m['layovers']) : const <String>[],
      'durationLabel': pick(['durationLabel', 'duration']),
      'fareFrom': n(pick(['fareFrom', 'price', 'amount'])),
      'cabin': (pick(['cabin']) ?? widget.cabin)?.toString(),
      'refundable': pick(['refundable']),
      'badges': (m['badges'] is List) ? List<String>.from(m['badges']) : const <String>[],
    };
  }

  void _openBooking(Map<String, dynamic> f) {
    final airline = (f['airline'] ?? '').toString();
    final from = (f['fromCode'] ?? widget.fromCode).toString();
    final to = (f['toCode'] ?? widget.toCode).toString();
    final title = '$airline • $from → $to';
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FlightBookingScreen(
        flightId: (f['id'] ?? '').toString(),
        title: title,
        date: widget.date,
        currency: widget.currency,
      ),
    ));
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
              final f = _items[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FlightCard(
                  id: (f['id'] ?? '').toString(),
                  airline: (f['airline'] ?? '').toString(),
                  flightNumber: (f['flightNumber'] ?? '').toString(),
                  airlineLogoUrl: f['airlineLogoUrl'] as String?,
                  fromCode: (f['fromCode'] ?? '').toString(),
                  toCode: (f['toCode'] ?? '').toString(),
                  departureTime: f['dep'],
                  arrivalTime: f['arr'],
                  stops: f['stops'] as int? ?? 0,
                  layoverCities: (f['layovers'] as List).cast<String>(),
                  durationLabel: f['durationLabel'] as String?,
                  fareFrom: f['fareFrom'] as num?,
                  currency: widget.currency,
                  cabin: f['cabin'] as String?,
                  refundable: f['refundable'] as bool?,
                  badges: (f['badges'] as List).cast<String>(),
                  onTap: () => _openBooking(f),
                  onBook: () => _openBooking(f),
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
            _loading && _items.isEmpty ? 'Loading…' : '${_items.length}${_hasMore ? '+' : ''} flights',
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
                DropdownMenuItem(value: 'duration_asc', child: Text('Duration (shortest)')),
                DropdownMenuItem(value: 'dep_asc', child: Text('Departure (earliest)')),
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
