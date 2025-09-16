// lib/features/journey/presentation/flights/widgets/flight_filters.dart

import 'package:flutter/material.dart';

class FlightFilters extends StatefulWidget {
  const FlightFilters({
    super.key,
    // Price range in currency units (e.g., ₹)
    this.minPrice = 0,
    this.maxPrice = 100000,
    this.initialPriceMin,
    this.initialPriceMax,

    // Departure window in hours of day [0,24]
    this.initialDepartStartHour = 0,
    this.initialDepartEndHour = 24,

    // Stops
    this.initialStops = const <String>{}, // {'nonstop','1stop','2plus'}

    // Cabin classes
    this.cabins = const <String>['Economy', 'Premium', 'Business', 'First'],
    this.initialCabins = const <String>{},

    // Airlines multi-select (IATA code or name)
    this.airlines = const <String>[],
    this.initialAirlines = const <String>{},

    // Refundable
    this.initialRefundable,

    this.currency = '₹',
    this.title = 'Filters',
  });

  final double minPrice;
  final double maxPrice;
  final double? initialPriceMin;
  final double? initialPriceMax;

  final int initialDepartStartHour;
  final int initialDepartEndHour;

  final Set<String> initialStops;

  final List<String> cabins;
  final Set<String> initialCabins;

  final List<String> airlines;
  final Set<String> initialAirlines;

  final bool? initialRefundable;

  final String currency;
  final String title;

  @override
  State<FlightFilters> createState() => _FlightFiltersState();

  /// Helper to show as a modal bottom sheet and return a normalized filter map:
  /// {
  ///   'price': {'min': double, 'max': double},
  ///   'depart': {'startHour': int, 'endHour': int},
  ///   'stops': Set<String>, // {'nonstop','1stop','2plus'}
  ///   'cabins': Set<String>,
  ///   'airlines': Set<String>,
  ///   'refundable': bool|null
  /// }
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    double minPrice = 0,
    double maxPrice = 100000,
    double? initialPriceMin,
    double? initialPriceMax,
    int initialDepartStartHour = 0,
    int initialDepartEndHour = 24,
    Set<String> initialStops = const <String>{},
    List<String> cabins = const <String>['Economy', 'Premium', 'Business', 'First'],
    Set<String> initialCabins = const <String>{},
    List<String> airlines = const <String>[],
    Set<String> initialAirlines = const <String>{},
    bool? initialRefundable,
    String currency = '₹',
    String title = 'Filters',
  }) {
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: FlightFilters(
          minPrice: minPrice,
          maxPrice: maxPrice,
          initialPriceMin: initialPriceMin,
          initialPriceMax: initialPriceMax,
          initialDepartStartHour: initialDepartStartHour,
          initialDepartEndHour: initialDepartEndHour,
          initialStops: initialStops,
          cabins: cabins,
          initialCabins: initialCabins,
          airlines: airlines,
          initialAirlines: initialAirlines,
          initialRefundable: initialRefundable,
          currency: currency,
          title: title,
        ),
      ),
    );
  }
}

class _FlightFiltersState extends State<FlightFilters> {
  late RangeValues _price;
  late RangeValues _departHours; // 0..24

  late Set<String> _stops; // 'nonstop','1stop','2plus'
  late Set<String> _cabins;
  late Set<String> _airlines;

  bool? _refundable;

  @override
  void initState() {
    super.initState();
    final pMin = widget.initialPriceMin ?? widget.minPrice;
    final pMax = widget.initialPriceMax ?? widget.maxPrice;
    _price = RangeValues(
      pMin.clamp(widget.minPrice, widget.maxPrice),
      pMax.clamp(widget.minPrice, widget.maxPrice),
    );
    _departHours = RangeValues(
      widget.initialDepartStartHour.toDouble().clamp(0, 24),
      widget.initialDepartEndHour.toDouble().clamp(0, 24),
    );
    _stops = {...widget.initialStops};
    _cabins = {...widget.initialCabins};
    _airlines = {...widget.initialAirlines};
    _refundable = widget.initialRefundable;
  }

  void _reset() {
    setState(() {
      _price = RangeValues(widget.minPrice, widget.maxPrice);
      _departHours = const RangeValues(0, 24);
      _stops.clear();
      _cabins.clear();
      _airlines.clear();
      _refundable = null;
    });
  }

