// lib/features/quick_actions/presentation/planning/widgets/group_chat.dart

import 'package:flutter/material.dart';

import '../../messages/widgets/message_thread.dart';
import '../../messages/widgets/suggested_places_messages.dart';
import '/../models/place.dart';
import '/../models/unit_system.dart';
import '/../models/share_location_request.dart';
import '/../../models/geo_point.dart';
import '/../../models/message_item.dart';
// Avoid UnitSystem name clash by aliasing and hiding UnitSystem from this import.


class GroupParticipant {
  const GroupParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
}

enum _GroupMode { chat, polls, schedule }

class PollDraft {
  const PollDraft({required this.question, required this.options});
  final String question;
  final List<String> options;
}

class GroupChat extends StatefulWidget {
  const GroupChat({
    super.key,
    required this.groupTitle,
    required this.participants,

    // Chat data
    required this.currentUserId,
    required this.messages,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onSendText,
    this.onAttach,
    this.onShareLocation,
    this.onOpenAttachment,
    this.onOpenLocation,

    // Suggestions for planning
    this.suggestedPlaces = const <Place>[],
    this.placesLoading = false,
    this.placesHasMore = false,
    this.onPlacesRefresh,
    this.onPlacesLoadMore,
    this.onOpenPlace,
    this.onSharePlace,
    this.onBookPlace,

    // Polls and schedule
    this.onCreatePoll, // Future<void> Function(PollDraft)
    this.onProposeSchedule, // Future<void> Function(DateTimeRange)
    this.initialPlanSummary,
    this.unit = UnitSystem.metric,
  });

  final String groupTitle;
  final List<GroupParticipant> participants;

  // Chat
  final String currentUserId;
  final List<MessageItem> messages;
  final bool loading;
  final bool hasMore;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;

  final Future<void> Function(String text)? onSendText;
  final Future<void> Function()? onAttach;
  final Future<void> Function(ShareLocationRequest req)? onShareLocation;

  final void Function(String url)? onOpenAttachment;
  final void Function(GeoPoint point)? onOpenLocation;

  // Suggested places
  final List<Place> suggestedPlaces;
  final bool placesLoading;
  final bool placesHasMore;

  final Future<void> Function()? onPlacesRefresh;
  final Future<void> Function()? onPlacesLoadMore;

  final void Function(Place place)? onOpenPlace;
  final Future<void> Function(Place place)? onSharePlace;
  final Future<void> Function(Place place)? onBookPlace;

  // Planning actions
  final Future<void> Function(PollDraft draft)? onCreatePoll;
  final Future<void> Function(DateTimeRange range)? onProposeSchedule;

  final String? initialPlanSummary;

  final UnitSystem unit;

  @override
  State<GroupChat> createState() => _GroupChatState();
}

class _GroupChatState extends State<GroupChat> {
  _GroupMode _mode = _GroupMode.chat;

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
          children: [
            // Header: title + participant avatars + quick actions
            _HeaderBar(
              title: widget.groupTitle,
              participants: widget.participants,
              onCreatePoll: widget.onCreatePoll == null ? null : () => _openPollCreator(context),
              onProposeSchedule: widget.onProposeSchedule == null ? null : () => _openScheduleSheet(context),
            ),

            const SizedBox(height: 8),

            // Mode chips (single-select)
            _ModeChips(
              selected: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),

            const SizedBox(height: 8),

            // Optional plan summary that can be collapsed
            if ((widget.initialPlanSummary ?? '').trim().isNotEmpty)
              _PlanSummaryPanel(text: widget.initialPlanSummary!.trim()),

            const SizedBox(height: 8),

            // Body per mode
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_mode) {
      case _GroupMode.chat:
        return Column(
          children: [
            // Thread
            Expanded(
              child: MessageThread(
                // Provide only known/required parameters for MessageThread.
                messages: widget.messages,
                loading: widget.loading,
                onSendMessage: (text) async {
                  final cb = widget.onSendText;
                  if (cb != null) await cb(text);
                },
              ),
            ),

            const SizedBox(height: 8),

            // Planning suggestions carousel (places to propose in the chat)
            SuggestedPlacesMessages(
              places: widget.suggestedPlaces,
              loading: widget.placesLoading,
              hasMore: widget.placesHasMore,
              onRefresh: widget.onPlacesRefresh ?? () async {},
              onLoadMore: widget.onPlacesLoadMore,
              onOpenPlace: widget.onOpenPlace,
              onSharePlace: widget.onSharePlace,
              onBook: widget.onBookPlace,
              originLat: null,
              originLng: null,
              unit: widget.unit,
              sectionTitle: 'Suggested for the plan',
            ),
          ],
        );

      case _GroupMode.polls:
        return _PollsEmptyState(
          onCreate: widget.onCreatePoll == null ? null : () => _openPollCreator(context),
        );

      case _GroupMode.schedule:
        return _ScheduleEmptyState(
          onPropose: widget.onProposeSchedule == null ? null : () => _openScheduleSheet(context),
        );
    }
  }

  Future<void> _openPollCreator(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final draft = await _PollCreatorSheet.show(context);
    if (draft != null && widget.onCreatePoll != null) {
      await widget.onCreatePoll!(draft);
      messenger.showSnackBar(const SnackBar(content: Text('Poll created')));
    }
  }

  Future<void> _openScheduleSheet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final range = await _ScheduleSheet.show(context);
    if (range != null && widget.onProposeSchedule != null) {
      await widget.onProposeSchedule!(range);
      messenger.showSnackBar(const SnackBar(content: Text('Schedule proposed')));
    }
  }
}

