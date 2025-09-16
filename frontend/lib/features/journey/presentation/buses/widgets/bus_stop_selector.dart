// lib/features/journey/presentation/buses/widgets/bus_stop_selector.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A selector for boarding and dropping stops with search and confirmation.
/// Each stop is a map like:
/// { id, name, time (ISO or HH:mm), address?, area?, lat?, lng? }
class BusStopSelector extends StatefulWidget {
  const BusStopSelector({
    super.key,
    required this.boardingStops,
    required this.droppingStops,
    this.initialBoardingId,
    this.initialDroppingId,
    this.title = 'Select stops',
  });

  final List<Map<String, dynamic>> boardingStops;
  final List<Map<String, dynamic>> droppingStops;
  final String? initialBoardingId;
  final String? initialDroppingId;
  final String title;

  @override
  State<BusStopSelector> createState() => _BusStopSelectorState();

  /// Helper to show as a modal bottom sheet and return selections on pop.
  /// Returns:
  /// {
  ///   'boardingId': String?,
  ///   'droppingId': String?,
  ///   'boarding': Map<String, dynamic>?,
  ///   'dropping': Map<String, dynamic>?
  /// }
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> boardingStops,
    required List<Map<String, dynamic>> droppingStops,
    String? initialBoardingId,
    String? initialDroppingId,
    String title = 'Select stops',
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
        child: BusStopSelector(
          boardingStops: boardingStops,
          droppingStops: droppingStops,
          initialBoardingId: initialBoardingId,
          initialDroppingId: initialDroppingId,
          title: title,
        ),
      ),
    );
  }
}

class _BusStopSelectorState extends State<BusStopSelector> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  String? _boardingId;
  String? _droppingId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _boardingId = widget.initialBoardingId;
    _droppingId = widget.initialDroppingId;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final b = widget.boardingStops.firstWhere(
      (e) => (e['id']?.toString() ?? '') == (_boardingId ?? ''),
      orElse: () => <String, dynamic>{},
    );
    final d = widget.droppingStops.firstWhere(
      (e) => (e['id']?.toString() ?? '') == (_droppingId ?? ''),
      orElse: () => <String, dynamic>{},
    );
    Navigator.of(context).pop({
      'boardingId': _boardingId,
      'droppingId': _droppingId,
      'boarding': b.isEmpty ? null : b,
      'dropping': d.isEmpty ? null : d,
    });
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _boardingId != null && _droppingId != null;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search stop or area',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Boarding'),
              Tab(text: 'Dropping'),
            ],
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _StopsList(
                  stops: widget.boardingStops,
                  selectedId: _boardingId,
                  onChanged: (id) => setState(() => _boardingId = id),
                  query: _searchCtrl.text.trim(),
                ),
                _StopsList(
                  stops: widget.droppingStops,
                  selectedId: _droppingId,
                  onChanged: (id) => setState(() => _droppingId = id),
                  query: _searchCtrl.text.trim(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canConfirm ? _confirm : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Confirm'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopsList extends StatelessWidget {
  const _StopsList({
    required this.stops,
    required this.selectedId,
    required this.onChanged,
    required this.query,
  });

  final List<Map<String, dynamic>> stops;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String query;

  @override
  Widget build(BuildContext context) {
    final filtered = _filter(stops, query);
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          query.isEmpty ? 'No stops available' : 'No matches for "$query"',
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = filtered[i];
        final id = (s['id'] ?? '').toString();
        final name = (s['name'] ?? '').toString();
        final address = (s['address'] ?? s['area'] ?? '').toString();
        final timeStr = _formatTime(s['time']);

        return RadioListTile<String>(
          value: id,
          groupValue: selectedId,
          onChanged: onChanged,
          title: Row(
            children: [
              if (timeStr != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  name.isEmpty ? 'Stop' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          subtitle: address.isEmpty ? null : Text(address, maxLines: 2, overflow: TextOverflow.ellipsis),
          // RadioListTile provides an accessible single-choice row with title/subtitle + trailing radio [1]
        );
      },
    );
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> items, String q) {
    if (q.isEmpty) return items;
    final qq = q.toLowerCase();
    return items.where((m) {
      bool has(dynamic v) => v != null && v.toString().toLowerCase().contains(qq);
      return has(m['name']) || has(m['address']) || has(m['area']);
    }).toList(growable: false);
  }

  String? _formatTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return DateFormat.Hm().format(v);
    if (v is String) {
      // Try HH:mm first, else ISO
      final hhmm = RegExp(r'^\d{2}:\d{2}$');
      if (hhmm.hasMatch(v)) return v;
      final dt = DateTime.tryParse(v);
      if (dt != null) return DateFormat.Hm().format(dt);
    }
    return null;
  }
}
