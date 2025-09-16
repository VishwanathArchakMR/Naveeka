// lib/features/journey/presentation/hotels/hotel_search_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'hotel_results_screen.dart';
import '../cabs/widgets/location_picker.dart'; // optional map center picker

class HotelSearchScreen extends StatefulWidget {
  const HotelSearchScreen({
    super.key,
    this.title = 'Search hotels',
    this.initialDestination,
    this.currency = '₹',
  });

  final String title;
  final String? initialDestination;
  final String currency;

  @override
  State<HotelSearchScreen> createState() => _HotelSearchScreenState();
}

class _HotelSearchScreenState extends State<HotelSearchScreen> {
  final _dfLong = DateFormat.yMMMEd();
  final _dfIso = DateFormat('yyyy-MM-dd');

  // Destination + optional center
  final _destCtrl = TextEditingController();
  double? _centerLat;
  double? _centerLng;

  // Dates
  late DateTime _checkIn;
  late DateTime _checkOut;

  // Rooms/guests
  int _rooms = 1;
  int _adults = 2;
  int _children = 0;
  final List<int> _childrenAges = [];

  @override
  void initState() {
    super.initState();
    _destCtrl.text = widget.initialDestination ?? '';
    final today = DateTime.now();
    _checkIn = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
    _checkOut = _checkIn.add(const Duration(days: 2));
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _checkIn.isBefore(now) ? now : _checkIn, end: _checkOut),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    ); // Use showDateRangePicker to collect check‑in/out in one flow [1]
    if (range != null) {
      setState(() {
        _checkIn = DateTime(range.start.year, range.start.month, range.start.day);
        _checkOut = DateTime(range.end.year, range.end.month, range.end.day);
      });
    }
  }

  Future<void> _openGuestsRooms() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _GuestsRoomsSheet(
        rooms: _rooms,
        adults: _adults,
        children: _children,
        childrenAges: _childrenAges,
      ),
    ); // Use a modal bottom sheet to edit rooms/guests compactly and return values on pop [12]
    if (result != null) {
      setState(() {
        _rooms = result['rooms'] as int;
        _adults = result['adults'] as int;
        _children = result['children'] as int;
        _childrenAges
          ..clear()
          ..addAll((result['childrenAges'] as List).cast<int>());
      });
    }
  }

  Future<void> _pickCenterOnMap() async {
    final res = await LocationPicker.show(
      context,
      title: 'Choose map center',
      initialLat: _centerLat,
      initialLng: _centerLng,
      initialAddress: null,
    ); // Reuse the map LocationPicker to optionally supply a center for map view/distances [12]
    if (res != null) {
      setState(() {
        _centerLat = (res['lat'] as double?) ?? _centerLat;
        _centerLng = (res['lng'] as double?) ?? _centerLng;
      });
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); // Reliable transient feedback with ScaffoldMessenger [10]
  }

  void _search() {
    final dest = _destCtrl.text.trim();
    if (dest.isEmpty) {
      _snack('Enter a destination');
      return;
    }
    if (!_checkOut.isAfter(_checkIn)) {
      _snack('Check‑out must be after check‑in');
      return;
    }
    if (_adults < 1) {
      _snack('At least one adult is required');
      return;
    }

    final inIso = _dfIso.format(_checkIn);
    final outIso = _dfIso.format(_checkOut);

    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HotelResultsScreen(
        destination: dest,
        checkInIso: inIso,
        checkOutIso: outIso,
        rooms: _rooms,
        adults: _adults,
        children: _children,
        childrenAges: _childrenAges,
        currency: widget.currency,
        centerLat: _centerLat,
        centerLng: _centerLng,
        title: 'Hotels',
      ),
    )); // Handoff to results passes ISO dates, pax, and optional map center for consistent downstream behavior [10]
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${_dfLong.format(_checkIn)} — ${_dfLong.format(_checkOut)}';
    final paxLabel = '${_rooms}R • ${_adults}A${_children > 0 ? ' ${_children}C' : ''}';
    final centerBadge = (_centerLat != null && _centerLng != null) ? 'Lat ${_centerLat!.toStringAsFixed(3)}, Lng ${_centerLng!.toStringAsFixed(3)}' : 'Optional';

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Destination
            TextFormField(
              controller: _destCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Destination (city/area)',
                prefixIcon: const Icon(Icons.location_city_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Pick on map',
                  onPressed: _pickCenterOnMap,
                  icon: const Icon(Icons.map_outlined),
                ),
              ),
            ), // Destination text plus a map‑center shortcut covers both typed and spatial search flows [12]

            const SizedBox(height: 12),

            // Dates
            ListTile(
              onTap: _pickDates,
              leading: const Icon(Icons.event),
              title: Text(dateLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Check‑in • Check‑out'),
              trailing: const Icon(Icons.edit_calendar_outlined),
            ), // Date‑range picker provides an accessible Material dialog for stay windows [1]

            const SizedBox(height: 8),

            // Guests & rooms
            ListTile(
              onTap: _openGuestsRooms,
              leading: const Icon(Icons.group_outlined),
              title: Text(paxLabel),
              subtitle: const Text('Rooms • Guests'),
              trailing: const Icon(Icons.tune),
            ), // Editing rooms/guests via a modal bottom sheet keeps the main screen clean and focused [12]

            const SizedBox(height: 8),

            // Map center status
            ListTile(
              onTap: _pickCenterOnMap,
              leading: const Icon(Icons.my_location),
              title: const Text('Map center'),
              subtitle: Text(centerBadge, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
            ), // Optional map center improves list/map results relevance without forcing geocoding up front [12]

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('Search hotels'),
              ),
            ), // CTA validates fields and navigates to the paged results screen with normalized params [10]
          ],
        ),
      ),
    );
  }
}