// ---------------- Header ----------------

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.title,
    required this.participants,
    this.onCreatePoll,
    this.onProposeSchedule,
  });

  final String title;
  final List<GroupParticipant> participants;
  final VoidCallback? onCreatePoll;
  final VoidCallback? onProposeSchedule;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(width: 8),
              _AvatarsRow(participants: participants),
            ],
          ),
        ),
        if (onCreatePoll != null)
          OutlinedButton.icon(
            onPressed: onCreatePoll,
            icon: const Icon(Icons.how_to_vote_outlined, size: 18),
            label: const Text('Poll'),
          ),
        const SizedBox(width: 8),
        if (onProposeSchedule != null)
          OutlinedButton.icon(
            onPressed: onProposeSchedule,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: const Text('Schedule'),
          ),
      ],
    );
  }
}

class _AvatarsRow extends StatelessWidget {
  const _AvatarsRow({required this.participants});
  final List<GroupParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surfaceContainerHigh.withValues(alpha: 1.0);
    return SizedBox(
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(participants.length.clamp(0, 3), (i) {
          final p = participants[i];
          return Positioned(
            left: i * 16.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: bg, width: 2)),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black12,
                    backgroundImage: (p.avatarUrl != null && p.avatarUrl!.trim().isNotEmpty) ? NetworkImage(p.avatarUrl!) : null,
                    child: (p.avatarUrl == null || p.avatarUrl!.trim().isEmpty)
                        ? Text(p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase(), style: const TextStyle(fontSize: 12))
                        : null,
                  ),
                ),
                if (p.isOnline)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: bg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ---------------- Mode chips ----------------

class _ModeChips extends StatelessWidget {
  const _ModeChips({required this.selected, required this.onChanged});

  final _GroupMode selected;
  final ValueChanged<_GroupMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const items = [
      (_GroupMode.chat, 'Chat', Icons.chat_bubble_outline),
      (_GroupMode.polls, 'Polls', Icons.how_to_vote_outlined),
      (_GroupMode.schedule, 'Schedule', Icons.event_outlined),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((e) {
        final isOn = selected == e.$1;
        final bg = isOn ? cs.primary.withValues(alpha: 0.14) : cs.surfaceContainerHigh.withValues(alpha: 1.0);
        final fg = isOn ? cs.primary : cs.onSurface;
        return ChoiceChip(
          avatar: Icon(e.$3, size: 16, color: fg),
          label: Text(e.$2, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
          selected: isOn,
          onSelected: (_) => onChanged(e.$1),
          selectedColor: cs.primary.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          side: BorderSide(color: isOn ? cs.primary : cs.outlineVariant),
          backgroundColor: bg,
        );
      }).toList(growable: false),
    );
  }
}

// ---------------- Plan summary ----------------

class _PlanSummaryPanel extends StatefulWidget {
  const _PlanSummaryPanel({required this.text});
  final String text;

