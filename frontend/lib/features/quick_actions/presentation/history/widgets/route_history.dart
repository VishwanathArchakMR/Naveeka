// lib/features/quick_actions/presentation/history/widgets/route_history.dart

import 'package:flutter/material.dart';

/// A single waypoint/visit on the route timeline.
class RouteHistoryItem {
  const RouteHistoryItem({
    required this.id,
    required this.time, // local or UTC; display uses toLocal()
    required this.title, // place name or route step title
    this.subtitle, // address or note
    this.icon, // optional icon for the rail dot
    this.color, // optional accent for the rail dot
  });

  final String id;
  final DateTime time;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
}

/// Groups items by calendar day and shows them as an expandable timeline with a vertical rail.
class RouteHistory extends StatelessWidget {
  const RouteHistory({
    super.key,
    required this.items,
    this.sectionTitle = 'Route history',
    this.onOpenItem, // void Function(RouteHistoryItem)
    this.onClearDay, // Future<void> Function(DateTime day)
    this.onClearAll, // Future<void> Function()
  });

  final List<RouteHistoryItem> items;
  final String sectionTitle;

  final void Function(RouteHistoryItem item)? onOpenItem;
  final Future<void> Function(DateTime day)? onClearDay;
  final Future<void> Function()? onClearAll;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDay(items);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (onClearAll != null)
                    TextButton.icon(
                      onPressed: onClearAll,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Clear all'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Body: date sections
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No route history')),
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
                    onOpenItem: onOpenItem,
                    onClearDay: onClearDay,
                  );
                },
              ),
          ],
        ),
      ),
    ); // ListView.separated builds only visible rows and inserts consistent separators, ideal for grouped lists. [13][16]
  }

  List<_DayGroup> _groupByDay(List<RouteHistoryItem> src) {
    if (src.isEmpty) return const [];
    final map = <DateTime, List<RouteHistoryItem>>{};
    for (final it in src) {
      final t = it.time.toLocal();
      final dayKey = DateTime(t.year, t.month, t.day);
      map.putIfAbsent(dayKey, () => <RouteHistoryItem>[]).add(it);
    }
    final entries = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)); // newest day first
    return entries
        .map((e) {
          final list = [...e.value]..sort((a, b) => a.time.compareTo(b.time)); // chronological within day
          return _DayGroup(day: e.key, items: list);
        })
        .toList(growable: false);
  }
}

class _DayGroup {
  const _DayGroup({required this.day, required this.items});
  final DateTime day;
  final List<RouteHistoryItem> items;
}

class _DaySection extends StatefulWidget {
  const _DaySection({
    required this.day,
    required this.items,
    this.onOpenItem,
    this.onClearDay,
  });

  final DateTime day;
  final List<RouteHistoryItem> items;
  final void Function(RouteHistoryItem item)? onOpenItem;
  final Future<void> Function(DateTime day)? onClearDay;

  @override
  State<_DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends State<_DaySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dayLabel = _fmtDay(widget.day);

    return Theme(
      data: Theme.of(context),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        title: const SizedBox.shrink(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onClearDay != null)
              IconButton(
                tooltip: 'Clear day',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await widget.onClearDay!.call(widget.day);
                },
              ),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
        children: [
          // Timeline list for the day
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: _TimelineList(
              items: widget.items,
              onOpenItem: widget.onOpenItem,
            ),
          ),
        ],
      ),
    ); // ExpansionTile is the standard Material pattern for collapsible grouped content. [12][15]
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

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.items, this.onOpenItem});

  final List<RouteHistoryItem> items;
  final void Function(RouteHistoryItem item)? onOpenItem;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final it = items[i];
        final first = i == 0;
        final last = i == items.length - 1;
        return _TimelineTile(
          item: it,
          drawTop: !first,
          drawBottom: !last,
          onOpen: onOpenItem,
        );
      },
    ); // ListView.separated adds uniform gaps between timeline tiles while only building visible items. [13][16]
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.item,
    required this.drawTop,
    required this.drawBottom,
    this.onOpen,
  });

  final RouteHistoryItem item;
  final bool drawTop;
  final bool drawBottom;
  final void Function(RouteHistoryItem item)? onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final time = TimeOfDay.fromDateTime(item.time.toLocal());
    final tstr = MaterialLocalizations.of(context).formatTimeOfDay(time);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rail + dot
        SizedBox(
          width: 28,
          child: CustomPaint(
            painter: _RailPainter(
              color: cs.outlineVariant,
              drawTop: drawTop,
              drawBottom: drawBottom,
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: (item.color ?? cs.primary).withValues(alpha: 1.0),
                  shape: BoxShape.circle,
                ),
                child: item.icon == null ? null : Icon(item.icon, size: 10, color: cs.onPrimary),
              ),
            ),
          ),
        ),

        // Content
        Expanded(
          child: InkWell(
            onTap: onOpen == null ? null : () => onOpen!(item),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
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
                          tstr,
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),

                  // Subtitle
                  if ((item.subtitle ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.subtitle!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.color,
    required this.drawTop,
    required this.drawBottom,
  });

  final Color color;
  final bool drawTop;
  final bool drawBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.0; // double required

    final centerX = size.width / 2;
    const dotRadius = 12 / 2;
    const topY = 0.0;
    final centerY = size.height / 2;
    if (drawTop) {
      canvas.drawLine(
        Offset(centerX, topY),
        Offset(centerX, centerY - dotRadius),
        p,
      );
    }
    if (drawBottom) {
      canvas.drawLine(
        Offset(centerX, centerY + dotRadius),
        Offset(centerX, size.height),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter oldDelegate) {
    return color != oldDelegate.color || drawTop != oldDelegate.drawTop || drawBottom != oldDelegate.drawBottom;
  }
}
