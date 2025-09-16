// lib/features/journey/presentation/activities/widgets/activity_card.dart

import 'package:flutter/material.dart';

import '../../../../../features/home/presentation/widgets/distance_indicator.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.id,
    required this.title,
    this.imageUrl,
    this.rating,
    this.ratingCount,
    this.priceFrom,
    this.currency = '₹',
    this.durationLabel,
    this.locationLabel,
    this.lat,
    this.lng,
    this.heroTag, // if not provided, defaults to 'activity_<id>'
    this.isFavorite = false,
    this.onTap,
    this.onToggleFavorite,
  });

  final String id;
  final String title;
  final String? imageUrl;
  final double? rating; // 0..5
  final int? ratingCount;
  final num? priceFrom; // lowest price
  final String currency;
  final String? durationLabel; // e.g., "2h 30m"
  final String? locationLabel; // e.g., "Munnar, Kerala"
  final double? lat;
  final double? lng;
  final String? heroTag;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final tag = heroTag ?? 'activity_$id';

    return Card(
      clipBehavior: Clip.antiAlias, // ensures ripple & image clip follow the card shape [11]
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        // InkWell + Material ancestor ensures visible ripple per Material guidelines [2][3]
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroImage(
              tag: tag,
              imageUrl: imageUrl,
              overlay: _TopBar(
                isFavorite: isFavorite,
                onToggleFavorite: onToggleFavorite,
              ),
              bottom: _ImageBottomOverlay(title: title),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: _InfoRow(
                rating: rating,
                ratingCount: ratingCount,
                durationLabel: durationLabel,
                priceFrom: priceFrom,
                currency: currency,
                locationLabel: locationLabel,
                lat: lat,
                lng: lng,
                id: id,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.tag,
    required this.imageUrl,
    required this.overlay,
    required this.bottom,
  });

  final String tag;
  final String? imageUrl;
  final Widget overlay;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    // Hero enables shared element transitions between list and details [9][15]
    return Hero(
      tag: tag,
      child: Stack(
        children: [
          // Use Ink.image so the ripple paints above the image within a Material ancestor [2][3]
          if (hasImage)
            Ink.image(
              image: NetworkImage(imageUrl!),
              height: 160,
              fit: BoxFit.cover,
            )
          else
            Container(
              height: 160,
              color: Theme.of(context).colorScheme.surfaceVariant,
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported_outlined, size: 28, color: Colors.black45),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Colors.black26,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black38,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: overlay,
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: bottom,
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isFavorite, required this.onToggleFavorite});

  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(20),
      child: IconButton(
        onPressed: onToggleFavorite,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          fixedSize: const Size(36, 36),
          foregroundColor: Colors.white,
        ),
        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
        tooltip: isFavorite ? 'Saved' : 'Save',
      ),
    );
  }
}

class _ImageBottomOverlay extends StatelessWidget {
  const _ImageBottomOverlay({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          height: 1.2,
        );
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.rating,
    required this.ratingCount,
    required this.durationLabel,
    required this.priceFrom,
    required this.currency,
    required this.locationLabel,
    required this.lat,
    required this.lng,
    required this.id,
  });

  final double? rating;
  final int? ratingCount;
  final String? durationLabel;
  final num? priceFrom;
  final String currency;
  final String? locationLabel;
  final double? lat;
  final double? lng;
  final String id;

  @override
  Widget build(BuildContext context) {
    final hasDistance = lat != null && lng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row: rating + duration + price
        Row(
          children: [
            if (rating != null) ...[
              const Icon(Icons.star_rate_rounded, size: 18, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                rating!.toStringAsFixed(1) + (ratingCount != null ? ' (${ratingCount})' : ''),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (rating != null && durationLabel != null) const SizedBox(width: 12),
            if (durationLabel != null) ...[
              const Icon(Icons.schedule, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(durationLabel!, style: const TextStyle(color: Colors.black54)),
            ],
            const Spacer(),
            if (priceFrom != null)
              Text(
                '$currency${priceFrom!.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Row: location + distance chip (if lat/lng present)
        Row(
          children: [
            if (locationLabel != null) ...[
              const Icon(Icons.place_outlined, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  locationLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ] else
              const Expanded(child: SizedBox()),
            if (hasDistance) ...[
              const SizedBox(width: 8),
              DistanceIndicator(
                targetLat: lat!,
                targetLng: lng!,
                cacheKey: 'activity/$id',
                compact: true,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
