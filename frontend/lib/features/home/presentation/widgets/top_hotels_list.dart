// lib/features/home/presentation/widgets/top_hotels_list.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/place.dart';
import '../../../../navigation/route_names.dart';

class TopHotelsListSection extends StatelessWidget {
  final List<Place> hotels;

  const TopHotelsListSection({
    super.key,
    required this.hotels,
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
                'Top Hotels',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (hotels.isNotEmpty)
                TextButton(
                  onPressed: () {
                    context.pushNamed(
                      RouteNames.hotelSearch,
                      queryParameters: {'category': 'top-rated'},
                    );
                  },
                  child: const Text('See all'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (hotels.isEmpty)
          _buildEmptyState(context)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: hotels.take(5).map((hotel) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TopHotelCard(
                    hotel: hotel,
                    onTap: () {
                      context.pushNamed(
                        RouteNames.placeDetail,
                        pathParameters: {'id': hotel.id},
                      );
                    },
                  ),
                );
              }).toList(),
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
              Icons.hotel_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'No top hotels available',
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

class _TopHotelCard extends StatelessWidget {
  final Place hotel;
  final VoidCallback onTap;

  const _TopHotelCard({
    required this.hotel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Hotel image
            SizedBox(
              width: 120,
              height: 100,
              child: hotel.images.isNotEmpty
                  ? Image.asset(
                      hotel.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          child: Icon(
                            Icons.hotel_outlined,
                            size: 32,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: Icon(
                        Icons.hotel_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
            ),

            // Hotel details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hotel name and verification
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hotel.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hotel.isVerified)
                          Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Location
                    if (hotel.location.address.city?.isNotEmpty == true)
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
                              hotel.location.address.city!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hotel.distanceText.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              hotel.distanceText,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),

                    const SizedBox(height: 8),

                    // Rating and amenities
                    Row(
                      children: [
                        if (hotel.rating > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  hotel.formattedRating,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // Amenity icons
                        if (hotel.accessibility.hasWifi)
                          Icon(
                            Icons.wifi_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        if (hotel.accessibility.hasParking) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.local_parking_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ],
                        if (hotel.accessibility.hasRestrooms) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.restaurant_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ],

                        const Spacer(),

                        // Price
                        if (hotel.pricing != null && !hotel.isFree)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${hotel.pricing!.entryFee?.toStringAsFixed(0) ?? '--'}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '/night',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Features or tags
                    if (hotel.tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: hotel.tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
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
}