  void _apply() {
    Navigator.of(context).pop(<String, dynamic>{
      'price': {'min': _price.start, 'max': _price.end},
      'depart': {'startHour': _departHours.start.round(), 'endHour': _departHours.end.round()},
      'stops': _stops,
      'cabins': _cabins,
      'airlines': _airlines,
      'refundable': _refundable,
    });
  }

  String _hourLabel(double h) {
    final v = h.round().clamp(0, 24);
    final hh = v % 24;
    final am = hh < 12 ? 'AM' : 'PM';
    final disp = hh == 0 ? 12 : (hh <= 12 ? hh : hh - 12);
    return '$disp $am';
  }

  @override
  Widget build(BuildContext context) {
    final spacing = 8.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Reset'),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Price range
            _SectionTitle('Price'),
            Row(
              children: [
                Expanded(
                  child: RangeSlider(
                    values: _price,
                    min: widget.minPrice,
                    max: widget.maxPrice,
                    divisions: 20,
                    labels: RangeLabels(
                      '${widget.currency}${_price.start.round()}',
                      '${widget.currency}${_price.end.round()}',
                    ),
                    onChanged: (v) => setState(() => _price = v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text('${widget.currency}${_price.start.round()}'),
                const Spacer(),
                Text('${widget.currency}${_price.end.round()}'),
              ],
            ),

            const SizedBox(height: 12),

            // Departure window
            _SectionTitle('Departure time'),
            RangeSlider(
              values: _departHours,
              min: 0,
              max: 24,
              divisions: 24,
              labels: RangeLabels(_hourLabel(_departHours.start), _hourLabel(_departHours.end)),
              onChanged: (v) => setState(() => _departHours = v),
            ),
            Row(
              children: [
                Text(_hourLabel(_departHours.start)),
                const Spacer(),
                Text(_hourLabel(_departHours.end)),
              ],
            ),

            const SizedBox(height: 12),

            // Stops
            _SectionTitle('Stops'),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StopChip(label: 'Non‑stop', keyValue: 'nonstop', selected: _stops.contains('nonstop'), onToggle: _toggleStop),
                _StopChip(label: '1 stop', keyValue: '1stop', selected: _stops.contains('1stop'), onToggle: _toggleStop),
                _StopChip(label: '2+ stops', keyValue: '2plus', selected: _stops.contains('2plus'), onToggle: _toggleStop),
              ],
            ),

            const SizedBox(height: 12),

            // Cabins
            _SectionTitle('Cabin'),
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: widget.cabins.map((c) {
                final sel = _cabins.contains(c);
                return FilterChip(
                  label: Text(c),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    if (sel) {
                      _cabins.remove(c);
                    } else {
                      _cabins.add(c);
                    }
                  }),
                );
              }).toList(growable: false),
            ),

            const SizedBox(height: 12),

            // Airlines
            if (widget.airlines.isNotEmpty) ...[
              _SectionTitle('Airlines'),
              SizedBox(
                height: 120,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: widget.airlines.map((a) {
                      final sel = _airlines.contains(a);
                      return FilterChip(
                        label: Text(a),
                        selected: sel,
                        onSelected: (_) => setState(() {
                          if (sel) {
                            _airlines.remove(a);
                          } else {
                            _airlines.add(a);
                          }
                        }),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Refundable
            Row(
              children: [
                const Icon(Icons.currency_exchange, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                const Text('Refundable'),
                const Spacer(),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Yes')),
                    ButtonSegment(value: 0, label: Text('No')),
                    ButtonSegment(value: -1, label: Text('Any')),
                  ],
                  selected: {
                    _refundable == null
                        ? -1
                        : (_refundable! ? 1 : 0)
                  },
                  onSelectionChanged: (s) {
                    final v = s.first;
                    setState(() {
                      if (v == -1) {
                        _refundable = null;
                      } else {
                        _refundable = v == 1;
                      }
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Apply
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Apply filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStop(String key) {
    setState(() {
      if (_stops.contains(key)) {
        _stops.remove(key);
      } else {
        _stops.add(key);
      }
    });
  }
}

class _StopChip extends StatelessWidget {
  const _StopChip({
    required this.label,
    required this.keyValue,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final String keyValue;
  final bool selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onToggle(keyValue),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
