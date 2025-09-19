// lib/features/journey/presentation/flights/flight_search_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'flight_results_screen.dart';
import 'widgets/airport_selector.dart';

class FlightSearchScreen extends StatefulWidget {
  const FlightSearchScreen({
    super.key,
    this.title = 'Search flights',
    this.initialFrom,
    this.initialTo,
    this.initialCabin = 'Economy',
    this.currency = '₹',
  });

  /// Optional preselected airports: {code,name,city,country,lat?,lng?}
  final Map<String, dynamic>? initialFrom;
  final Map<String, dynamic>? initialTo;

  final String initialCabin;
  final String title;
  final String currency;

  @override
  State<FlightSearchScreen> createState() => _FlightSearchScreenState();
}

enum _TripType { oneWay, roundTrip }

class _FlightSearchScreenState extends State<FlightSearchScreen> {
  final _dfLong = DateFormat.yMMMEd();
  final _dfIso = DateFormat('yyyy-MM-dd');

  // Airports
  Map<String, dynamic>? _from;
  Map<String, dynamic>? _to;

  // Trip type + dates
  _TripType _trip = _TripType.oneWay;
  DateTime _depart = DateTime.now();
  DateTime? _return;

  // Pax & cabin
  int _adults = 1;
  int _children = 0;
  int _infants = 0;
  String _cabin = 'Economy';

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
    _cabin = widget.initialCabin;
    _depart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } // Use ScaffoldMessenger for reliable SnackBars in modern Flutter apps [3]

  Future<void> _pickFrom() async {
    final res = await AirportSelector.show(
      context,
      searchAirports: _searchAirports,
      popularAirports: const [],
      title: 'From',
    );
    if (res != null) setState(() => _from = res);
  } // AirportSelector is presented via a modal bottom sheet and returns a selected airport map [4]

  Future<void> _pickTo() async {
    final res = await AirportSelector.show(
      context,
      searchAirports: _searchAirports,
      popularAirports: const [],
      title: 'To',
    );
    if (res != null) setState(() => _to = res);
  } // The same selector pattern is reused for destination to keep UX consistent and modular [4]

  Future<List<Map<String, dynamic>>> _searchAirports(String q) async {
    // Wire to backend or local index; return [{code,name,city,country,lat,lng}]
    // This stub returns empty; implement API wiring in your data layer.
    return <Map<String, dynamic>>[];
  } // Debounced search is handled inside AirportSelector to avoid spamming network calls [5]

  Future<void> _pickDate() async {
    final now = DateTime.now();
    if (_trip == _TripType.oneWay) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _depart.isBefore(now) ? now : _depart,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (picked != null) {
        setState(() {
          _depart = DateTime(picked.year, picked.month, picked.day);
          _return = null;
        });
      }
    } else {
      final range = await showDateRangePicker(
        context: context,
        initialDateRange: _return != null
            ? DateTimeRange(start: _depart, end: _return!)
            : DateTimeRange(start: _depart.isBefore(now) ? now : _depart, end: ( _depart.isBefore(now) ? now : _depart ).add(const Duration(days: 2))),
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (range != null) {
        setState(() {
          _depart = DateTime(range.start.year, range.start.month, range.start.day);
          _return = DateTime(range.end.year, range.end.month, range.end.day);
        });
      }
    }
  } // One‑way uses showDatePicker while round‑trip uses showDateRangePicker for an accessible date selection UX in Material apps [2][6]

  Future<void> _openPaxCabin() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PaxCabinSheet(
        adults: _adults,
        children: _children,
        infants: _infants,
        cabin: _cabin,
      ),
    );
    if (result != null) {
      setState(() {
        _adults = result['adults'] as int;
        _children = result['children'] as int;
        _infants = result['infants'] as int;
        _cabin = (result['cabin'] as String?) ?? _cabin;
      });
    }
  } // Bottom sheets are a standard, ergonomic way to collect contextual inputs like passenger counts and cabin in Flutter [4]

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
  } // Swap helps quickly reverse routes without retyping, improving search ergonomics in travel flows [1]

  void _search() {
    if (_from == null || _to == null) {
      _snack('Select both From and To airports');
      return;
    }
    if (_trip == _TripType.roundTrip && _return == null) {
      _snack('Pick return date for round trip');
      return;
    }
    if (_adults < 1) {
      _snack('At least 1 adult is required');
      return;
    }
    if (_infants > _adults) {
      _snack('Infants cannot exceed adults');
      return;
    }

    final fromCode = (_from!['code'] ?? '').toString().toUpperCase();
    final toCode = (_to!['code'] ?? '').toString().toUpperCase();
    final departIso = _dfIso.format(_depart);
    final returnIso = _return != null ? _dfIso.format(_return!) : null;

    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FlightResultsScreen(
        fromCode: fromCode,
        toCode: toCode,
        date: departIso,
        returnDate: _trip == _TripType.roundTrip ? returnIso : null,
        cabin: _cabin,
        adults: _adults,
        children: _children,
        infants: _infants,
        currency: widget.currency,
        title: 'Flights',
      ),
    ));
  } // Handoff to FlightResultsScreen passes normalized codes, ISO dates, cabin, and pax counts to keep paging and pricing consistent downstream [7]

  @override
  Widget build(BuildContext context) {
    final fromLabel = _from == null ? 'From' : '${_from!['code'] ?? ''} • ${_from!['city'] ?? _from!['name'] ?? ''}';
    final toLabel = _to == null ? 'To' : '${_to!['code'] ?? ''} • ${_to!['city'] ?? _to!['name'] ?? ''}';

    final dateLabel = _trip == _TripType.oneWay
        ? _dfLong.format(_depart)
        : (_return == null
            ? '${_dfLong.format(_depart)} — Return'
            : '${_dfLong.format(_depart)} — ${_dfLong.format(_return!)}');

    final paxCabinLabel = '$_cabin • ${_adults}A${_children > 0 ? ' ${_children}C' : ''}${_infants > 0 ? ' ${_infants}I' : ''}';

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Trip type
            Row(
              children: [
                const Icon(Icons.swap_horiz, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                SegmentedButton<_TripType>(
                  segments: const [
                    ButtonSegment(value: _TripType.oneWay, label: Text('One‑way')),
                    ButtonSegment(value: _TripType.roundTrip, label: Text('Round‑trip')),
                  ],
                  selected: {_trip},
                  onSelectionChanged: (s) => setState(() {
                    _trip = s.first;
                    if (_trip == _TripType.oneWay) _return = null;
                  }),
                ),
              ],
            ), // SegmentedButton is recommended for choosing among a small, fixed set of options like one‑way vs round‑trip [1]

            const SizedBox(height: 16),

            // Airports
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flight_takeoff),
                    title: Text(fromLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: _pickFrom,
                  ),
                ),
                IconButton(
                  tooltip: 'Swap',
                  onPressed: _swap,
                  icon: const Icon(Icons.swap_vert),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flight_land),
                    title: Text(toLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: _pickTo,
                  ),
                ),
              ],
            ), // Airport pickers are shown as bottom sheets to maintain flow and prevent context switching [4]

            const SizedBox(height: 8),

            // Dates
            ListTile(
              onTap: _pickDate,
              leading: const Icon(Icons.event),
              title: Text(dateLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(_trip == _TripType.oneWay ? 'Departure' : 'Departure • Return'),
              trailing: const Icon(Icons.edit_calendar_outlined),
            ), // Date pickers use Material dialogs (single or range) for accessible, platform‑consistent selection [2][6]

            const SizedBox(height: 8),

            // Pax & cabin
            ListTile(
              onTap: _openPaxCabin,
              leading: const Icon(Icons.airline_seat_recline_normal_outlined),
              title: Text(paxCabinLabel),
              subtitle: const Text('Passengers • Cabin'),
              trailing: const Icon(Icons.tune),
            ), // A modal sheet aggregates passenger and cabin choices for compact, focused editing [4]

            const SizedBox(height: 20),

            // CTA
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('Search flights'),
              ),
            ), // Submit validates essentials then navigates to results with normalized parameters for consistency [7]
          ],
        ),
      ),
    );
  }
}

