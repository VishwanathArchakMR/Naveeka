// lib/features/quick_actions/presentation/planning/widgets/trip_itinerary.dart

import 'package:flutter/material.dart';

/// A single activity within a day.
class ItineraryActivity {
  const ItineraryActivity({
    required this.id,
    required this.start, // local time
    required this.end, // local time
    required this.title, // activity name or place name
    this.subtitle, // address or details
    this.icon, // e.g., Icons.restaurant
    this.thumbnailUrl, // optional cover image
    this.bookable = false,
    this.notes,
  });

  final String id;
  final TimeOfDay start;
  final TimeOfDay end;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? thumbnailUrl;
  final bool bookable;
  final String? notes;
}

/// A single day in the itinerary.
class ItineraryDay {
  const ItineraryDay({
    required this.date, // date for the day
    required this.activities,
    this.title, // optional label e.g., "Day 1 – Arrival"
    this.summary, // short summary for the day
  });

  final DateTime date;
  final List<ItineraryActivity> activities;
  final String? title;
  final String? summary;
}

/// An expandable, reorderable day-by-day itinerary list.
/// - ExpansionPanelList controls per-day open/closed state
/// - ReorderableListView supports drag-and-drop activity ordering
/// - Quick actions: Open, Map, Book
/// - Uses Color.withValues and const for performance
class TripItinerary extends StatefulWidget {
  const TripItinerary({
    super.key,
    required this.days,
    this.initialOpenAll = false,
    this.onReorder, // Future<void> Function(DateTime day, int oldIndex, int newIndex)
    this.onOpenActivity, // void Function(ItineraryActivity)
    this.onMapActivity, // void Function(ItineraryActivity)
    this.onBookActivity, // Future<void> Function(ItineraryActivity)
    this.onEditNotes, // Future<void> Function(DateTime day, ItineraryActivity, String nextNotes)
    this.sectionTitle = 'Trip itinerary',
    this.onAddActivity, // void Function(DateTime day)
  });

  final List<ItineraryDay> days;
  final bool initialOpenAll;
  final Future<void> Function(DateTime day, int oldIndex, int newIndex)? onReorder;

  final void Function(ItineraryActivity activity)? onOpenActivity;
  final void Function(ItineraryActivity activity)? onMapActivity;
  final Future<void> Function(ItineraryActivity activity)? onBookActivity;
  final Future<void> Function(DateTime day, ItineraryActivity activity, String nextNotes)? onEditNotes;

  final String sectionTitle;
  final void Function(DateTime day)? onAddActivity;

  @override
  State<TripItinerary> createState() => _TripItineraryState();
}

class _TripItineraryState extends State<TripItinerary> {
  late List<_DayState> _state;

  @override
  void initState() {
    super.initState();
    _state = widget.days
        .map((d) => _DayState(
              day: d,
              open: widget.initialOpenAll,
              items: [...d.activities],
            ))
        .toList(growable: true);
  }

  @override
  void didUpdateWidget(covariant TripItinerary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) {
      _state = widget.days
          .map((d) => _DayState(
                day: d,
                open: widget.initialOpenAll,
                items: [...d.activities],
              ))
          .toList(growable: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(child: Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800))),
                if (widget.onAddActivity != null)
                  FilledButton.icon(
                    onPressed: () {
                      if (_state.isEmpty) return;
                      widget.onAddActivity!.call(_state.first.day.date);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Days as ExpansionPanelList
            Expanded(
              child: SingleChildScrollView(
                child: ExpansionPanelList.radio(
                  elevation: 0,
                  expandedHeaderPadding: EdgeInsets.zero,
                  materialGapSize: 0,
                  children: _state.map((s) => _buildPanel(context, s)).toList(growable: false),
                ),
              ),
            ), // ExpansionPanelList and ExpansionPanelList.radio are built-in Material widgets for expandable sections with animated transitions. [1][4]
          ],
        ),
      ),
    );
  }

  ExpansionPanelRadio _buildPanel(BuildContext context, _DayState s) {
    final cs = Theme.of(context).colorScheme;
    final label = _dayLabel(s.day);
    final subtitle = (s.day.title ?? '').trim().isNotEmpty ? s.day.title!.trim() : null;

    return ExpansionPanelRadio(
      canTapOnHeader: true,
      value: s.day.date.toIso8601String(),
      headerBuilder: (_, isOpen) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if ((s.day.summary ?? '').trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(s.day.summary!.trim(), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          subtitle: subtitle == null
              ? null
              : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant)),
          trailing: widget.onAddActivity == null
              ? null
              : IconButton(
                  tooltip: 'Add',
                  icon: const Icon(Icons.add),
                  onPressed: () => widget.onAddActivity!.call(s.day.date),
                ),
        );
      },
      body: _DayBody(
        state: s,
        onReorder: widget.onReorder,
        onOpenActivity: widget.onOpenActivity,
        onMapActivity: widget.onMapActivity,
        onBookActivity: widget.onBookActivity,
        onEditNotes: widget.onEditNotes,
      ),
    ); // ExpansionPanel provides a header and a body that toggles visibility, suitable for day-level grouping. [11][3]
  }

  String _dayLabel(ItineraryDay d) {
    final local = d.date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }
}

