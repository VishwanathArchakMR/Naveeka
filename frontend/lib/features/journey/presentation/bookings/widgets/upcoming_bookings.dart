// lib/features/journey/presentation/bookings/widgets/upcoming_bookings.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'booking_card.dart';

/// A grouped list of upcoming bookings with:
/// - Pull-to-refresh
/// - Time filters (All, Today, Week, Month)
/// - Date headers (Today, Tomorrow, or formatted dates)
/// - BookingCard rows with actions
///
/// Expected booking map (normalized):
/// {
///   id, title, subtitle?, amount?, currency?,
///   start (DateTime|ISO), end (DateTime|ISO),
///   type ('activity'|'hotel'|'flight'|'train'|'bus'|'cab'|'restaurant'|'generic'),
///   status ('pending'|'confirmed'|'completed'|'cancelled'|'failed'|'refunded'),
///   reference?, leadingImageUrl?
/// }
class UpcomingBookings extends StatefulWidget {
  const UpcomingBookings({
    super.key,
    required this.bookings,
    this.onRefresh,
    this.onTapBooking,
    this.onCancelBooking,
    this.onMoreForBooking,
    this.emptyTitle = 'No upcoming bookings',
    this.emptySubtitle = 'New bookings will appear here with quick actions',
  });

  final List<Map<String, dynamic>> bookings;
  final Future<void> Function()? onRefresh;
  final void Function(Map<String, dynamic> booking)? onTapBooking;
  final void Function(Map<String, dynamic> booking)? onCancelBooking;
  final void Function(Map<String, dynamic> booking)? onMoreForBooking;

  final String emptyTitle;
  final String emptySubtitle;

  @override
  State<UpcomingBookings> createState() => _UpcomingBookingsState();
}

enum _TimeFilter { all, today, week, month }

class _UpcomingBookingsState extends State<UpcomingBookings> {
  _TimeFilter _filter = _TimeFilter.all;

