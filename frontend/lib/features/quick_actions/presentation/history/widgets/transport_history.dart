// lib/features/quick_actions/presentation/history/widgets/transport_history.dart

import 'package:flutter/material.dart';

/// Transport modes supported in the history.
enum TransportMode {
  walk,
  bike,
  car,
  taxi,
  bus,
  metro,
  train,
  flight,
}

extension TransportModeX on TransportMode {
  String get label {
    switch (this) {
      case TransportMode.walk:
        return 'Walk';
      case TransportMode.bike:
        return 'Bike';
      case TransportMode.car:
        return 'Car';
      case TransportMode.taxi:
        return 'Taxi';
      case TransportMode.bus:
        return 'Bus';
      case TransportMode.metro:
        return 'Metro';
      case TransportMode.train:
        return 'Train';
      case TransportMode.flight:
        return 'Flight';
    }
  }

  IconData get icon {
    switch (this) {
      case TransportMode.walk:
        return Icons.directions_walk;
      case TransportMode.bike:
        return Icons.pedal_bike;
      case TransportMode.car:
        return Icons.directions_car;
      case TransportMode.taxi:
        return Icons.local_taxi;
      case TransportMode.bus:
        return Icons.directions_bus;
      case TransportMode.metro:
        return Icons.directions_subway;
      case TransportMode.train:
        return Icons.train;
      case TransportMode.flight:
        return Icons.flight_takeoff;
    }
  }
}

/// A single transport segment (trip/ride).
class TransportSegment {
  const TransportSegment({
    required this.id,
    required this.mode,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    this.co2Kg,
    this.from,
    this.to,
    this.notes,
  });

  final String id;
  final TransportMode mode;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final double? co2Kg;
  final String? from;
  final String? to;
  final String? notes;
}

/// Groups segments by day and shows a filterable, accessible list with actions.
class TransportHistory extends StatefulWidget {
  const TransportHistory({
    super.key,
    required this.segments,
    this.sectionTitle = 'Transport history',
    this.selectedModes = const <TransportMode>{},
    this.onChangeModes, // void Function(Set<TransportMode>)
    this.onOpenSegment, // void Function(TransportSegment)
    this.onDirections, // Future<void> Function(TransportSegment)
    this.onShare, // void Function(TransportSegment)
    this.onClearDay, // Future<void> Function(DateTime day)
    this.onClearAll, // Future<void> Function()
  });

  final List<TransportSegment> segments;
  final String sectionTitle;

  final Set<TransportMode> selectedModes;
  final void Function(Set<TransportMode>)? onChangeModes;

  final void Function(TransportSegment)? onOpenSegment;
  final Future<void> Function(TransportSegment)? onDirections;
  final void Function(TransportSegment)? onShare;

  final Future<void> Function(DateTime day)? onClearDay;
  final Future<void> Function()? onClearAll;

  @override
  State<TransportHistory> createState() => _TransportHistoryState();
}

class _TransportHistoryState extends State<TransportHistory> {
  late Set<TransportMode> _modes;

  @override
  void initState() {
    super.initState();
    _modes = {...widget.selectedModes};
  }

  @override
  void didUpdateWidget(covariant TransportHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedModes != widget.selectedModes) {
      _modes = {...widget.selectedModes};
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groups = _groupByDay(_applyModeFilter(widget.segments, _modes));

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with clear-all
            Row(
              children: [
                Expanded(
                  child: Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (widget.onClearAll != null)
                  TextButton.icon(
                    onPressed: widget.onClearAll,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear all'),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // Mode filter chips
            _ModeChips(
              selected: _modes,
              onChanged: (next) {
                setState(() => _modes = next);
                widget.onChangeModes?.call(next);
              },
            ),

            const SizedBox(height: 10),

            // Content
            if (groups.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No transport records', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groups.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, i) {
                  final g = groups[i];
                  return _DaySection(
                    day: g.day,
                    items: g.items,
                    onOpen: widget.onOpenSegment,
                    onDirections: widget.onDirections,
                    onShare: widget.onShare,
                    onClearDay: widget.onClearDay,
                  );
                },
              ),
          ],
        ),
      ),
    ); // ListView.separated renders items with consistent separators and efficient lazy building. [1][11]
  }

  List<_DayGroup> _groupByDay(List<TransportSegment> src) {
    if (src.isEmpty) return const [];
    final map = <DateTime, List<TransportSegment>>{};
    for (final s in src) {
      final t = s.startTime.toLocal();
      final key = DateTime(t.year, t.month, t.day);
      map.putIfAbsent(key, () => <TransportSegment>[]).add(s);
    }
    final out = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // newest date first
    return out
        .map((e) {
          final list = [...e.value]..sort((a, b) => a.startTime.compareTo(b.startTime));
          return _DayGroup(day: e.key, items: list);
        })
        .toList(growable: false);
  }

  List<TransportSegment> _applyModeFilter(List<TransportSegment> src, Set<TransportMode> modes) {
    if (modes.isEmpty) return src;
    return src.where((s) => modes.contains(s.mode)).toList(growable: false);
  }
}

