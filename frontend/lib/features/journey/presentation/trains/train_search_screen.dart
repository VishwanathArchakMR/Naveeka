// lib/features/journey/presentation/trains/train_search_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'train_results_screen.dart';
import 'widgets/station_selector.dart';

class TrainSearchScreen extends StatefulWidget {
  const TrainSearchScreen({
    super.key,
    this.title = 'Search trains',
    this.initialFrom, // {code,name,city,state?,country?,lat?,lng?}
    this.initialTo,   // same shape as above
    this.initialClassCode, // e.g., '3A','SL','2S'
    this.initialQuota = 'GN', // 'GN','TQ','PT','SS','HO','LD'
  });

  final String title;
  final Map<String, dynamic>? initialFrom;
  final Map<String, dynamic>? initialTo;
  final String? initialClassCode;
  final String initialQuota;

  @override
  State<TrainSearchScreen> createState() => _TrainSearchScreenState();
}

class _TrainSearchScreenState extends State<TrainSearchScreen> {
  final _dfIso = DateFormat('yyyy-MM-dd');
  final _dfLong = DateFormat.yMMMEd();

  Map<String, dynamic>? _from;
  Map<String, dynamic>? _to;

  DateTime _date = DateTime.now().add(const Duration(days: 1));

  String? _classCode;
  String _quota = 'GN';

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
    _classCode = widget.initialClassCode;
    _quota = widget.initialQuota;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickFrom() async {
    final res = await StationSelector.show(
      context,
      title: 'From',
      searchStations: _searchStations,
      popularStations: const <Map<String, dynamic>>[],
    );
    if (res != null) setState(() => _from = res);
  }

  Future<void> _pickTo() async {
    final res = await StationSelector.show(
      context,
      title: 'To',
      searchStations: _searchStations,
      popularStations: const <Map<String, dynamic>>[],
    );
    if (res != null) setState(() => _to = res);
  }

  // Simple in-memory station search; replace with backend wiring when available.
  // Returns normalized maps: {code,name,city,state?,country?,lat?,lng?}
  Future<List<Map<String, dynamic>>> _searchStations(String q) async {
    final catalog = <Map<String, dynamic>>[
      {'code': 'NDLS', 'name': 'New Delhi', 'city': 'Delhi', 'state': 'Delhi', 'country': 'IN', 'lat': 28.643, 'lng': 77.219},
      {'code': 'BCT', 'name': 'Mumbai Central', 'city': 'Mumbai', 'state': 'Maharashtra', 'country': 'IN', 'lat': 18.969, 'lng': 72.819},
      {'code': 'CSMT', 'name': 'Chhatrapati Shivaji Maharaj Terminus', 'city': 'Mumbai', 'state': 'Maharashtra', 'country': 'IN', 'lat': 18.940, 'lng': 72.835},
      {'code': 'HWH', 'name': 'Howrah Jn', 'city': 'Kolkata', 'state': 'West Bengal', 'country': 'IN', 'lat': 22.585, 'lng': 88.342},
      {'code': 'SBC', 'name': 'KSR Bengaluru', 'city': 'Bengaluru', 'state': 'Karnataka', 'country': 'IN', 'lat': 12.978, 'lng': 77.571},
      {'code': 'MAS', 'name': 'Chennai Central', 'city': 'Chennai', 'state': 'Tamil Nadu', 'country': 'IN', 'lat': 13.082, 'lng': 80.275},
      {'code': 'PNBE', 'name': 'Patna Jn', 'city': 'Patna', 'state': 'Bihar', 'country': 'IN', 'lat': 25.594, 'lng': 85.137},
      {'code': 'BPL', 'name': 'Bhopal Jn', 'city': 'Bhopal', 'state': 'Madhya Pradesh', 'country': 'IN', 'lat': 23.260, 'lng': 77.402},
      {'code': 'JP', 'name': 'Jaipur', 'city': 'Jaipur', 'state': 'Rajasthan', 'country': 'IN', 'lat': 26.919, 'lng': 75.787},
      {'code': 'LKO', 'name': 'Lucknow NR', 'city': 'Lucknow', 'state': 'Uttar Pradesh', 'country': 'IN', 'lat': 26.852, 'lng': 80.946},
    ];
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return catalog.take(10).toList(growable: false);
    bool has(dynamic v) => v != null && v.toString().toLowerCase().contains(s);
    final res = catalog.where((m) => has(m['code']) || has(m['name']) || has(m['city'])).take(20).toList(growable: false);
    return res;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickClass() async {
    final res = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SimpleListSheet(
        title: 'Select class',
        items: const ['1A', '2A', '3A', '3E', 'SL', 'CC', '2S'],
        selected: _classCode,
      ),
    );
    if (res != null) setState(() => _classCode = res);
  }

  Future<void> _pickQuota() async {
    final res = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SimpleListSheet(
        title: 'Select quota',
        items: const ['GN', 'TQ', 'LD', 'PT', 'SS', 'HO'],
        selected: _quota,
      ),
    );
    if (res != null) setState(() => _quota = res);
  }

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
  }

  void _search() {
    if (_from == null || _to == null) {
      _snack('Select both From and To');
      return;
    }
    final fromCode = (_from!['code'] ?? '').toString().toUpperCase();
    final toCode = (_to!['code'] ?? '').toString().toUpperCase();
    if (fromCode.isEmpty || toCode.isEmpty) {
      _snack('Missing station codes');
      return;
    }

    final dateIso = _dfIso.format(_date);

    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TrainResultsScreen(
        fromCode: fromCode,
        toCode: toCode,
        dateIso: dateIso,
        initialClassCode: _classCode,
        initialQuota: _quota,
        title: 'Trains',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fromLabel = _from == null
        ? 'From'
        : '${_from!['code'] ?? ''} • ${_from!['city'] ?? _from!['name'] ?? ''}';
    final toLabel = _to == null
        ? 'To'
        : '${_to!['code'] ?? ''} • ${_to!['city'] ?? _to!['name'] ?? ''}';
    final dateLabel = _dfLong.format(_date);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Stations
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.train_outlined),
                    title: Text(fromLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: _pickFrom,
                  ),
                ),
                IconButton(
                  tooltip: 'Swap',
                  icon: const Icon(Icons.swap_vert),
                  onPressed: _swap,
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(toLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: _pickTo,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Date
            ListTile(
              onTap: _pickDate,
              leading: const Icon(Icons.event),
              title: Text(dateLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Journey date'),
              trailing: const Icon(Icons.edit_calendar_outlined),
            ),

            const SizedBox(height: 8),

            // Class & Quota
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    onTap: _pickClass,
                    leading: const Icon(Icons.chair_alt_outlined),
                    title: Text(_classCode ?? 'Select class'),
                    subtitle: const Text('Class'),
                    trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    onTap: _pickQuota,
                    leading: const Icon(Icons.confirmation_number_outlined),
                    title: Text(_quota),
                    subtitle: const Text('Quota'),
                    trailing: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // CTA
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('Search trains'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleListSheet extends StatefulWidget {
  const _SimpleListSheet({required this.title, required this.items, this.selected});

  final String title;
  final List<String> items;
  final String? selected;

  @override
  State<_SimpleListSheet> createState() => _SimpleListSheetState();
}

class _SimpleListSheetState extends State<_SimpleListSheet> {
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Fixed: lowercase 'min'
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final v = widget.items[i];
              final isSelected = _selectedValue == v;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(v),
                onTap: () {
                  setState(() => _selectedValue = v);
                  Navigator.of(context).maybePop(v);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