  @override
  Widget build(BuildContext context) {
    // Only future (or ongoing today) items are relevant for "upcoming"
    final now = DateTime.now();
    final upcoming = widget.bookings.where((b) {
      final start = _parseDate(b['start']) ?? _parseDate(b['end']);
      if (start == null) return false;
      final startAtMidnight = DateTime(start.year, start.month, start.day);
      final todayMidnight = DateTime(now.year, now.month, now.day);
      return startAtMidnight.isAfter(todayMidnight) || startAtMidnight.isAtSameMomentAs(todayMidnight);
    }).toList(growable: false);

    final filtered = _applyFilter(upcoming, _filter);
    final sections = _groupByDay(filtered);

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: sections.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 48),
                Icon(Icons.event_busy, size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(
                  widget.emptyTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.emptySubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: sections.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Header(
                    filter: _filter,
                    onFilterChanged: (f) => setState(() => _filter = f),
                  );
                }
                final sec = sections[index - 1];
                return _Section(
                  title: sec.title,
                  items: sec.items,
                  onTap: widget.onTapBooking,
                  onCancel: widget.onCancelBooking,
                  onMore: widget.onMoreForBooking,
                );
              },
            ),
    );
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> list, _TimeFilter filter) {
    if (filter == _TimeFilter.all) return list;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekEnd = todayStart.add(Duration(days: 7 - todayStart.weekday)); // end of this week
    final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1)); // last day of current month

    bool inToday(DateTime d) {
      final ds = DateTime(d.year, d.month, d.day);
      return ds.isAtSameMomentAs(todayStart);
    }

    bool inWeek(DateTime d) {
      final ds = DateTime(d.year, d.month, d.day);
      return (ds.isAfter(todayStart) || ds.isAtSameMomentAs(todayStart)) && ds.isBefore(weekEnd.add(const Duration(days: 1)));
    }

    bool inMonth(DateTime d) {
      final ds = DateTime(d.year, d.month, d.day);
      // Use monthEnd to properly bound the month filter
      return (ds.isAfter(todayStart) || ds.isAtSameMomentAs(todayStart)) && 
             (ds.isBefore(monthEnd.add(const Duration(days: 1))) || ds.isAtSameMomentAs(monthEnd));
    }

    return list.where((b) {
      final start = _parseDate(b['start']) ?? _parseDate(b['end']);
      if (start == null) return false;
      switch (filter) {
        case _TimeFilter.today:
          return inToday(start);
        case _TimeFilter.week:
          return inWeek(start);
        case _TimeFilter.month:
          return inMonth(start);
        case _TimeFilter.all:
          return true;
      }
    }).toList(growable: false);
  }

  List<_DaySection> _groupByDay(List<Map<String, dynamic>> list) {
    final now = DateTime.now();
    final df = DateFormat.yMMMEd();

    list.sort((a, b) {
      final ad = _parseDate(a['start']) ?? _parseDate(a['end']) ?? DateTime.now();
      final bd = _parseDate(b['start']) ?? _parseDate(b['end']) ?? DateTime.now();
      return ad.compareTo(bd); // earliest first
    });

    final sections = <_DaySection>[];
    String? currentKey;

    for (final b in list) {
      final d = _parseDate(b['start']) ?? _parseDate(b['end']);
      if (d == null) continue;
      final title = _dayLabel(now, d, df);
      if (currentKey != title) {
        sections.add(_DaySection(title: title, items: []));
        currentKey = title;
      }
      sections.last.items.add(b);
    }

    return sections;
  }

  String _dayLabel(DateTime now, DateTime d, DateFormat df) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);

    if (day.isAtSameMomentAs(today)) return 'Today';
    if (day.isAtSameMomentAs(today.add(const Duration(days: 1)))) return 'Tomorrow';
    return df.format(d);
  }

  DateTime? _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.filter, required this.onFilterChanged});

  final _TimeFilter filter;
  final ValueChanged<_TimeFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Text(
            'Upcoming',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          SegmentedButton<_TimeFilter>(
            segments: const [
              ButtonSegment(value: _TimeFilter.all, label: Text('All'), icon: Icon(Icons.inbox_outlined)),
              ButtonSegment(value: _TimeFilter.today, label: Text('Today'), icon: Icon(Icons.today_outlined)),
              ButtonSegment(value: _TimeFilter.week, label: Text('Week'), icon: Icon(Icons.view_week_outlined)),
              ButtonSegment(value: _TimeFilter.month, label: Text('Month'), icon: Icon(Icons.calendar_month_outlined)),
            ],
            selected: {filter},
            onSelectionChanged: (s) => onFilterChanged(s.first),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.items,
    this.onTap,
    this.onCancel,
    this.onMore,
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> booking)? onTap;
  final void Function(Map<String, dynamic> booking)? onCancel;
  final void Function(Map<String, dynamic> booking)? onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayHeader(title: title),
        const SizedBox(height: 8),
        ...items.map((b) {
          final type = _typeFromStr((b['type'] ?? 'generic').toString());
          final status = _statusFromStr((b['status'] ?? 'confirmed').toString());
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BookingCard(
              title: (b['title'] ?? '').toString(),
              subtitle: (b['subtitle'] ?? '').toString().isEmpty ? null : (b['subtitle'] ?? '').toString(),
              type: type,
              status: status,
              reference: (b['reference'] ?? b['ref'])?.toString(),
              start: _parseDate(b['start']),
              end: _parseDate(b['end']),
              currency: (b['currency'] ?? '₹').toString(),
              amount: b['amount'] is num ? b['amount'] as num : _toNum(b['amount']),
              leadingImageUrl: (b['leadingImageUrl'] ?? b['imageUrl'])?.toString(),
              onTap: onTap != null ? () => onTap!(b) : null,
              onCancel: onCancel != null ? () => onCancel!(b) : null,
              onMore: onMore != null ? () => onMore!(b) : null,
            ),
          );
        }),
      ],
    );
  }

  BookingType _typeFromStr(String s) {
    switch (s.toLowerCase()) {
      case 'activity':
        return BookingType.activity;
      case 'hotel':
        return BookingType.hotel;
      case 'flight':
        return BookingType.flight;
      case 'train':
        return BookingType.train;
      case 'bus':
        return BookingType.bus;
      case 'cab':
        return BookingType.cab;
      case 'restaurant':
        return BookingType.restaurant;
      default:
        return BookingType.generic;
    }
  }

  BookingStatus _statusFromStr(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return BookingStatus.pending;
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'failed':
        return BookingStatus.failed;
      case 'refunded':
        return BookingStatus.refunded;
      default:
        return BookingStatus.confirmed;
    }
  }

  DateTime? _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  num? _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DaySection {
  _DaySection({required this.title, required this.items});
  final String title;
  final List<Map<String, dynamic>> items;
}
