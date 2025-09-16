// lib/features/atlas/presentation/widgets/list_view.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/place.dart';
import '../../../../navigation/route_names.dart';
import '../../../../services/location_service.dart';

class AtlasListView extends StatelessWidget {
  final List<Place> places;
  final Function(Place) onPlaceTap;
  final ScrollController? scrollController;

  const AtlasListView({
    super.key,
    required this.places,
    required this.onPlaceTap,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: places.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final place = places[index];
        return _PlaceListCard(
          place: place,
          onTap: () => onPlaceTap(place),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No places found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or location filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceListCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const _PlaceListCard({
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Place image
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  place.images.isNotEmpty
                      ? Image.asset(
                          place.images.first,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => _buildImageFallback(context),
                        )
                      : _buildImageFallback(context),
                  
                  // Emotion badge
                  if (place.emotions.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          place.distanceText,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Place details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and verification
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (place.isVerified)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Category and emotions
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            place.categoryLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (place.emotions.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            place.emotionEmojis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Rating and reviews
                    if (place.rating > 0)
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            place.formattedRating,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (place.reviewCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${place.reviewCount} reviews)',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),

                    const SizedBox(height: 8),

                    // Address
                    if (place.location.address.toString().isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place.location.address.toString(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 8),

                    // Status and price row
                    Row(
                      children: [
                        // Open/closed status
                        if (place.timings != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: place.isOpenNow 
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: place.isOpenNow ? Colors.green : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              place.isOpenNow ? 'Open now' : 'Closed',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: place.isOpenNow ? Colors.green[700] : Colors.red[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                            ),
                          ),

                        const Spacer(),

                        // Price
                        if (place.pricing != null)
                          Text(
                            place.isFree 
                                ? 'Free' 
                                : '₹${place.pricing!.entryFee?.toStringAsFixed(0) ?? '--'}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFallback(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Icon(
        _getCategoryIcon(place.category),
        size: 32,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );
  }

  IconData _getCategoryIcon(PlaceCategory category) {
    switch (category) {
      case PlaceCategory.temple:
        return Icons.temple_buddhist_outlined;
      case PlaceCategory.monument:
        return Icons.account_balance_outlined;
      case PlaceCategory.museum:
        return Icons.museum_outlined;
      case PlaceCategory.park:
        return Icons.park_outlined;
      case PlaceCategory.beach:
        return Icons.beach_access_outlined;
      case PlaceCategory.mountain:
        return Icons.terrain_outlined;
      case PlaceCategory.lake:
        return Icons.water_outlined;
      case PlaceCategory.hotel:
        return Icons.hotel_outlined;
      case PlaceCategory.restaurant:
        return Icons.restaurant_outlined;
      case PlaceCategory.cafe:
        return Icons.local_cafe_outlined;
      case PlaceCategory.activity:
        return Icons.local_activity_outlined;
      case PlaceCategory.tour:
        return Icons.tour_outlined;
      case PlaceCategory.transport:
        return Icons.directions_bus_outlined;
      case PlaceCategory.shopping:
        return Icons.shopping_bag_outlined;
      case PlaceCategory.entertainment:
        return Icons.local_movies_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}
