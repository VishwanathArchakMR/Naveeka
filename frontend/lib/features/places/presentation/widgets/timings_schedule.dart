// lib/features/places/presentation/widgets/timings_schedule.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';

/// A reusable hours-of-operation widget:
/// - Collapsed header shows "Open now / Closed" and next change
/// - Expansion reveals weekly schedule, highlights "today"
/// - Supports multiple intervals per day (e.g., 10:00–14:00, 17:00–22:00)
/// - Fallback to raw openingHours text if structured data is missing
class TimingsSchedule extends StatelessWidget {
  const TimingsSchedule({
    super.key,
    required this.weekly,           // Monday..Sunday entries (1..7)
    this.timezone,
    this.rawText,
    this.title = 'Hours',
    this.showTitle = true,
    this.accentColor,
    DateTime? now,
  }) : _now = now;

  /// Convenience: build from Place; uses structured fields if present, else falls back to openingHours text.
  factory TimingsSchedule.fromPlace(Place p, {Key? key, String title = 'Hours', bool showTitle = true, Color? accentColor, DateTime? now}) {
    // Expect an optional structured weekly hours in the model, otherwise fallback to raw text.
    final structured = _extractWeeklyFromPlace(p);
    return TimingsSchedule(
      key: key,
      weekly: structured,
      timezone: p.timezone, // optional in your model
      rawText: structured.isEmpty ? p.openingHours : null,
      title: title,
      showTitle: showTitle,
      accentColor: accentColor,
      now: now,
    );
  }

  final List<DailyHours> weekly;
  final String? timezone;
  final String? rawText;
  final String title;
  final bool showTitle;
  final Color? accentColor;

  final DateTime? _now;

