// lib/features/journey/presentation/buses/bus_results_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/buses_api.dart';
import 'widgets/bus_card.dart';
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

  // Active filter params (mutable copies from widget.*)
  List<String>? _operators;
  List<String>? _classes;
  String? _q;
  double? _minPrice;
  double? _maxPrice;

  @override
  void initState() {
    super.initState();
    _sort = widget.sort;
    _operators = widget.operators == null ? null : List<String>.from(widget.operators!);
    _classes = widget.classes == null ? null : List<String>.from(widget.classes!);
    _q = widget.q;
    _minPrice = widget.minPrice;
    _maxPrice = widget.maxPrice;
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
      operators: _operators,
      classes: _classes,
      q: _q,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      sort: _sort,
      page: _page,
      limit: widget.pageSize,
    );

    if (!mounted) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.safeMessage)),
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
            onPressed: _openFilters, // implemented bottom sheet
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
              key: ValueKey(_sort),
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

  // Filters bottom sheet implementation
  Future<void> _openFilters() async {
    // Local mutable copies for UI
    String? sort = _sort;
    double? minPrice = _minPrice;
    double? maxPrice = _maxPrice;
    final classes = (_classes == null) ? <String>{} : _classes!.toSet();
    final operators = (_operators == null) ? <String>{} : _operators!.toSet();
    final qCtrl = TextEditingController(text: _q ?? '');

    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setM) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 4, width: 40, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
                    Text('Filters', style: Theme.of(ctx).textTheme.titleMedium),
                    const SizedBox(height: 12),

                    // Search text
                    TextField(
                      controller: qCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Query',
                        hintText: 'Operator, class, features…',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Price range
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Min price',
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(text: minPrice?.toStringAsFixed(0) ?? ''),
                            onChanged: (s) => setM(() => minPrice = double.tryParse(s)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max price',
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(text: maxPrice?.toStringAsFixed(0) ?? ''),
                            onChanged: (s) => setM(() => maxPrice = double.tryParse(s)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Classes quick chips (example set)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Classes', style: Theme.of(ctx).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in const ['AC', 'Non-AC', 'Sleeper', 'Seater'])
                          FilterChip(
                            label: Text(c),
                            selected: classes.contains(c),
                            onSelected: (v) => setM(() {
                              if (v) {
                                classes.add(c);
                              } else {
                                classes.remove(c);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Operators quick chips (example set)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Operators', style: Theme.of(ctx).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final o in const ['VRL', 'SRS', 'KSRTC', 'Orange'])
                          FilterChip(
                            label: Text(o),
                            selected: operators.contains(o),
                            onSelected: (v) => setM(() {
                              if (v) {
                                operators.add(o);
                              } else {
                                operators.remove(o);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Sort
                    DropdownButtonFormField<String>(
                      key: ValueKey(sort),
                      initialValue: sort,
                      decoration: const InputDecoration(
                        labelText: 'Sort by',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'price_asc', child: Text('Price (low to high)')),
                        DropdownMenuItem(value: 'departure_asc', child: Text('Departure time')),
                        DropdownMenuItem(value: 'rating_desc', child: Text('Rating')),
                      ],
                      onChanged: (v) => setM(() => sort = v),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setM(() {
                              qCtrl.text = '';
                              minPrice = null;
                              maxPrice = null;
                              classes.clear();
                              operators.clear();
                              sort = 'price_asc';
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).maybePop(_FilterResult(
                              sort: sort,
                              q: qCtrl.text.trim().isEmpty ? null : qCtrl.text.trim(),
                              minPrice: minPrice,
                              maxPrice: maxPrice,
                              classes: classes.isEmpty ? null : classes.toList(),
                              operators: operators.isEmpty ? null : operators.toList(),
                            ));
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _sort = result.sort ?? _sort;
        _q = result.q;
        _minPrice = result.minPrice;
        _maxPrice = result.maxPrice;
        _classes = result.classes;
        _operators = result.operators;
      });
      await _fetch(reset: true);
    }
  }
}

class _FilterResult {
  _FilterResult({
    this.sort,
    this.q,
    this.minPrice,
    this.maxPrice,
    this.classes,
    this.operators,
  });

  final String? sort;
  final String? q;
  final double? minPrice;
  final double? maxPrice;
  final List<String>? classes;
  final List<String>? operators;
}