class _GuestsRoomsSheet extends StatefulWidget {
  const _GuestsRoomsSheet({
    required this.rooms,
    required this.adults,
    required this.children,
    required this.childrenAges,
  });

  final int rooms;
  final int adults;
  final int children;
  final List<int> childrenAges;

  @override
  State<_GuestsRoomsSheet> createState() => _GuestsRoomsSheetState();
}

class _GuestsRoomsSheetState extends State<_GuestsRoomsSheet> {
  late int _rooms;
  late int _adults;
  late int _children;
  late List<int> _ages;

  @override
  void initState() {
    super.initState();
    _rooms = widget.rooms;
    _adults = widget.adults;
    _children = widget.children;
    _ages = [...widget.childrenAges];
    _syncAges();
  }

  void _syncAges() {
    if (_children < _ages.length) {
      _ages = _ages.take(_children).toList();
    } else {
      while (_ages.length < _children) {
        _ages.add(8);
      }
    }
  }

  void _close() {
    Navigator.of(context).maybePop({
      'rooms': _rooms,
      'adults': _adults,
      'children': _children,
      'childrenAges': _ages,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Rooms & guests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(onPressed: _close, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          _counter(
            'Rooms',
            _rooms,
            () => setState(() => _rooms += 1),
            () => setState(() => _rooms = _rooms > 1 ? _rooms - 1 : _rooms),
            disableDec: _rooms <= 1,
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
            () {
              setState(() {
                _children += 1;
                _syncAges();
              });
            },
            () {
              setState(() {
                _children = _children > 0 ? _children - 1 : 0;
                _syncAges();
              });
            },
            disableDec: _children <= 0,
          ),
          if (_children > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Children ages', style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_children, (i) {
                return DropdownButton<int>(
                  value: _ages[i],
                  items: List.generate(17, (a) => DropdownMenuItem(value: a, child: Text('$a'))),
                  onChanged: (v) => setState(() => _ages[i] = v ?? _ages[i]),
                );
              }),
            ),
          ],
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
