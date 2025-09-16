// lib/features/journey/presentation/bookings/widgets/booking_details.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:url_launcher/url_launcher.dart'; // mailto:, tel:

enum BookingType { activity, hotel, flight, train, bus, cab, restaurant, generic }
enum BookingStatus { pending, confirmed, completed, cancelled, failed, refunded }

class BookingDetails extends StatelessWidget {
  const BookingDetails({
    super.key,
    required this.booking,
    this.type = BookingType.generic,
    this.status = BookingStatus.confirmed,
    this.supportEmail,
    this.supportPhone,
    this.onCancel,
    this.onViewInvoice,
  });

  /// Normalized booking payload (keys are optional and safely handled):
  /// {
  ///   id, reference, title, subtitle, amount, currency,
  ///   start (ISO), end (ISO), traveler: {...}, payment: {...},
  ///   location: { name, address, lat, lng }, notes
  /// }
  final Map<String, dynamic> booking;

  final BookingType type;
  final BookingStatus status;

  /// Optional support contacts
  final String? supportEmail;
  final String? supportPhone;

  /// Optional action callbacks
  final VoidCallback? onCancel;
  final VoidCallback? onViewInvoice;

  @override
  Widget build(BuildContext context) {
    final title = (booking['title'] ?? 'Booking').toString();
    final subtitle = (booking['subtitle'] ?? '').toString();
    final reference = (booking['reference'] ?? booking['ref'] ?? '').toString();
    final amount = _toNum(booking['amount']);
    final currency = (booking['currency'] ?? '₹').toString();

    final start = _parseDateTime(booking['start']);
    final end = _parseDateTime(booking['end']);

    final statusSpec = _statusSpec(context, status);

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(type)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ),
            ],
            const SizedBox(height: 10),

            // Ref + copy, amount
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          reference.isEmpty ? '-' : 'Ref: $reference',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                      if (reference.isNotEmpty)
                        IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () => _copyRef(context, reference),
                        ),
                    ],
                  ),
                ),
                if (amount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatCurrency(amount, currency),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Dates
            Row(
              children: [
                const Icon(Icons.event, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDateRange(start, end),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Sections
            _travelerTile(context),
            _paymentTile(context),
            _locationTile(context),
            _notesTile(context),

            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                if (onViewInvoice != null)
                  OutlinedButton.icon(
                    onPressed: onViewInvoice,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Invoice'),
                  ),
                if (onCancel != null && _canCancel(status)) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                  ),
                ],
                const Spacer(),
                if (supportEmail != null)
                  IconButton(
                    tooltip: 'Email support',
                    onPressed: () => _email(supportEmail!),
                    icon: const Icon(Icons.mail_outline),
                  ),
                if (supportPhone != null)
                  IconButton(
                    tooltip: 'Call support',
                    onPressed: () => _tel(supportPhone!),
                    icon: const Icon(Icons.call_outlined),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Sections ----

  Widget _travelerTile(BuildContext context) {
    final traveler = (booking['traveler'] as Map?) ?? const <String, dynamic>{};
    final name = (traveler['name'] ?? '').toString();
    final email = (traveler['email'] ?? '').toString();
    final phone = (traveler['phone'] ?? '').toString();

    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.person_outline),
      title: const Text('Traveler'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        _kv('Name', name),
        if (email.isNotEmpty) _kv('Email', email),
        if (phone.isNotEmpty) _kv('Phone', phone),
      ],
    );
  }

  Widget _paymentTile(BuildContext context) {
    final payment = (booking['payment'] as Map?) ?? const <String, dynamic>{};
    final method = (payment['method'] ?? '').toString().toUpperCase();
    final masked = (payment['masked'] ?? '').toString();
    final statusText = (payment['status'] ?? '').toString();

    return ExpansionTile(
      leading: const Icon(Icons.credit_card),
      title: const Text('Payment'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        _kv('Method', method.isEmpty ? '-' : method),
        if (masked.isNotEmpty) _kv('Card/UPI', masked),
        if (statusText.isNotEmpty) _kv('Status', statusText),
      ],
    );
  }

  Widget _locationTile(BuildContext context) {
    final location = (booking['location'] as Map?) ?? const <String, dynamic>{};
    final name = (location['name'] ?? '').toString();
    final address = (location['address'] ?? '').toString();
    final lat = _toDouble(location['lat']);
    final lng = _toDouble(location['lng']);

    return ExpansionTile(
      leading: const Icon(Icons.place_outlined),
      title: const Text('Location'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (name.isNotEmpty) _kv('Place', name),
        if (address.isNotEmpty) _kv('Address', address),
        if (lat != null && lng != null) _kv('Coordinates', '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'),
        if (lat != null && lng != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openMaps(lat, lng),
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Open in Maps'),
            ),
          ),
      ],
    );
  }

  Widget _notesTile(BuildContext context) {
    final notes = (booking['notes'] ?? '').toString();
    if (notes.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      leading: const Icon(Icons.note_outlined),
      title: const Text('Notes'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            notes,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }

  // ---- Helpers ----

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  bool _canCancel(BookingStatus s) {
    return s == BookingStatus.pending || s == BookingStatus.confirmed;
  }

  Future<void> _copyRef(BuildContext context, String ref) async {
    await Clipboard.setData(ClipboardData(text: ref));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied')));
    }
  }

  Future<void> _email(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _tel(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatCurrency(num amount, String currency) {
    final fmt = NumberFormat.currency(symbol: currency, decimalDigits: 0);
    return fmt.format(amount);
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    final dfDate = DateFormat.yMMMEd();
    final dfTime = DateFormat.jm();
    if (start == null && end == null) return '-';
    if (start != null && end != null && !end.isAtSameMomentAs(start)) {
      final sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
      if (sameDay) {
        return '${dfDate.format(start)} • ${dfTime.format(start)} - ${dfTime.format(end)}';
      }
      return '${dfDate.format(start)} - ${dfDate.format(end)}';
    }
    final d = start ?? end!;
    return '${dfDate.format(d)} • ${dfTime.format(d)}';
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

  DateTime? _parseDateTime(dynamic v) {
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      return DateTime.tryParse(v);
    }
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  num? _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
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
