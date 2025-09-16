// lib/features/checkout/presentation/checkout_screen.dart

import 'package:flutter/material.dart';

import '../../../core/config/constants.dart';
import 'widgets/checkout_flow.dart';
import 'widgets/order_summary.dart';
import 'widgets/confirmation.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, this.bookingData});

  /// Booking payload passed via go_router extra (Map<String, dynamic>).
  /// Example shape: { title, date, ref, total, currencyCode, currencySymbol }.
  final Map<String, dynamic>? bookingData;

  @override
  Widget build(BuildContext context) {
    final currencyCode = (bookingData?['currencyCode'] as String?) ?? 'INR';
    final currencySymbol = (bookingData?['currencySymbol'] as String?) ?? '₹';
    final locale = (bookingData?['locale'] as String?) ?? 'en_IN';

    // Build line items for OrderSummary if data present
    final items = <OrderLine>[
      if (bookingData != null && bookingData!['title'] != null)
        OrderLine(label: bookingData!['title'].toString(), amount: (bookingData!['total'] as num?)?.toDouble() ?? 0),
      // Example of additional computed lines (can be customized per booking type)
      // OrderLine(label: 'Taxes & fees', amount: 0, isTaxOrFee: true),
      // OrderLine(label: 'Promo discount', amount: -0.0),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.padding),
          children: [
            // Optional order summary header (only if bookingData provided)
            if (bookingData != null) ...[
              OrderSummary(
                currencyLocale: locale,
                currencyName: currencyCode,
                currencySymbol: currencySymbol,
                items: items,
                collapsedByDefault: false,
                title: 'Order summary',
              ),
              const SizedBox(height: 8),
            ],

            // Main checkout flow; onCompleted shows ConfirmationCard and can navigate to My Bookings
            _CheckoutFlowContainer(
              bookingData: bookingData,
              onNavigateToBookings: () {
                // Replace with router navigation to '/journey/my-bookings' or equivalent.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening bookings...')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutFlowContainer extends StatefulWidget {
  const _CheckoutFlowContainer({
    required this.bookingData,
    required this.onNavigateToBookings,
  });

  final Map<String, dynamic>? bookingData;
  final VoidCallback onNavigateToBookings;

  @override
  State<_CheckoutFlowContainer> createState() => _CheckoutFlowContainerState();
}

class _CheckoutFlowContainerState extends State<_CheckoutFlowContainer> {
  Map<String, dynamic>? _finalOrder;

  @override
  Widget build(BuildContext context) {
    // If flow has completed, show a confirmation card; else render the flow.
    if (_finalOrder != null) {
      return ConfirmationCard(
        order: _finalOrder!,
        onViewBookings: widget.onNavigateToBookings,
        onDone: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You can close the app bar to exit')),
            );
          }
        },
      );
    }

    return CheckoutFlow(
      bookingData: widget.bookingData,
      onCompleted: (finalOrder) {
        setState(() => _finalOrder = finalOrder);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checkout complete')),
        );
      },
    );
  }
}
