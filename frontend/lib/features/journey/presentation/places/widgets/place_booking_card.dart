// lib/features/journey/presentation/places/widgets/place_booking_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PlaceBookingCard extends StatelessWidget {
  const PlaceBookingCard({
    super.key,
    required this.id,
    required this.title,
    this.category,
    this.city,
    this.imageUrl,
    this.rating,
    this.reviewCount,
    this.priceFrom,
    this.currency = '₹',
    this.durationMinutes,
    this.nextSlot, // DateTime or ISO string
    this.freeCancellation = false,
    this.instantConfirmation = false,
    this.distanceKm,
    this.onTap,
    this.onBook,
  });

  final String id;
  final String title;
  final String? category;
  final String? city;

  final String? imageUrl;

  final double? rating;
  final int? reviewCount;

  final num? priceFrom;
  final String currency;

  final int? durationMinutes;
  final dynamic nextSlot;

  final bool freeCancellation;
  final bool instantConfirmation;

  final double? distanceKm;

  final VoidCallback? onTap;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = _buildLocation();
    final price = _formatCurrency(priceFrom, currency);
    final slot = _formatNextSlot(nextSlot);

    return Card(
      clipBehavior: Clip.antiAlias, // clip ripple and image to rounded card shape for proper Material ink [1]
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap ?? onBook,
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
                  // Title + price
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      if (price != null)
                        Text(
                          price,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                    ],
                  ),
                  if (category != null || city != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            loc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Meta row: duration • next slot • distance
                  Row(
                    children: [
                      if (durationMinutes != null) ...[
                        const Icon(Icons.timer_outlined, size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(_durationText(durationMinutes!), style: const TextStyle(color: Colors.black54)),
                        const SizedBox(width: 10),
                      ],
                      if (slot != null) ...[
                        const Icon(Icons.event_available_outlined, size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text(slot, style: const TextStyle(color: Colors.black54)),
                        const SizedBox(width: 10),
                      ],
                      if (distanceKm != null) ...[
                        const Icon(Icons.directions_walk, size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        Text('${distanceKm! < 10 ? distanceKm!.toStringAsFixed(1) : distanceKm!.toStringAsFixed(0)} km',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ],
                  ),

                  // Policy badges
                  if (freeCancellation || instantConfirmation) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (instantConfirmation)
                          _Badge(
                            label: 'Instant confirmation',
                            color: theme.colorScheme.primaryContainer,
                            textColor: theme.colorScheme.onPrimaryContainer,
                          ),
                        if (freeCancellation)
                          _Badge(
                            label: 'Free cancellation',
                            color: Colors.green.withValues(alpha: 0.12),
                            textColor: Colors.green.shade700,
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // CTA
                  Row(
                    children: [
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: onBook ?? onTap,
                        icon: const Icon(Icons.event_seat_outlined),
                        label: const Text('Book'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // InkWell inside Card provides Material ripple and tap handling per InkWell guidance [12]
    );
  }

  String _buildLocation() {
    final parts = <String>[];
    if (category != null && category!.trim().isNotEmpty) parts.add(category!.trim());
    if (city != null && city!.trim().isNotEmpty) parts.add(city!.trim());
    return parts.join(' • ');
  }

  String? _formatCurrency(num? v, String currency) {
    if (v == null) return null;
    // Zero decimals fit typical ticket/experience price display; override in caller if needed.
    return NumberFormat.currency(symbol: currency, decimalDigits: 0).format(v); // Localized currency formatting via intl [7]
  }

  String _durationText(int minutes) {
    if (minutes <= 0) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String? _formatNextSlot(dynamic v) {
    DateTime? dt;
    if (v == null) return null;
    if (v is DateTime) dt = v;
    if (v is String && v.isNotEmpty) dt = DateTime.tryParse(v);
    if (dt == null) return null;
    final d1 = DateFormat.MMMd().format(dt);
    final t1 = DateFormat.Hm().format(dt);
    return '$d1 • $t1';
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({this.imageUrl, this.rating, this.reviewCount});

  final String? imageUrl;
  final double? rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    const ratio = 16 / 9.0;
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
                        '($reviewCount)',
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
