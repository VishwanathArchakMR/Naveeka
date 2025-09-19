// lib/features/journey/presentation/cabs/widgets/cab_option_card.dart

import 'package:flutter/material.dart';

class CabOptionCard extends StatelessWidget {
  const CabOptionCard({
    super.key,
    required this.provider,
    required this.vehicle,
    this.price,
    this.currency = '₹',
    this.etaText,
    this.etaMinutes,
    this.surge = false,
    this.features = const <String>[], // e.g. ['AC','Top-rated']
    this.selected = false,
    this.onTap,
    this.onBook,
  });

  final String provider;
  final String vehicle;
  final double? price;
  final String currency;
  final String? etaText;
  final int? etaMinutes;
  final bool surge;
  final List<String> features;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = theme.colorScheme.secondaryContainer;
    final chipText = theme.colorScheme.onSecondaryContainer;

    return Card(
      clipBehavior: Clip.antiAlias, // clip ripple to rounded shape for correct Material splash [3]
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: selected ? 1.2 : 1.0,
        ),
      ),
      elevation: selected ? 2 : 0,
      child: InkWell(
        onTap: onTap ?? onBook,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                child: Text(
                  provider.isNotEmpty ? provider.toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),

              // Title + meta + chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$vehicle • $provider',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        if (price != null)
                          Text(
                            '$currency${price!.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // ETA / meta row
                    if (etaText != null || etaMinutes != null)
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            etaText ?? '$etaMinutes min',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),

                    // Chips
                    if (surge || features.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (surge)
                            Chip(
                              label: const Text('Surge'),
                              backgroundColor: Colors.orange.withValues(alpha: 0.15),
                              labelStyle: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700),
                              visualDensity: VisualDensity.compact,
                            ),
                          ...features.take(3).map((f) {
                            return Chip(
                              label: Text(f),
                              backgroundColor: chipColor,
                              labelStyle: TextStyle(color: chipText, fontWeight: FontWeight.w600),
                              visualDensity: VisualDensity.compact,
                            );
                          }),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // CTA
              FilledButton(
                onPressed: onBook ?? onTap,
                child: const Text('Book'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
