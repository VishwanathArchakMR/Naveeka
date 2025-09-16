// lib/features/home/presentation/widgets/trending_places.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/place.dart';
import '../../../../navigation/route_names.dart';

class TrendingPlacesSection extends StatelessWidget {
  final List<Place> places;

  const TrendingPlacesSection({
    super.key,
    required this.places,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trending Places',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (places.isNotEmpty)
                TextButton(
                  onPressed: () {
                    context.pushNamed(
                      RouteNames.atlas,
                      queryParameters: {'trending': 'true'},
                    );
                  },
                  child: const Text('See all'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (places.isEmpty)
          _buildEmptyState(context)
        else
          SizedBox(
            height: 260,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                return _TrendingPlaceCard(
                  place: place,
                  onTap: () {
                    context.pushNamed(
                      RouteNames.placeDetail,
                      pathParameters: {'id': place.id},
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up_outlined,
              size: 32,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'No trending places available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingPlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const _TrendingPlaceCard({
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 220,
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with badges
                Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 140,
                      child: place.images.isNotEmpty
                          ? Image.asset(
                              place.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) {
                                return Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainer,
                                  child: Icon(
                                    Icons.place_outlined,
                                    size: 40,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainer,
                              child: Icon(
                                Icons.place_outlined,
                                size: 40,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                    ),
                    // Trending badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.trending_up_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'Trending',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Distance badge
                    if (place.distanceText.isNotEmpty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            place.distanceText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    // Emotion emoji
                    if (place.emotions.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            place.emotions.first.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        place.categoryLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (place.rating > 0) ...[
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              place.formattedRating,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (place.reviewCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${place.reviewCount})',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6)),
                              ),
                            ],
                          ],
                          const Spacer(),
                          if (place.isFeatured)
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (place.timings != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: place.isOpenNow
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                place.isOpenNow ? 'Open now' : 'Closed',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: place.isOpenNow
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 10),
                              ),
                            ),
                          const Spacer(),
                          if (place.pricing != null && !place.isFree)
                            Text(
                              place.isFree
                                  ? 'Free'
                                  : '₹${place.pricing!.entryFee?.toStringAsFixed(0) ?? '--'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
