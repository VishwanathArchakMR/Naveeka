// lib/features/journey/presentation/restaurants/widgets/restaurant_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.id,
    required this.name,
    this.imageUrl,
    this.cuisines = const <String>[],
    this.rating,
    this.reviewCount,
    this.priceLevel, // 1..4 for ₹..₹₹₹₹ (or $..$$$$)
    this.costForTwo, // num
    this.currency = '₹',
    this.distanceKm,
    this.isOpen,
    this.tags = const <String>[], // e.g., ['Veg only','Delivery','Outdoor seating']
    this.onTap,
    this.onPrimaryAction, // e.g., view menu / reserve
    this.primaryLabel = 'View menu',
  });

  final String id;
  final String name;
  final String? imageUrl;

  final List<String> cuisines;

  final double? rating;
  final int? reviewCount;

  final int? priceLevel;
  final num? costForTwo;
  final String currency;

  final double? distanceKm;

  final bool? isOpen;

  final List<String> tags;

  final VoidCallback? onTap;
  final VoidCallback? onPrimaryAction;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = _buildSubtitle();
    final priceText = _buildPriceText();
    final statusChip = _buildStatusChip();

    return Card(
      clipBehavior: Clip.antiAlias, // clip image and ripple to the rounded card shape per Card guidance [1]
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap ?? onPrimaryAction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverImage(
              imageUrl: imageUrl,
              rating: rating,
              reviewCount: reviewCount,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + action
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      FilledButton(
                        onPressed: onPrimaryAction ?? onTap,
                        child: Text(primaryLabel),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                  ],
                  const SizedBox(height: 6),
                  // Meta row: price / cost for two • distance • status
                  Row(
                    children: [
                      if (priceText != null) ...[
                        const Icon(Icons.currency_rupee, size: 16, color: Colors.black54),
                        const SizedBox(width: 2),
                        Text(priceText, style: const TextStyle(color: Colors.black54)),
                        const SizedBox(width: 10),
                      ],
                      if (distanceKm != null) ...[
                        const Icon(Icons.place_outlined, size: 16, color: Colors.black54),
                        const SizedBox(width: 2),
                        Text('${distanceKm! < 10 ? distanceKm!.toStringAsFixed(1) : distanceKm!.toStringAsFixed(0)} km', style: const TextStyle(color: Colors.black54)),
                      ],
                      const Spacer(),
                      if (statusChip != null) statusChip,
                    ],
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.take(4).map((t) {
                        return _Badge(
                          label: t,
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: Colors.black87,
                        );
                      }).toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ), // InkWell gives proper Material ripple on tap inside a Card per InkWell usage guidance [12]
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (cuisines.isNotEmpty) parts.add(cuisines.take(3).join(', '));
    if (rating != null) {
      final r = rating!.toStringAsFixed(1);
      final rev = reviewCount != null ? ' ($reviewCount)' : '';
      parts.add('★ $r$rev');
    }
    return parts.join(' • ');
  }

  String? _buildPriceText() {
    // Prefer a symbolic price level if provided; else show localized cost for two.
    if (priceLevel != null && priceLevel! > 0) {
      return List.filled(priceLevel!.clamp(1, 5), currency).join();
    }
    if (costForTwo != null) {
      // Localized currency formatting using intl NumberFormat.currency [7]
      final fmt = NumberFormat.currency(symbol: currency, decimalDigits: 0);
      return 'for two ${fmt.format(costForTwo)}';
    }
    return null;
  }

  Widget? _buildStatusChip() {
    if (isOpen == null) return null;
    return _Badge(
      label: isOpen! ? 'Open now' : 'Closed',
      color: isOpen! ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
      textColor: isOpen! ? Colors.green.shade700 : Colors.red.shade700,
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({this.imageUrl, this.rating, this.reviewCount});

  final String? imageUrl;
  final double? rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    final ratio = 16 / 9.0;
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        children: [
          Positioned.fill(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImageFallback(),
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const _ImageShimmer();
                    },
                  )
                : const _ImageFallback(),
          ),
          if (rating != null)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rate_rounded, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    if (reviewCount != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${reviewCount})',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.image_not_supported_outlined, color: Colors.black45),
          SizedBox(width: 6),
          Text('No image', style: TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }
}

class _ImageShimmer extends StatelessWidget {
  const _ImageShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.textColor});
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
    );
  }
}
