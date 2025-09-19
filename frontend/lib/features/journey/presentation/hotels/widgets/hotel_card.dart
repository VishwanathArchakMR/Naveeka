// lib/features/journey/presentation/hotels/widgets/hotel_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HotelCard extends StatelessWidget {
  const HotelCard({
    super.key,
    required this.id,
    required this.name,
    this.city,
    this.area,
    this.imageUrl,
    this.rating,
    this.reviewCount,
    this.pricePerNight,
    this.currency = '₹',
    this.distanceKm,
    this.freeCancellation = false,
    this.payAtHotel = false,
    this.amenities = const <String>[], // ["WiFi","Breakfast","Pool"]
    this.onTap,
    this.onViewRooms,
  });

  final String id;
  final String name;
  final String? city;
  final String? area;

  final String? imageUrl;

  final double? rating;
  final int? reviewCount;

  final num? pricePerNight;
  final String currency;

  final double? distanceKm;

  final bool freeCancellation;
  final bool payAtHotel;

  final List<String> amenities;

  final VoidCallback? onTap;
  final VoidCallback? onViewRooms;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = _buildLocation();
    final price = _formatCurrency(pricePerNight, currency);

    return Card(
      clipBehavior: Clip.antiAlias, // ensures ripple and image clip to rounded card shape [1]
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap ?? onViewRooms,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            _CoverImage(imageUrl: imageUrl),
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
                          name,
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
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 16, color: Colors.black54),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Rating + distance
                  Row(
                    children: [
                      if (rating != null) ...[
                        const Icon(Icons.star_rate_rounded, size: 18, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          rating!.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (reviewCount != null) ...[
                          const SizedBox(width: 6),
                          Text('($reviewCount)', style: const TextStyle(color: Colors.black54)),
                        ],
                      ],
                      const Spacer(),
                      if (distanceKm != null)
                        Row(
                          children: [
                            const Icon(Icons.directions_walk, size: 16, color: Colors.black54),
                            const SizedBox(width: 4),
                            Text('${distanceKm!.toStringAsFixed(distanceKm! < 10 ? 1 : 0)} km'),
                          ],
                        ),
                    ],
                  ),

                  // Badges
                  if (freeCancellation || payAtHotel) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (freeCancellation)
                          _Badge(
                            label: 'Free cancellation',
                            color: Colors.green.withValues(alpha: 0.12),
                            textColor: Colors.green.shade700,
                          ),
                        if (payAtHotel)
                          _Badge(
                            label: 'Pay at hotel',
                            color: theme.colorScheme.secondaryContainer,
                            textColor: theme.colorScheme.onSecondaryContainer,
                          ),
                      ],
                    ),
                  ],

                  // Amenities
                  if (amenities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: amenities.take(4).map((a) {
                        return _Badge(
                          label: a,
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: Colors.black87,
                        );
                      }).toList(growable: false),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // CTA
                  Row(
                    children: [
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: onViewRooms ?? onTap,
                        icon: const Icon(Icons.meeting_room_outlined),
                        label: const Text('View rooms'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildLocation() {
    final parts = <String>[];
    if (area != null && area!.trim().isNotEmpty) parts.add(area!.trim());
    if (city != null && city!.trim().isNotEmpty) parts.add(city!.trim());
    return parts.join(' • ');
  }

  String? _formatCurrency(num? v, String currency) {
    if (v == null) return null;
    final fmt = NumberFormat.currency(symbol: currency, decimalDigits: 0); // localized currency formatting [7][13]
    return fmt.format(v);
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const ratio = 16 / 9.0;
    return AspectRatio(
      aspectRatio: ratio,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return const _ImageFallback();
              },
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return const _ImageShimmer();
              },
            )
          : const _ImageFallback(),
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
