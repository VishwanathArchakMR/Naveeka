// lib/features/home/presentation/widgets/nearby_hotels_restaurants.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/place.dart';
import '../../../../navigation/route_names.dart';

class NearbyHotelsRestaurantsSection extends StatelessWidget {
  final List<Place> hotels;
  final List<Place> restaurants;
  
  const NearbyHotelsRestaurantsSection({
    super.key,
    required this.hotels,
    required this.restaurants,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hotels Section
        if (hotels.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Nearby Hotels',
            onSeeAll: () {
              context.pushNamed(
                RouteNames.hotelSearch,
                queryParameters: {'nearby': 'true'},
              );
            },
          ),
          const SizedBox(height: 12),
          _buildHotelsList(),
          const SizedBox(height: 32),
        ],

        // Restaurants Section
        if (restaurants.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Nearby Restaurants',
            onSeeAll: () {
              context.pushNamed(
                RouteNames.restaurantSearch,
                queryParameters: {'nearby': 'true'},
              );
            },
          ),
          const SizedBox(height: 12),
          _buildRestaurantsList(),
        ],

        // Empty state if both are empty
        if (hotels.isEmpty && restaurants.isEmpty)
          _buildEmptyState(context),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required VoidCallback onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          TextButton(
            onPressed: onSeeAll,
            child: const Text('See all'),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelsList() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: hotels.length,
        itemBuilder: (context, index) {
          final hotel = hotels[index];
          return _HotelCard(
            place: hotel,
            onTap: () {
              context.pushNamed(
                RouteNames.placeDetail,
                pathParameters: {'id': hotel.id},
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRestaurantsList() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = restaurants[index];
          return _RestaurantCard(
            place: restaurant,
            onTap: () {
              context.pushNamed(
                RouteNames.placeDetail,
                pathParameters: {'id': restaurant.id},
              );
            },
          );
        },
      ),
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
              'No nearby hotels or restaurants found',
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

class _HotelCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const _HotelCard({
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
          width: 200,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hotel image
                SizedBox(
                  width: double.infinity,
                  height: 120,
                  child: place.images.isNotEmpty
                      ? Image.asset(
                          place.images.first,
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
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
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
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (place.distanceText.isNotEmpty)
                            Text(
                              place.distanceText,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                      if (place.pricing != null && !place.isFree)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '₹${place.pricing!.entryFee?.toStringAsFixed(0) ?? '--'}/night',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

class _RestaurantCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const _RestaurantCard({
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
          width: 180,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant image
                SizedBox(
                  width: double.infinity,
                  height: 100,
                  child: place.images.isNotEmpty
                      ? Image.asset(
                          place.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Theme.of(context).colorScheme.surfaceContainer,
                              child: Icon(
                                Icons.restaurant_outlined,
                                size: 28,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          child: Icon(
                            Icons.restaurant_outlined,
                            size: 28,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                ),
                
                // Restaurant details
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
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
                          const Spacer(),
                          if (place.isOpenNow)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Open',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
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
