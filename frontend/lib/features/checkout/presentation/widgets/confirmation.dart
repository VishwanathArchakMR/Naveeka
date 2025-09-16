// lib/features/checkout/presentation/widgets/confirmation.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard [11]

import '../../../../core/config/constants.dart';

/// A reusable confirmation card after successful checkout/payment. [10]
class ConfirmationCard extends StatelessWidget {
  const ConfirmationCard({
    super.key,
    required this.order,
    this.onViewBookings,
    this.onDone,
  });

  /// Finalized order map:
  /// {
  ///   booking: { ref, title, date, total },
  ///   traveler: { name, email, phone },
  ///   payment: { method, ... },
  ///   createdAt: ISO string
  /// }
  final Map<String, dynamic> order;

  /// Optional navigation to the "My Bookings" screen.
  final VoidCallback? onViewBookings;

  /// Optional completion callback (e.g., pop to home).
  final VoidCallback? onDone;

  String? get _ref {
    final booking = order['booking'];
    if (booking is Map && booking['ref'] != null) {
      return booking['ref']?.toString();
    }
    return order['reference']?.toString();
  }

  String get _title {
    final booking = order['booking'];
    return (booking is Map ? booking['title']?.toString() : null) ?? 'Booking';
  }

  double? get _total {
    final booking = order['booking'];
    final n = (booking is Map ? booking['total'] : null);
    if (n is num) return n.toDouble();
    return null;
    }

  String? get _date {
    final booking = order['booking'];
    return (booking is Map ? booking['date']?.toString() : null) ??
        order['createdAt']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final ref = _ref;

    return Card(
      margin: const EdgeInsets.all(AppConstants.padding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12), // wide-gamut safe
                borderRadius: BorderRadius.circular(44),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 56),
            ),
            const SizedBox(height: 12),
            const Text(
              'Booking confirmed!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              ref == null ? 'Your order is complete.' : 'Reference: $ref',
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'A confirmation has been sent to your email.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Summary block
            _SummaryTile(label: 'Item', value: _title),
            if (_date != null) _SummaryTile(label: 'Date', value: _date!),
            _SummaryTile(
              label: 'Total',
              value: total == null ? '-' : '₹${total.toStringAsFixed(2)}',
              bold: true,
            ),

            const SizedBox(height: 16),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: ref == null ? null : () => _copyRef(context, ref),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy reference'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onViewBookings,
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('View bookings'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onDone,
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyRef(BuildContext context, String ref) async {
    await Clipboard.setData(ClipboardData(text: ref)); // Clipboard API
    // Show feedback with ScaffoldMessenger (modern snackbar flow)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reference copied to clipboard')),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final valueStyle = bold
        ? const TextStyle(fontWeight: FontWeight.bold)
        : const TextStyle(fontWeight: FontWeight.w500);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value, style: valueStyle)),
        ],
      ),
    );
  }
}
