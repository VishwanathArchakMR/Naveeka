// lib/features/journey/presentation/bookings/widgets/booking_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum BookingType { activity, hotel, flight, train, bus, cab, restaurant, generic }
enum BookingStatus { pending, confirmed, completed, cancelled, failed, refunded }

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.title,
    this.subtitle,
    this.type = BookingType.generic,
    this.status = BookingStatus.confirmed,
    this.reference,
    this.start,
    this.end,
    this.currency = '₹',
    this.amount,
    this.leadingImageUrl,
    this.onTap,
    this.onCancel,
    this.onMore,
  });

  final String title;
  final String? subtitle;
  final BookingType type;
  final BookingStatus status;
  final String? reference;

  final DateTime? start;
  final DateTime? end;

  final String currency;
  final num? amount;

  final String? leadingImageUrl;

  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final statusSpec = _statusSpec(context, status);
    final icon = _iconFor(type);

    return Card(
      clipBehavior: Clip.antiAlias, // Ensures ripple and child content clip to rounded shape [1]
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            _LeadingVisual(
              icon: icon,
              imageUrl: leadingImageUrl,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(statusSpec.label),
                          visualDensity: VisualDensity.compact,
                          labelStyle: TextStyle(
                            color: statusSpec.fg,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: statusSpec.bg,
                          side: BorderSide(color: statusSpec.border),
                        ), // Status as a compact Chip per Material guidance [7][18]
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                    if (reference != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ref: $reference',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black45, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Dates row
                    _DatesRow(start: start, end: end),
                    const SizedBox(height: 10),
                    // Price + actions
                    Row(
                      children: [
                        if (amount != null)
                          Text(
                            '$currency${amount!.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        const Spacer(),
                        if (onCancel != null && _canCancel(status))
                          OutlinedButton.icon(
                            onPressed: onCancel,
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Cancel'),
                          ),
                        if (onMore != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: onMore,
                            icon: const Icon(Icons.more_vert),
                            tooltip: 'More',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canCancel(BookingStatus s) {
    return s == BookingStatus.pending ||
        s == BookingStatus.confirmed; // simple policy, adjust per domain rules
  }

  _StatusSpec _statusSpec(BuildContext context, BookingStatus s) {
    final scheme = Theme.of(context).colorScheme;
    switch (s) {
      case BookingStatus.pending:
        return _StatusSpec(
          label: 'Pending',
          fg: scheme.onSecondaryContainer,
          bg: scheme.secondaryContainer.withValues(alpha: 0.6),
          border: scheme.secondaryContainer,
        );
      case BookingStatus.confirmed:
        return _StatusSpec(
          label: 'Confirmed',
          fg: scheme.onPrimaryContainer,
          bg: scheme.primaryContainer.withValues(alpha: 0.6),
          border: scheme.primaryContainer,
        );
      case BookingStatus.completed:
        return _StatusSpec(
          label: 'Completed',
          fg: Colors.white,
          bg: Colors.green.withValues(alpha: 0.8),
          border: Colors.green,
        );
      case BookingStatus.cancelled:
        return _StatusSpec(
          label: 'Cancelled',
          fg: Colors.white,
          bg: Colors.red.withValues(alpha: 0.7),
          border: Colors.red,
        );
      case BookingStatus.failed:
        return _StatusSpec(
          label: 'Failed',
          fg: Colors.white,
          bg: Colors.redAccent.withValues(alpha: 0.8),
          border: Colors.redAccent,
        );
      case BookingStatus.refunded:
        return _StatusSpec(
          label: 'Refunded',
          fg: scheme.onTertiaryContainer,
          bg: scheme.tertiaryContainer.withValues(alpha: 0.7),
          border: scheme.tertiaryContainer,
        );
    }
  }

  IconData _iconFor(BookingType t) {
    switch (t) {
      case BookingType.activity:
        return Icons.hiking;
      case BookingType.hotel:
        return Icons.bed_outlined;
      case BookingType.flight:
        return Icons.flight_takeoff;
      case BookingType.train:
        return Icons.train_outlined;
      case BookingType.bus:
        return Icons.directions_bus_filled_outlined;
      case BookingType.cab:
        return Icons.local_taxi_outlined;
      case BookingType.restaurant:
        return Icons.restaurant_outlined;
      case BookingType.generic:
        return Icons.receipt_long_outlined;
    }
  }
}

class _LeadingVisual extends StatelessWidget {
  const _LeadingVisual({required this.icon, this.imageUrl});

  final IconData icon;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 70.0;
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Ink.image(
              image: NetworkImage(imageUrl!),
              fit: BoxFit.cover,
            )
          : Center(
              child: Icon(icon, size: 28, color: Colors.black54),
            ),
    );
  }
}

class _DatesRow extends StatelessWidget {
  const _DatesRow({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final hasEnd = end != null && start != null && !end!.isAtSameMomentAs(start!);
    return Row(
      children: [
        const Icon(Icons.event, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _buildDateRange(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _buildDateRange() {
    if (start == null && end == null) return '-';
    final dfDate = DateFormat.yMMMEd(); // Intl DateFormat for a friendly date [9][12]
    final dfTime = DateFormat.jm(); // Time in locale-friendly format [9][19]
    if (start != null && end != null && !end!.isAtSameMomentAs(start!)) {
      final sameDay = start!.year == end!.year &&
          start!.month == end!.month &&
          start!.day == end!.day;
      if (sameDay) {
        return '${dfDate.format(start!)} • ${dfTime.format(start!)} - ${dfTime.format(end!)}';
      }
      return '${dfDate.format(start!)} - ${dfDate.format(end!)}';
    }
    if (start != null) {
      return '${dfDate.format(start!)} • ${dfTime.format(start!)}';
    }
    // Only end present (rare)
    return '${dfDate.format(end!)} • ${dfTime.format(end!)}';
  }
}

class _StatusSpec {
  const _StatusSpec({
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
  });

  final String label;
  final Color fg;
  final Color bg;
  final Color border;
}