  @override
  State<_PlanSummaryPanel> createState() => _PlanSummaryPanelState();
}

class _PlanSummaryPanelState extends State<_PlanSummaryPanel> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExpansionPanelList(
      elevation: 0,
      expansionCallback: (_, isOpen) => setState(() => _open = !isOpen),
      expandedHeaderPadding: EdgeInsets.zero,
      materialGapSize: 0,
      children: [
        ExpansionPanel(
          isExpanded: _open,
          canTapOnHeader: true,
          headerBuilder: (_, __) => const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Plan summary', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          body: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(widget.text, style: TextStyle(color: cs.onSurface)),
          ),
          backgroundColor: cs.surfaceContainerHigh.withValues(alpha: 1.0),
        ),
      ],
    );
  }
}

// ---------------- Polls ----------------

class _PollsEmptyState extends StatelessWidget {
  const _PollsEmptyState({this.onCreate});
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.how_to_vote_outlined, size: 40),
          const SizedBox(height: 8),
          Text('No polls yet', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (onCreate != null) FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create poll')),
        ],
      ),
    );
  }
}

class _PollCreatorSheet extends StatefulWidget {
  const _PollCreatorSheet();

  static Future<PollDraft?> show(BuildContext context) {
    return showModalBottomSheet<PollDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _PollCreatorSheet(),
    );
  }

  @override
  State<_PollCreatorSheet> createState() => _PollCreatorSheetState();
}

class _PollCreatorSheetState extends State<_PollCreatorSheet> {
  final _q = TextEditingController();
  final List<TextEditingController> _opts = [TextEditingController(), TextEditingController()];
  bool _busy = false;

  @override
  void dispose() {
    _q.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Create poll', style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            TextField(
              controller: _q,
              decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            ..._buildOptionFields(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _opts.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('Add option'),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptionFields() {
    return List<Widget>.generate(_opts.length, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: _opts[i],
          decoration: InputDecoration(
            labelText: 'Option ${i + 1}',
            border: const OutlineInputBorder(),
            suffixIcon: i > 1
                ? IconButton(
                    onPressed: () => setState(() => _opts.removeAt(i)),
                    icon: const Icon(Icons.close),
                  )
                : null,
          ),
        ),
      );
    });
  }

  Future<void> _submit() async {
    final q = _q.text.trim();
    final options = _opts.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
    if (q.isEmpty || options.length < 2) return;
    setState(() => _busy = true);
    try {
      Navigator.pop(context, PollDraft(question: q, options: options));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ---------------- Schedule ----------------

class _ScheduleEmptyState extends StatelessWidget {
  const _ScheduleEmptyState({this.onPropose});
  final VoidCallback? onPropose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_outlined, size: 40),
          const SizedBox(height: 8),
          Text('No schedule proposed', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (onPropose != null)
            FilledButton.icon(onPressed: onPropose, icon: const Icon(Icons.add), label: const Text('Propose time')),
        ],
      ),
    );
  }
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet();

  static Future<DateTimeRange?> show(BuildContext context) {
    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _ScheduleSheet(),
    );
  }

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  DateTime _end = DateTime.now().add(const Duration(hours: 3));
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      // Fix: use shape for RoundedRectangleBorder
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Propose schedule', style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            _ScheduleRow(
              label: 'Start',
              value: _fmt(_start),
              onAddHour: () => setState(() => _start = _start.add(const Duration(hours: 1))),
              onSubHour: () => setState(() => _start = _start.subtract(const Duration(hours: 1))),
            ),
            const SizedBox(height: 8),
            _ScheduleRow(
              label: 'End',
              value: _fmt(_end),
              onAddHour: () => setState(() => _end = _end.add(const Duration(hours: 1))),
              onSubHour: () => setState(() => _end = _end.subtract(const Duration(hours: 1))),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Send proposal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_end.isAfter(_start)) return;
    setState(() => _busy = true);
    try {
      Navigator.pop(context, DateTimeRange(start: _start, end: _end));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    final date = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date · $time';
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.label,
    required this.value,
    required this.onAddHour,
    required this.onSubHour,
  });

  final String label;
  final String value;
  final VoidCallback onAddHour;
  final VoidCallback onSubHour;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text(value),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: onSubHour, child: const Text('-1h')),
        const SizedBox(width: 6),
        OutlinedButton(onPressed: onAddHour, child: const Text('+1h')),
      ],
    );
  }
}
