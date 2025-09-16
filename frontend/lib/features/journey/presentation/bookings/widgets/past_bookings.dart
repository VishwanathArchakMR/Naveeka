// lib/features/journey/presentation/bookings/widgets/past_bookings.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'booking_card.dart';

/// A paginated-ready, grouped list of past bookings with:
/// - Pull-to-refresh
/// - Status filter via SegmentedButton
/// - Group headers by month (e.g., "August 2025")
/// - BookingCard rows
///
/// Input "bookings" is a list of normalized maps:
/// {
///   id, title, subtitle?, amount?, currency?,
///   start (DateTime|ISO), end (DateTime|ISO),
///   type ('activity'|'hotel'|'flight'|'train'|'bus'|'cab'|'restaurant'|'generic'),
///   status ('completed'|'cancelled'|'refunded'|'failed'|'confirmed'|'pending'),
///   reference?, leadingImageUrl?
/// }
class PastBookings extends StatefulWidget {
  const PastBookings({
    super.key,
    required this.bookings,
    this.onRefresh,
    this.onTapBooking,
    this.onCancelBooking,
    this.onMoreForBooking,
    this.emptyTitle = 'No past bookings',
    this.emptySubtitle = 'Completed and cancelled bookings will appear here',
  });

  final List<Map<String, dynamic>> bookings;
  final Future<void> Function()? onRefresh;
  final void Function(Map<String, dynamic> booking)? onTapBooking;
  final void Function(Map<String, dynamic> booking)? onCancelBooking;
  final void Function(Map<String, dynamic> booking)? onMoreForBooking;

  final String emptyTitle;
  final String emptySubtitle;

  @override
  State<PastBookings> createState() => _PastBookingsState();
}

enum _StatusFilter { all, completed, cancelled, refunded, failed }

class _PastBookingsState extends State<PastBookings> {
  _StatusFilter _filter = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(widget.bookings, _filter);
    final sections = _groupByMonth(filtered);

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: sections.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 48),
                Icon(Icons.history_toggle_off,
                    size: 48, color: Theme.of(context).colorScheme.outline),
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
                // Header row with segmented filter
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

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> bookings, _StatusFilter filter) {
    if (filter == _StatusFilter.all) return bookings;
    final key = switch (filter) {
      _StatusFilter.completed => 'completed',
      _StatusFilter.cancelled => 'cancelled',
      _StatusFilter.refunded => 'refunded',
      _StatusFilter.failed => 'failed',
      _ => 'all',
    };
    if (key == 'all') return bookings;
    return bookings.where((b) {
      final s = (b['status'] ?? '').toString().toLowerCase();
      return s == key;
    }).toList(growable: false);
  }

  List<_MonthSection> _groupByMonth(List<Map<String, dynamic>> bookings) {
    // Use "start" date for grouping; fallback to "end" when start missing.
    final df = DateFormat.yMMMM();
    final list = [...bookings];
    list.sort((a, b) {
      final ad = _parseDate(a['start']) ?? _parseDate(a['end']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = _parseDate(b['start']) ?? _parseDate(b['end']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad); // newest first
    });

    final sections = <_MonthSection>[];
    String? currentKey;
    for (final b in list) {
      final d = _parseDate(b['start']) ?? _parseDate(b['end']);
      final key = d != null ? df.format(d) : 'Undated';
      if (currentKey != key) {
        sections.add(_MonthSection(title: key, items: []));
        currentKey = key;
      }
      sections.last.items.add(b);
    }
    return sections;
  }

  DateTime? _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.filter,
    required this.onFilterChanged,
  });

  final _StatusFilter filter;
  final ValueChanged<_StatusFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Text(
            'Past bookings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          SegmentedButton<_StatusFilter>(
            segments: const [
              ButtonSegment<_StatusFilter>(value: _StatusFilter.all, label: Text('All'), icon: Icon(Icons.inbox_outlined)),
              ButtonSegment<_StatusFilter>(value: _StatusFilter.completed, label: Text('Done'), icon: Icon(Icons.check_circle_outline)),
              ButtonSegment<_StatusFilter>(value: _StatusFilter.cancelled, label: Text('Cancelled'), icon: Icon(Icons.cancel_outlined)),
              ButtonSegment<_StatusFilter>(value: _StatusFilter.refunded, label: Text('Refunded'), icon: Icon(Icons.currency_rupee)),
              ButtonSegment<_StatusFilter>(value: _StatusFilter.failed, label: Text('Failed'), icon: Icon(Icons.error_outline)),
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
        _MonthHeader(title: title),
        const SizedBox(height: 8),
        ...items.map((b) {
          final type = _typeFromStr((b['type'] ?? 'generic').toString());
          final status = _statusFromStr((b['status'] ?? 'completed').toString());
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
        return BookingStatus.completed;
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

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.title});
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

class _MonthSection {
  _MonthSection({required this.title, required this.items});
  final String title;
  final List<Map<String, dynamic>> items;
}
