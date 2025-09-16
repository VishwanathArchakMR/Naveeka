// lib/features/atlas/presentation/widgets/famous_nearby.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../models/place.dart';
import '../../../../navigation/route_names.dart';
import '../../../../core/storage/seed_data_loader.dart';

class FamousNearbySection extends ConsumerStatefulWidget {
  const FamousNearbySection({super.key});

  @override
  ConsumerState<FamousNearbySection> createState() => _FamousNearbySectionState();
}

class _FamousNearbySectionState extends ConsumerState<FamousNearbySection> {
  List<Place> _famousPlaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFamousNearbyPlaces();
  }

  Future<void> _loadFamousNearbyPlaces() async {
    try {
      final atlasData = await ref.read(atlasDataProvider.future);
      final nearbyFamousData = atlasData['famousNearby'] as List<dynamic>? ?? [];

      _famousPlaces = nearbyFamousData
          .cast<Map<String, dynamic>>()
          .map((data) => Place.fromJson(data))
          .where((place) => place.isFeatured || place.rating >= 4.0)
          .take(5)
          .toList();

      // Sort by distance if available
      _famousPlaces.sort((a, b) {
        final aDistance = a.location.distanceFromUser ?? double.infinity;
        final bDistance = b.location.distanceFromUser ?? double.infinity;
        return aDistance.compareTo(bDistance);
      });
    } catch (e) {
      debugPrint('Error loading famous nearby places: $e');
      _famousPlaces = [];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_famousPlaces.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Famous Nearby',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              TextButton(
                onPressed: () {
                  context.pushNamed(
                    RouteNames.atlas,
                    queryParameters: const {'featured': 'true'},
                  );
                },
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _famousPlaces.length,
            itemBuilder: (context, index) {
              final place = _famousPlaces[index];
              return _FamousPlaceCard(
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

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Famous Nearby',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            itemBuilder: (context, index) => _buildPlaceholderCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 32,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'No famous places nearby',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Enable location to discover popular places around you',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard() {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 160,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FamousPlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;

  const _FamousPlaceCard({
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
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Place image with badges
                Stack(
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
                                    Icons.place_outlined,
                                    size: 32,
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

                    // Famous badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'Famous',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
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

                    // Emotion emoji
                    if (place.emotions.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            place.emotions.first.emoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),

                // Place details
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
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            place.formattedRating,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${place.reviewCount})',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