  @override
  Widget build(BuildContext context) {
    final now = _now ?? DateTime.now();
    final todayIdx = _weekdayIndex(now.weekday);
    final today = weekly.isNotEmpty ? weekly[(todayIdx - 1) % 7] : null;

    final status = _statusAt(now, tzName: timezone);
    final isOpen = status.isOpen;
    final nextLabel = status.nextChangeLabel(context);

    // Fallback: rawText only
    if (weekly.isEmpty && (rawText ?? '').trim().isNotEmpty) {
      return Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitle)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_outlined),
                      const SizedBox(width: 8),
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(isOpen ? Icons.circle : Icons.circle_outlined, color: isOpen ? Colors.green : Colors.red),
                title: Text(isOpen ? 'Open now' : 'Closed'),
                subtitle: nextLabel != null ? Text(nextLabel) : null,
              ),
              const SizedBox(height: 8),
              Text(rawText!.trim()),
            ],
          ),
        ),
      ); // Raw-text fallback uses a compact ListTile header with open/closed status, matching Material list patterns. [21]
    }

    // Structured schedule path
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                if (showTitle)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_outlined),
                        const SizedBox(width: 8),
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOpen ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(isOpen ? 'Open now' : 'Closed', style: TextStyle(color: isOpen ? Colors.green : Colors.red, fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            if (nextLabel != null) ...[
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: Text(nextLabel, style: const TextStyle(color: Colors.black54))),
            ],

            if ((timezone ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Align(alignment: Alignment.centerLeft, child: Text('Time zone: ${timezone!.trim()}', style: const TextStyle(color: Colors.black45, fontSize: 12))),
            ],

            const SizedBox(height: 8),

            // Expandable weekly list
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('This week', style: const TextStyle(fontWeight: FontWeight.w700)),
                children: weekly.map((d) {
                  final isToday = d.weekday == today?.weekday;
                  final hl = isToday ? (accentColor ?? Theme.of(context).colorScheme.primary) : Colors.transparent;
                  final fg = isToday ? Theme.of(context).colorScheme.onPrimary : null;

                  return Container(
                    decoration: BoxDecoration(
                      color: isToday ? hl.withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: SizedBox(
                        width: 84,
                        child: Text(
                          _weekdayLabel(d.weekday),
                          style: TextStyle(fontWeight: isToday ? FontWeight.w800 : FontWeight.w500, color: isToday ? null : Colors.black87),
                        ),
                      ),
                      title: _IntervalsText(intervals: d.intervals),
                      trailing: d.closed
                          ? Text('Closed', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade400))
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ); // Weekly view uses ExpansionTile for compact expand/collapse and ListTile rows for clear, accessible daily entries. [9][21]
  }

  // ----- Helpers -----

  static List<DailyHours> _extractWeeklyFromPlace(Place p) {
    // If your Place model has structured hours, map them here.
    // Expected flexible shape in your model:
    // p.hoursWeekly?: [{ "weekday":1..7, "intervals":[{"start":"09:00","end":"18:00"}], "closed":false }, ...]
    final raw = p.hoursWeekly; // dynamic/nullable in your model
    if (raw is List) {
      final out = <DailyHours>[];
      for (final e in raw) {
        if (e is Map) {
          final wd = (e['weekday'] as num?)?.toInt();
          if (wd == null) continue;
          final closed = e['closed'] == true;
          final list = <HoursInterval>[];
          final arr = e['intervals'];
          if (arr is List) {
            for (final it in arr) {
              if (it is Map) {
                final s = (it['start'] ?? '').toString();
                final en = (it['end'] ?? '').toString();
                final ts = _tryParseTime(s);
                final te = _tryParseTime(en);
                if (ts != null && te != null) list.add(HoursInterval(start: ts, end: te));
              }
            }
          }
          out.add(DailyHours(weekday: wd, intervals: list, closed: closed));
        }
      }
      // Ensure order Monday..Sunday if needed
      out.sort((a, b) => a.weekday.compareTo(b.weekday));
      return out;
    }
    return const <DailyHours>[];
  }

  static TimeOfDay? _tryParseTime(String v) {
    // Accept "HH:mm" 24h
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final mi = int.tryParse(m.group(2)!);
    if (h == null || mi == null) return null;
    if (h < 0 || h > 23 || mi < 0 || mi > 59) return null;
    return TimeOfDay(hour: h, minute: mi);
  } // TimeOfDay is the Material value object for day times and works with locale-aware formatting via MaterialLocalizations. [7]

  String _weekdayLabel(int weekday) {
    // 1=Mon ... 7=Sun (ISO-8601)
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return 'Day';
    }
  }

  int _weekdayIndex(int dartWeekday) {
    // Dart DateTime.weekday: 1=Mon..7=Sun already in ISO-8601 order
    return dartWeekday;
  }

  _OpenStatus _statusAt(DateTime now, {String? tzName}) {
    if (weekly.isEmpty) return _OpenStatus(false, null);
    final todayIdx = _weekdayIndex(now.weekday);
    final today = weekly[(todayIdx - 1) % 7];

    bool openNow = false;
    TimeOfDay? nextOpen;
    TimeOfDay? nextClose;

    final local = TimeOfDay(hour: now.hour, minute: now.minute);
    // Is inside any interval today?
    for (final it in today.intervals) {
      if (_within(local, it)) {
        openNow = true;
        nextClose = it.end;
        break;
      } else if (_before(local, it.start)) {
        nextOpen = (nextOpen == null || _before(it.start, nextOpen!)) ? it.start : nextOpen;
      }
    }

    if (openNow) {
      return _OpenStatus(true, (ctx) => 'Closes ${_fmt(ctx, nextClose)}');
    }

    // If no more openings today, find next opening day
    if (nextOpen == null) {
      for (var i = 1; i <= 7; i++) {
        final idx = ((todayIdx - 1 + i) % 7);
        final d = weekly[idx];
        if (d.closed || d.intervals.isEmpty) continue;
        nextOpen = d.intervals.first.start;
        final label = i == 1
            ? 'tomorrow'
            : _weekdayLabel(d.weekday);
        return _OpenStatus(false, (ctx) => 'Opens ${_fmt(ctx, nextOpen)} $label');
      }
      return _OpenStatus(false, null);
    }

    return _OpenStatus(false, (ctx) => 'Opens ${_fmt(ctx, nextOpen)}');
  }

  bool _within(TimeOfDay t, HoursInterval i) {
    final a = t.hour * 60 + t.minute;
    final s = i.start.hour * 60 + i.start.minute;
    final e = i.end.hour * 60 + i.end.minute;
    return a >= s && a < e;
  }

  bool _before(TimeOfDay a, TimeOfDay b) {
    final ma = a.hour * 60 + a.minute;
    final mb = b.hour * 60 + b.minute;
    return ma < mb;
  }

  String _fmt(BuildContext context, TimeOfDay? t) {
    if (t == null) return '';
    // MaterialLocalizations provides locale-aware time formatting (12/24h). [7]
    return MaterialLocalizations.of(context).formatTimeOfDay(t);
  }
}

/// A single day’s hours.
/// weekday: 1=Mon..7=Sun (ISO-8601)
class DailyHours {
  const DailyHours({
    required this.weekday,
    this.intervals = const <HoursInterval>[],
    this.closed = false,
  });

  final int weekday;
  final List<HoursInterval> intervals;
  final bool closed;
}

class HoursInterval {
  const HoursInterval({required this.start, required this.end});
  final TimeOfDay start;
  final TimeOfDay end;
}

class _OpenStatus {
  _OpenStatus(this.isOpen, this._next);
  final bool isOpen;
  final String Function(BuildContext ctx)? _next;
  String? nextChangeLabel(BuildContext ctx) => _next?.call(ctx);
}

class _IntervalsText extends StatelessWidget {
  const _IntervalsText({required this.intervals});
  final List<HoursInterval> intervals;

  @override
  Widget build(BuildContext context) {
    if (intervals.isEmpty) {
      return const Text('—', style: TextStyle(color: Colors.black54));
    }
    final l = MaterialLocalizations.of(context);
    final text = intervals
        .map((it) => '${l.formatTimeOfDay(it.start)} – ${l.formatTimeOfDay(it.end)}')
        .join(', ');
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w600));
  }
}
