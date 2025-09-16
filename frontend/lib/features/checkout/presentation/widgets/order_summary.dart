// lib/features/checkout/presentation/widgets/order_summary.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // currency formatting [3]

import '../../../../core/config/constants.dart';

/// Data model for a summary line item.
class OrderLine {
  final String label;        // e.g., "Flight base fare"
  final double amount;       // positive for charges, negative for discounts
  final bool isTaxOrFee;     // true for taxes/fees to group visually
  final bool emphasize;      // bold row

  const OrderLine({
    required this.label,
    required this.amount,
    this.isTaxOrFee = false,
    this.emphasize = false,
  });
}

/// OrderSummary displays a breakdown of line items and grand total,
/// with optional expandable details section. [17]
class OrderSummary extends StatelessWidget {
  const OrderSummary({
    super.key,
    required this.currencyLocale,
    required this.currencyName,
    required this.currencySymbol,
    required this.items,
    this.collapsedByDefault = true,
    this.title = 'Order summary',
  });

  /// Locale for currency formatting, e.g., 'en_IN' for Indian grouping. [1]
  final String currencyLocale;

  /// ISO 4217 currency code, e.g., 'INR'. [5]
  final String currencyName;

  /// Currency symbol, e.g., '₹'. [5]
  final String currencySymbol;

  /// Line items that compose the order. Positive = charge, negative = discount. [17]
  final List<OrderLine> items;

  /// Whether the breakdown ExpansionTile is initially collapsed. [12]
  final bool collapsedByDefault;

  /// Section title.
  final String title;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: currencyLocale,
      name: currencyName,
      symbol: currencySymbol,
      decimalDigits: 2,
    ); // currency formatter with locale/symbol [5]

    final charges = items.where((e) => e.amount >= 0).toList(growable: false);
    final discounts = items.where((e) => e.amount < 0).toList(growable: false);
    final subtotal = charges.fold<double>(0, (p, e) => p + e.amount); // [17]
    final discountTotal = discounts.fold<double>(0, (p, e) => p + e.amount); // negative sum [17]
    final grandTotal = subtotal + discountTotal; // includes discounts [17]

    return Card(
      margin: const EdgeInsets.all(AppConstants.padding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ), // semantic section title [20]
            const SizedBox(height: 8),

            // Grand total row
            _row(
              label: 'Total',
              value: fmt.format(grandTotal),
              emphasize: true,
            ), // clear primary amount [5]
            const SizedBox(height: 8),
            const Divider(), // separates headline from breakdown [10]

            // Expandable details
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.black12),
              child: ExpansionTile(
                initiallyExpanded: !collapsedByDefault,
                title: const Text('Details'),
                childrenPadding: const EdgeInsets.only(
                  left: AppConstants.paddingXS,
                  right: AppConstants.paddingXS,
                  bottom: AppConstants.padding,
                ),
                children: [
                  // Charges
                  if (charges.isNotEmpty) ...[
                    _sectionLabel('Items'),
                    const SizedBox(height: 4),
                    ...charges.map((e) => _row(
                          label: e.label,
                          value: fmt.format(e.amount),
                          muted: e.isTaxOrFee,
                          emphasize: e.emphasize,
                        )),
                  ], // group items per Material list guidance [20]

                  if (discounts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _sectionLabel('Discounts'),
                    const SizedBox(height: 4),
                    ...discounts.map((e) => _row(
                          label: e.label,
                          value: fmt.format(e.amount),
                          isDiscount: true,
                          emphasize: e.emphasize,
                        )),
                  ], // show discounts as separate group [20]

                  const SizedBox(height: 8),
                  const Divider(), // divider within details [10]

                  // Subtotals
                  _row(
                    label: 'Subtotal',
                    value: fmt.format(subtotal),
                  ), // intermediate sum [5]
                  if (discounts.isNotEmpty)
                    _row(
                      label: 'Discounts',
                      value: fmt.format(discountTotal),
                      isDiscount: true,
                    ), // negative subtotal [5]
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Taxes and fees included where applicable.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ), // lightweight footnote [18]
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: Colors.black54),
    );
  }

  Widget _row({
    required String label,
    required String value,
    bool muted = false,
    bool emphasize = false,
    bool isDiscount = false,
  }) {
    final color = isDiscount ? Colors.green : (muted ? Colors.black54 : null);
    final weight = emphasize ? FontWeight.w700 : FontWeight.w500;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: muted ? Colors.black54 : null,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: weight,
            ),
          ),
        ],
      ),
    );
  }
}
