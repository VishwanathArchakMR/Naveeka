// lib/features/quick_actions/presentation/booking/widgets/recent_bookings.dart

import 'package:flutter/material.dart';

import '../../../../quick_actions/data/booking_api.dart';
// Fixed relative import path to the DirectionsButton widget.
import '../../../../places/presentation/widgets/directions_button.dart';

/// Lightweight view model for recent booking rows (decoupled from API DTOs).
class BookingRow {
  const BookingRow({
    required this.reservationId,
    required this.placeId,
    required this.placeName,
    required this.slotStart,
    required this.partySize,
    required this.status, // pending | confirmed | cancelled | completed
    this.coverImage,
    this.address,
    this.lat,
    this.lng,
  });

  final String reservationId;
  final String placeId;
  final String placeName;
  final DateTime slotStart;
  final int partySize;
  final String status;
  final String? coverImage;
  final String? address;
  final double? lat;
  final double? lng;
}

/// Recent bookings list with:
/// - Pull-to-refresh and infinite scroll
/// - Status chips
/// - Swipe-to-cancel (Dismissible)
/// - Actions: Open, Directions, Rebook
class RecentBookings extends StatefulWidget {
  const RecentBookings({
    super.key,
    required this.items,
    required this.loading,
    required this.hasMore,
    required this.onRefresh,
    this.onLoadMore,
    this.onOpen,
    this.onCancel,
    this.onRebook,
    this.sectionTitle = 'Recent bookings',
    this.emptyPlaceholder,
  });

  final List<BookingRow> items;
  final bool loading;
  final bool hasMore;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;

  final void Function(BookingRow row)? onOpen;
  final Future<void> Function(BookingRow row)? onCancel;
  final Future<void> Function(BookingRow row)? onRebook;

  final String sectionTitle;
  final Widget? emptyPlaceholder;

  @override
  State<RecentBookings> createState() => _RecentBookingsState();
}