class _PaxCabinSheet extends StatefulWidget {
  const _PaxCabinSheet({
    required this.adults,
    required this.children,
    required this.infants,
    required this.cabin,
  });

  final int adults;
  final int children;
  final int infants;
  final String cabin;

  @override
  State<_PaxCabinSheet> createState() => _PaxCabinSheetState();
}

class _PaxCabinSheetState extends State<_PaxCabinSheet> {
  late int _adults;
  late int _children;
  late int _infants;
  late String _cabin;

  @override
  void initState() {
    super.initState();
    _adults = widget.adults;
    _children = widget.children;
    _infants = widget.infants;
    _cabin = widget.cabin;
  }

  void _close() {
    Navigator.of(context).maybePop({
      'adults': _adults,
      'children': _children,
      'infants': _infants,
      'cabin': _cabin,
    });
  }

  Widget _counter(String label, int value, VoidCallback inc, VoidCallback dec, {bool disableDec = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(onPressed: disableDec ? null : dec, icon: const Icon(Icons.remove_circle_outline)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(onPressed: inc, icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cabins = ['Economy', 'Premium', 'Business', 'First'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Passengers & cabin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(onPressed: _close, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          _counter(
            'Adults',
            _adults,
            () => setState(() => _adults += 1),
            () => setState(() => _adults = _adults > 1 ? _adults - 1 : _adults),
            disableDec: _adults <= 1,
          ),
          const SizedBox(height: 8),
          _counter(
            'Children',
            _children,
            () => setState(() => _children += 1),
            () => setState(() => _children = _children > 0 ? _children - 1 : _children),
            disableDec: _children <= 0,
          ),
          const SizedBox(height: 8),
          _counter(
            'Infants',
            _infants,
            () => setState(() => _infants = _infants < _adults ? _infants + 1 : _infants),
            () => setState(() => _infants = _infants > 0 ? _infants - 1 : _infants),
            disableDec: _infants <= 0,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _cabin,
            decoration: const InputDecoration(labelText: 'Cabin'),
            items: cabins.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _cabin = v ?? _cabin),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _close,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
