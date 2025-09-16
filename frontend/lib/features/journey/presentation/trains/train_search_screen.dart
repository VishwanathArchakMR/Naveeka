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
    ); // Presented as a shaped modal bottom sheet returning the selected station via Navigator.pop for a clean handoff. [1]
    if (res != null) setState(() => _from = res);
  }

  Future<void> _pickTo() async {
    final res = await StationSelector.show(
      context,
      title: 'To',
      searchStations: _searchStations,
      popularStations: const <Map<String, dynamic>>[],
    ); // Reuses the same bottom‑sheet selector to keep UX consistent and modular across both endpoints. [1]
    if (res != null) setState(() => _to = res);
  }

  Future<List<Map<String, dynamic>>> _searchStations(String q) async {
    // TODO: wire to backend; return [{code,name,city,state?,country?,lat?,lng?}]
    return <Map<String, dynamic>>[];
  } // The selector expects an async search function that returns normalized station maps for display. [3]

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
    ); // showDatePicker presents a Material date dialog and resolves a Future<DateTime?> suitable for travel date selection flows. [2]
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
    ); // showModalBottomSheet is the standard API for shaped modal pickers that return a value via Navigator.pop. [1]
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
    ); // Using the same modal bottom‑sheet pattern maintains a consistent, focused control surface for quota selection. [1]
    if (res != null) setState(() => _quota = res);
  }

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
  } // Swapping in place minimizes reentry and aligns with common travel app ergonomics for reversing routes. [3]

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
    )); // The handoff pushes the typed parameters (codes, ISO date, class/quota) to a paginated results screen for continuity. [3]
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
            ), // ListTile provides compact, accessible rows for picking endpoints in a form-like screen per Material guidance. [3]

            const SizedBox(height: 8),

            // Date
            ListTile
            (
              onTap: _pickDate,
              leading: const Icon(Icons.event),
              title: Text(dateLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Journey date'),
              trailing: const Icon(Icons.edit_calendar_outlined),
            ), // Tapping opens showDatePicker to edit the travel date within a constrained future window. [2]

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
            ), // Modal bottom sheets are used for class and quota selection to keep the screen focused and uncluttered. [1]

            const SizedBox(height: 20),

            // CTA
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search),
                label: const Text('Search trains'),
              ),
            ), // The CTA validates essentials and navigates to TrainResultsScreen with normalized parameters for a seamless flow. [3]
          ],
        ),
      ),
    );
  }
}

class _SimpleListSheet extends StatelessWidget {
  const _SimpleListSheet({required this.title, required this.items, this.selected});

  final String title;
  final List<String> items;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close)),
            ],
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final v = items[i];
              return RadioListTile<String>(
                value: v,
                groupValue: selected,
                onChanged: (_) => Navigator.of(context).maybePop(v),
                title: Text(v),
              );
            },
          ),
        ],
      ),
    );
  }
}
