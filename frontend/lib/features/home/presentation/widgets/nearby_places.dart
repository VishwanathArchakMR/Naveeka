// lib/features/home/presentation/widgets/nearby_places.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/place.dart';
import '../../../../navigation/route_names.dart';

class NearbyPlacesSection extends StatelessWidget {
  final List<Place> places;
  const NearbyPlacesSection({
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
                'Nearby Places',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (places.isNotEmpty)
                TextButton(
                  onPressed: () {
                    context.pushNamed(
                      RouteNames.atlas,
                      queryParameters: {'nearby': 'true'},
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
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                return _NearbyPlaceCard(
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
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable location to discover nearby places',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyPlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;
  const _NearbyPlaceCard({
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Place image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    SizedBox(
                      width: 160,
                      height: 120,
                      child: place.images.isNotEmpty
                          ? Image.asset(
                              place.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Theme.of(context).colorScheme.surfaceContainer,
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Theme.of(context).colorScheme.surfaceContainer,
                              child: Icon(
                                Icons.place_outlined,
                                size: 32,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                    ),
                    // Emotion category badge
                    if (place.emotions.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            place.emotions.first.emoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    // Distance badge
                    if (place.distanceText.isNotEmpty)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Place name
              Text(
                place.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Category and rating
              Row(
                children: [
                  Text(
                    place.categoryLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (place.rating > 0) ...[
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Colors.amber[600],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      place.formattedRating,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              // Open/closed status
              if (place.timings != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    place.isOpenNow ? 'Open now' : 'Closed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: place.isOpenNow ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
