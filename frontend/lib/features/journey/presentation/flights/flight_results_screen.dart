// lib/features/journey/presentation/flights/flight_results_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      airlines: const <String>[],
      initialAirlines: (_filters['airlines'] as Set?)?.cast<String>() ?? const <String>{},
      initialRefundable: _filters['refundable'] as bool?,
      currency: widget.currency,
    );
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

    try {
      final data = await _fakeSearch(
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
        priceMin: (_filters['price']?['min'] as num?)?.toDouble(),
        priceMax: (_filters['price']?['max'] as num?)?.toDouble(),
        departStartHour: (_filters['depart']?['startHour'] as int?),
        departEndHour: (_filters['depart']?['endHour'] as int?),
        stops: (_filters['stops'] as Set?)?.cast<String>().toList(),
        cabins: (_filters['cabins'] as Set?)?.cast<String>().toList(),
        airlines: (_filters['airlines'] as Set?)?.cast<String>().toList(),
        refundable: _filters['refundable'] as bool?,
      );

      final list = _asList(data);
      final normalized = list.map(_normalize).toList(growable: false);
      setState(() {
        _items.addAll(normalized);
        _hasMore = list.length >= widget.pageSize;
        if (_hasMore) _page += 1;
        _loading = false;
        _loadMore = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _loadMore = false;
        _hasMore = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load flights')),
      );
    }
  }

  // Local mock search to avoid missing backend or invalid named params.
  Future<Map<String, dynamic>> _fakeSearch({
    required String from,
    required String to,
    required String date,
    String? returnDate,
    String? cabin,
    required int adults,
    required int children,
    required int infants,
    String? sort,
    required int page,
    required int limit,
    double? priceMin,
    double? priceMax,
    int? departStartHour,
    int? departEndHour,
    List<String>? stops,
    List<String>? cabins,
    List<String>? airlines,
    bool? refundable,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final baseDep = DateTime.parse(date).add(Duration(hours: (page - 1) * 2));
    final results = <Map<String, dynamic>>[];
    final count = page >= 3 ? (limit ~/ 2) : limit;
    for (var i = 0; i < count; i++) {
      final dep = baseDep.add(Duration(minutes: i * 15));
      final durMin = 90 + (i * 10);
      final arr = dep.add(Duration(minutes: durMin));
      results.add({
        'id': 'FL-$page-${i + 1}',
        'airline': ['IndiGo', 'Air India', 'Vistara'][i % 3],
        'flightNumber': 'AI${100 + i}',
        'airlineLogoUrl': null,
        'from': from,
        'to': to,
        'departureTime': dep.toIso8601String(),
        'arrivalTime': arr.toIso8601String(),
        'stops': i % 2,
        'layovers': i % 2 == 0 ? [] : ['BOM'],
        'durationLabel': '${(durMin / 60).floor()}h ${durMin % 60}m',
        'price': 3200 + (i * 150),
        'cabin': cabin ?? 'Economy',
        'refundable': i % 3 == 0,
        'badges': i % 4 == 0 ? ['Lowest'] : <String>[],
      });
    }
    return {'data': results};
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
      builder: (_) => _InlineFlightBookingScreen(
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
              initialValue: _sort,
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

/* ---------- Local minimal widgets/helpers to replace missing imports ---------- */

class FlightCard extends StatelessWidget {
  const FlightCard({
    super.key,
    required this.id,
    required this.airline,
    required this.flightNumber,
    required this.airlineLogoUrl,
    required this.fromCode,
    required this.toCode,
    required this.departureTime,
    required this.arrivalTime,
    required this.stops,
    required this.layoverCities,
    required this.durationLabel,
    required this.fareFrom,
    required this.currency,
    required this.cabin,
    required this.refundable,
    required this.badges,
    this.onTap,
    this.onBook,
  });

  final String id;
  final String airline;
  final String flightNumber;
  final String? airlineLogoUrl;
  final String fromCode;
  final String toCode;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
  final int stops;
  final List<String> layoverCities;
  final String? durationLabel;
  final num? fareFrom;
  final String currency;
  final String? cabin;
  final bool? refundable;
  final List<String> badges;
  final VoidCallback? onTap;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.Hm();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                child: Text(airline.isEmpty ? 'FL' : airline.characters.take(2).toString()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$airline • $flightNumber', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '$fromCode ${departureTime == null ? '' : df.format(departureTime!)} → $toCode ${arrivalTime == null ? '' : df.format(arrivalTime!)}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${durationLabel ?? ''} • ${stops == 0 ? 'Non-stop' : '$stops stop'}${layoverCities.isEmpty ? '' : ' • ${layoverCities.join(', ')}'}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    if (cabin != null || refundable != null || badges.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: -6,
                        children: [
                          if (cabin != null) Chip(label: Text(cabin!), visualDensity: VisualDensity.compact),
                          if (refundable == true) const Chip(label: Text('Refundable'), visualDensity: VisualDensity.compact),
                          ...badges.map((b) => Chip(label: Text(b), visualDensity: VisualDensity.compact)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fareFrom == null ? '-' : '$currency${fareFrom!.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onBook ?? onTap,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text('Book'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FlightFilters {
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String title,
    required double minPrice,
    required double maxPrice,
    double? initialPriceMin,
    double? initialPriceMax,
    required int initialDepartStartHour,
    required int initialDepartEndHour,
    required Set<String> initialStops,
    required List<String> cabins,
    required Set<String> initialCabins,
    required List<String> airlines,
    required Set<String> initialAirlines,
    bool? initialRefundable,
    required String currency,
  }) async {
    // Simple immediate return of provided initial values; replace with a modal UI as needed.
    return {
      'price': {'min': initialPriceMin, 'max': initialPriceMax},
      'depart': {'startHour': initialDepartStartHour, 'endHour': initialDepartEndHour},
      'stops': initialStops,
      'cabins': initialCabins,
      'airlines': initialAirlines,
      'refundable': initialRefundable,
    };
  }
}

class _InlineFlightBookingScreen extends StatelessWidget {
  const _InlineFlightBookingScreen({
    required this.flightId,
    required this.title,
    required this.date,
    required this.currency,
  });

  final String flightId;
  final String title;
  final String date;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMEd();
    return Scaffold(
      appBar: AppBar(title: Text('Book: $title')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Flight: $flightId'),
            const SizedBox(height: 8),
            Text('Date: ${df.format(DateTime.parse(date))}'),
            const SizedBox(height: 8),
            Text('Currency: $currency'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop({'confirmation': 'DEMO-${DateTime.now().millisecondsSinceEpoch}'}),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm (demo)'),
            ),
          ],
        ),
      ),
    );
  }
}