class _DayState {
  _DayState({required this.day, required this.open, required this.items});
  final ItineraryDay day;
  bool open;
  List<ItineraryActivity> items;
}

class _DayBody extends StatefulWidget {
  const _DayBody({
    required this.state,
    this.onReorder,
    this.onOpenActivity,
    this.onMapActivity,
    this.onBookActivity,
    this.onEditNotes,
  });

  final _DayState state;
  final Future<void> Function(DateTime day, int oldIndex, int newIndex)? onReorder;
  final void Function(ItineraryActivity activity)? onOpenActivity;
  final void Function(ItineraryActivity activity)? onMapActivity;
  final Future<void> Function(ItineraryActivity activity)? onBookActivity;
  final Future<void> Function(DateTime day, ItineraryActivity activity, String nextNotes)? onEditNotes;

  @override
  State<_DayBody> createState() => _DayBodyState();
}

class _DayBodyState extends State<_DayBody> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Text('No activities yet', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: ReorderableListView.builder(
        key: PageStorageKey(widget.state.day.date.toIso8601String()),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.state.items.length,
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(8),
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final act = widget.state.items[index];
          return _ActivityTile(
            key: ValueKey(act.id),
            activity: act,
            onOpen: widget.onOpenActivity,
            onMap: widget.onMapActivity,
            onBook: widget.onBookActivity,
            onEditNotes:
                widget.onEditNotes == null ? null : (next) => widget.onEditNotes!(widget.state.day.date, act, next),
          );
        },
        onReorder: (oldIndex, newIndex) async {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = widget.state.items.removeAt(oldIndex);
            widget.state.items.insert(newIndex, item);
          });
          if (widget.onReorder != null) {
            await widget.onReorder!(widget.state.day.date, oldIndex, newIndex);
          }
        },
      ),
    ); // ReorderableListView enables drag-and-drop reordering of activities with builder for lazy item creation. [12][15]
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    super.key,
    required this.activity,
    this.onOpen,
    this.onMap,
    this.onBook,
    this.onEditNotes,
  });

  final ItineraryActivity activity;
  final void Function(ItineraryActivity activity)? onOpen;
  final void Function(ItineraryActivity activity)? onMap;
  final Future<void> Function(ItineraryActivity activity)? onBook;
  final Future<void> Function(String nextNotes)? onEditNotes;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final time = '${_fmt(context, activity.start)} – ${_fmt(context, activity.end)}';

    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _leading(),
      title: Row(
        children: [
          Expanded(
            child: Text(
              activity.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(time, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((activity.subtitle ?? '').trim().isNotEmpty)
            Text(activity.subtitle!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis),
          if ((activity.notes ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                activity.notes!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          if (onEditNotes != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final next = await _editNotes(context, activity.notes ?? '');
                  if (next != null) await onEditNotes!(next);
                },
                icon: const Icon(Icons.edit_note),
                label: const Text('Edit notes'),
              ),
            ),
        ],
      ),
      trailing: Wrap(
        spacing: 6,
        children: [
          IconButton(
            tooltip: 'Open',
            icon: const Icon(Icons.open_in_new),
            onPressed: onOpen == null ? null : () => onOpen!(activity),
          ),
          IconButton(
            tooltip: 'Map',
            icon: const Icon(Icons.map_outlined),
            onPressed: onMap == null ? null : () => onMap!(activity),
          ),
          if (activity.bookable)
            IconButton(
              tooltip: 'Book',
              icon: const Icon(Icons.event_available_outlined),
              onPressed: onBook == null ? null : () => onBook!(activity),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.drag_handle), // drag handle
        ],
      ),
      onTap: onOpen == null ? null : () => onOpen!(activity),
    );
  }

  Widget _leading() {
    if ((activity.thumbnailUrl ?? '').trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          activity.thumbnailUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(activity.icon ?? Icons.place_outlined, color: Colors.black45),
    );
  }

  String _fmt(BuildContext context, TimeOfDay t) {
    return MaterialLocalizations.of(context).formatTimeOfDay(t);
  }

  Widget _fallback() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.photo, color: Colors.black38),
    );
  }
}

Future<String?> _editNotes(BuildContext context, String current) async {
  final ctrl = TextEditingController(text: current);
  final res = await showDialog<String>(
    context: context,
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Text('Edit notes'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          minLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
  ctrl.dispose();
  return res;
}
