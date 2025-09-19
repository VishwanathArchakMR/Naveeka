// lib/features/places/presentation/widgets/place_card.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../ui/theme/theme.dart';
import '../../../../ui/components/glass_card.dart';
import 'distance_indicator.dart';

class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    this.onToggleWishlist,
    this.originLat,
    this.originLng,
    this.heroPrefix = 'place-hero',
  });

  final Map<String, dynamic> place;
  final VoidCallback? onToggleWishlist;

  /// Optional origin for distance row. If both origin and place lat/lng exist,
  /// a compact DistanceIndicator will be shown.
  final double? originLat;
  final double? originLng;

  /// Matches PlaceHeaderSliver/PhotoGallery hero tags for smooth transitions.
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final placeId = (place['_id'] ?? place['id'])?.toString() ?? '';
    final image = (place['coverImage'] ?? (place['photos'] is List && (place['photos'] as List).isNotEmpty ? place['photos'] : null))?.toString();
    final approved = (place['isApproved'] == true);
    final wishlisted = (place['isWishlisted'] == true);

    final name = (place['name'] ?? '').toString().trim();
    final category = (place['category'] ?? '').toString().trim();
    final emotion = (place['emotion'] ?? '').toString().trim();
    final rating = _toDouble(place['rating']);
    final reviews = _toInt(place['reviewsCount']);

    final lat = _toDouble(place['lat']);
    final lng = _toDouble(place['lng']);
    final canShowDistance = originLat != null && originLng != null && lat != null && lng != null;

    // Emotion theme for gradients/badges
    final EmotionKind emotionKind = EmotionKind.values.firstWhere(
      (e) => emotion.isNotEmpty && emotion.toLowerCase() == e.name.toLowerCase().replaceAll('_', ' '),
      orElse: () => EmotionKind.peaceful,
    );
    final theme = EmotionTheme.of(emotionKind);

    return GlassCard(
      onTap: placeId.isEmpty ? null : () => context.go('/places/$placeId'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image with Hero and overlays
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: image == null || image.isEmpty
                      ? Container(color: Colors.white12)
                      : Hero(
                          tag: '$heroPrefix-$placeId',
                          child: CachedNetworkImage(
                            imageUrl: image,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.white12,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, color: Colors.white38),
                            ),
                          ),
                        ),
                ),
              ),

              // Approved badge
              if (approved)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: theme.gradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Approved',
                      style: TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

              // Wishlist icon
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onToggleWishlist,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        wishlisted ? Icons.favorite : Icons.favorite_border,
                        color: wishlisted ? Colors.pinkAccent : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Text & meta
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),

                  // Category · Emotion
                  Text(
                    [
                      if (category.isNotEmpty) category,
                      if (emotion.isNotEmpty) emotion,
                    ].join(' · '),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Rating + Distance row
                  Row(
                    children: [
                      if (rating != null) _RatingPill(rating: rating, reviews: reviews),
                      if (rating != null && canShowDistance) const SizedBox(width: 8),
                      if (canShowDistance)
                        DistanceIndicator(
                          targetLat: lat,
                          targetLng: lng,
                          originLat: originLat,
                          originLng: originLng,
                          compact: true,
                          labelSuffix: 'away',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ); // Card-like presentation with rounded media, content, and actions follows Material Card patterns for compact, tappable summaries. [1]
  }

  double? _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
    }
  int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({this.rating, this.reviews});
  final double? rating;
  final int? reviews;

  @override
  Widget build(BuildContext context) {
    if (rating == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            reviews == null || reviews == 0
                ? rating!.toStringAsFixed(1)
                : '${rating!.toStringAsFixed(1)} · $reviews',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