class _DayGroup {
  const _DayGroup({required this.day, required this.items});
  final DateTime day;
  final List<TransportSegment> items;
}

class _ModeChips extends StatelessWidget {
  const _ModeChips({required this.selected, required this.onChanged});

  final Set<TransportMode> selected;
  final void Function(Set<TransportMode>) onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const all = TransportMode.values;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: all.map((m) {
        final isOn = selected.contains(m);
        final bg = isOn ? cs.primary.withValues(alpha: 0.14) : cs.surfaceContainerHigh.withValues(alpha: 1.0);
        final fg = isOn ? cs.primary : cs.onSurface;
        return FilterChip(
          avatar: Icon(m.icon, size: 16, color: fg),
          label: Text(m.label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
          selected: isOn,
          onSelected: (on) {
            final next = {...selected};
            on ? next.add(m) : next.remove(m);
            onChanged(next);
          },
          backgroundColor: bg,
          selectedColor: cs.primary.withValues(alpha: 0.18),
          showCheckmark: false,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          side: BorderSide(color: isOn ? cs.primary : cs.outlineVariant),
        );
      }).toList(growable: false),
    ); // FilterChip is the Material choice for compact, multi-select filters like transport modes. [9][15]
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.items,
    this.onOpen,
    this.onDirections,
    this.onShare,
    this.onClearDay,
  });

  final DateTime day;
  final List<TransportSegment> items;
  final void Function(TransportSegment)? onOpen;
  final Future<void> Function(TransportSegment)? onDirections;
  final void Function(TransportSegment)? onShare;
  final Future<void> Function(DateTime)? onClearDay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = _fmtDay(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              if (onClearDay != null)
                IconButton(
                  tooltip: 'Clear day',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onClearDay!(day),
                ),
            ],
          ),
        ),

        // Segments of the day
        ...items.map((s) => _SegmentTile(
              segment: s,
              onOpen: onOpen,
              onDirections: onDirections,
              onShare: onShare,
            )),
      ],
    );
  }

  String _fmtDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest = today.subtract(const Duration(days: 1));
    final key = DateTime(d.year, d.month, d.day);
    if (key == today) return 'Today';
    if (key == yest) return 'Yesterday';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.segment,
    this.onOpen,
    this.onDirections,
    this.onShare,
  });

  final TransportSegment segment;
  final void Function(TransportSegment)? onOpen;
  final Future<void> Function(TransportSegment)? onDirections;
  final void Function(TransportSegment)? onShare;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final start = TimeOfDay.fromDateTime(segment.startTime.toLocal());
    final end = TimeOfDay.fromDateTime(segment.endTime.toLocal());
    final sStr = MaterialLocalizations.of(context).formatTimeOfDay(start);
    final eStr = MaterialLocalizations.of(context).formatTimeOfDay(end);

    final distance = segment.distanceKm >= 10
        ? '${segment.distanceKm.toStringAsFixed(0)} km'
        : '${segment.distanceKm.toStringAsFixed(1)} km';

    final co2 = segment.co2Kg == null
        ? null
        : (segment.co2Kg! >= 10 ? '${segment.co2Kg!.toStringAsFixed(0)} kg CO₂' : '${segment.co2Kg!.toStringAsFixed(2)} kg CO₂');

    final metaParts = <String>[distance, '$sStr → $eStr'];
    if (co2 != null) metaParts.add(co2);
    final meta = metaParts.join(' · ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(segment.mode.icon, color: cs.primary),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _title(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              segment.mode.label,
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis),
          if ((segment.notes ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(segment.notes!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
        ],
      ),
      trailing: Wrap(
        spacing: 6,
        children: [
          IconButton(
            tooltip: 'Open',
            icon: const Icon(Icons.open_in_new),
            onPressed: onOpen == null ? null : () => onOpen!(segment),
          ),
          IconButton(
            tooltip: 'Directions',
            icon: const Icon(Icons.directions_outlined),
            onPressed: onDirections == null ? null : () => onDirections!(segment),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare == null ? null : () => onShare!(segment),
          ),
        ],
      ),
      onTap: onOpen == null ? null : () => onOpen!(segment),
    );
  }

  String _title() {
    final from = (segment.from ?? '').trim();
    final to = (segment.to ?? '').trim();
    if (from.isEmpty && to.isEmpty) return 'Trip';
    if (from.isEmpty) return '→ $to';
    if (to.isEmpty) return '$from →';
    return '$from → $to';
  }
}