class _RecentBookingsState extends State<RecentBookings> {
  final _scroll = ScrollController();
  bool _loadRequested = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onLoadMore == null || !widget.hasMore || widget.loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 420) {
      if (_loadRequested) return;
      _loadRequested = true;
      widget.onLoadMore!().whenComplete(() => _loadRequested = false);
    }
  } // Infinite loading triggers near list end to fetch additional reservations for a seamless feed.

  @override
  Widget build(BuildContext context) {
    final hasAny = widget.items.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Expanded(child: Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800))),
                  if (widget.loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: RefreshIndicator.adaptive(
                onRefresh: widget.onRefresh,
                child: hasAny
                    ? ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        itemCount: widget.items.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (context, i) {
                          if (i == widget.items.length) return _footer();
                          final row = widget.items[i];
                          final canDismiss = widget.onCancel != null && row.status != 'cancelled' && row.status != 'completed';
                          return Dismissible(
                            key: ValueKey(row.reservationId),
                            direction: canDismiss ? DismissDirection.endToStart : DismissDirection.none,
                            background: _dismissBg(),
                            confirmDismiss: canDismiss
                                ? (dir) async => await _confirmCancel(context, row)
                                : null,
                            onDismissed: canDismiss
                                ? (_) async {
                                    await widget.onCancel!(row);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Cancelled "${row.placeName}"')),
                                      );
                                    }
                                  }
                                : null,
                            child: _BookingTile(
                              row: row,
                              onOpen: widget.onOpen,
                              onRebook: widget.onRebook,
                            ),
                          );
                        },
                      )
                    : _empty(),
              ),
            ), // RefreshIndicator wraps the list to enable the standard pull-to-refresh gesture for reloading bookings.
          ],
        ),
      ),
    );
  }

  Widget _dismissBg() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.red.shade400,
      child: const Icon(Icons.cancel_outlined, color: Colors.white),
    );
  } // Dismissible uses a leave-behind background to clearly signal the cancel action during a swipe gesture.

  Future<bool> _confirmCancel(BuildContext context, BookingRow row) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cancel reservation?'),
            content: Text('Cancel booking at ${row.placeName}?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes, cancel')),
            ],
          ),
        ) ??
        false;
    return ok;
  }

  Widget _footer() {
    if (widget.loading && widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No more bookings')),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _empty() {
    return widget.emptyPlaceholder ??
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No recent bookings'),
          ),
        );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.row, this.onOpen, this.onRebook});

  final BookingRow row;
  final void Function(BookingRow row)? onOpen;
  final Future<void> Function(BookingRow row)? onRebook;

  @override
  Widget build(BuildContext context) {
    final dt = row.slotStart.toLocal();
    final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final timeStr = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(dt));
    final meta = '$dateStr · $timeStr · ${row.partySize} guest${row.partySize == 1 ? '' : 's'}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _thumb(row.coverImage),
      title: Row(
        children: [
          Expanded(child: Text(row.placeName, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          _StatusChip(status: row.status),
        ],
      ),
      subtitle: Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis),
      isThreeLine: false,
      trailing: _Actions(row: row, onOpen: onOpen, onRebook: onRebook),
      onTap: onOpen == null ? null : () => onOpen!(row),
    ); // ListTile offers an accessible row layout with leading media, primary/secondary text, and trailing actions for bookings.
  }

  Widget _thumb(String? url) {
    if (url == null || url.trim().isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.event_outlined, color: Colors.black38),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color c;
    Color fg;
    IconData ic;
    switch (s) {
      case 'confirmed':
        c = Colors.green.withValues(alpha: 0.12); // migrated from withOpacity
        fg = Colors.green;
        ic = Icons.verified_outlined;
        break;
      case 'pending':
        c = Colors.amber.withValues(alpha: 0.12); // migrated from withOpacity
        fg = Colors.amber.shade800;
        ic = Icons.schedule_outlined;
        break;
      case 'completed':
        c = Colors.blue.withValues(alpha: 0.12); // migrated from withOpacity
        fg = Colors.blue;
        ic = Icons.check_circle_outline;
        break;
      case 'cancelled':
      default:
        c = Colors.red.withValues(alpha: 0.12); // migrated from withOpacity
        fg = Colors.red;
        ic = Icons.cancel_outlined;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(_label(status), style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    ); // A compact chip-like pill conveys booking status with color and icon.
  }

  String _label(String s) {
    final t = s.toLowerCase();
    return t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.row, this.onOpen, this.onRebook});

  final BookingRow row;
  final void Function(BookingRow row)? onOpen;
  final Future<void> Function(BookingRow row)? onRebook;

  @override
  Widget build(BuildContext context) {
    final hasCoords = row.lat != null && row.lng != null;
    return Wrap(
      spacing: 6,
      children: [
        IconButton(
          tooltip: 'Open',
          icon: const Icon(Icons.open_in_new),
          onPressed: onOpen == null ? null : () => onOpen!(row),
        ),
        if (hasCoords)
          // Use the DirectionsButton widget directly instead of calling a non-existent getter.
          DirectionsButton(
            lat: row.lat!,
            lng: row.lng!,
            label: 'Directions',
            expanded: false,
          ),
        IconButton(
          tooltip: 'Rebook',
          icon: const Icon(Icons.event_available_outlined),
          onPressed: onRebook == null ? null : () => onRebook!(row),
        ),
      ],
    ); // Trailing icon buttons expose quick actions without crowding the main tile content.
  }
}

/// Helper to adapt API DTOs to view models.
extension BookingReservationMapper on BookingReservation {
  BookingRow toRow({
    required String placeName,
    String? coverImage,
    String? address,
    double? lat,
    double? lng,
  }) {
    return BookingRow(
      reservationId: id,
      placeId: placeId,
      placeName: placeName,
      slotStart: slotStart,
      partySize: partySize,
      status: status,
      coverImage: coverImage,
      address: address,
      lat: lat,
      lng: lng,
    );
  }
}
