// lib/features/places/presentation/widgets/universal_place_page.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';

// Composed widgets provided earlier
import 'place_header.dart';
import 'photo_gallery.dart';
import 'address_details.dart';
import 'timings_schedule.dart';
import 'transport_info.dart';
import 'booking_services.dart';
import 'parking_info.dart';
import 'contact_accessibility.dart';
import 'coordinates_display.dart';
import 'reviews_ratings.dart';
import 'suggested_nearby.dart';
import 'location_section.dart';

class UniversalPlacePage extends StatelessWidget {
  const UniversalPlacePage({
    super.key,
    required this.place,
    this.originLat,
    this.originLng,
    this.currency = '₹',
    this.reserveUrl,
    this.bookingUrl,
    this.orderUrl,
    this.onToggleFavorite, // Future<bool> Function(bool next)
    this.favoriteCount,
    this.onOpenNearby, // void Function(Place place)
    this.onSeeAllNearby, // VoidCallback
    this.nearbyPlaces = const <Place>[],
    this.reviews = const <ReviewItem>[],
    this.reviewDistribution,
  });

  final Place place;

  // Optional user/device origin
  final double? originLat;
  final double? originLng;

  final String currency;

  // Optional partner URLs
  final Uri? reserveUrl;
  final Uri? bookingUrl;
  final Uri? orderUrl;

  final Future<bool> Function(bool next)? onToggleFavorite;
  final int? favoriteCount;

  // Nearby
  final List<Place> nearbyPlaces;
  final void Function(Place place)? onOpenNearby;
  final VoidCallback? onSeeAllNearby;

  // Reviews
  final List<ReviewItem> reviews;
  final Map<int, int>? reviewDistribution;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsible image header with actions
          PlaceHeaderSliver(
            place: place,
            expandedHeight: 280,
            heroTag: 'place-hero-${place.id}',
            onToggleFavorite: onToggleFavorite,
            favoriteCount: favoriteCount,
          ),

          // Body sections as a single sliver list
          SliverList(
            delegate: SliverChildListDelegate(
              [
                const SizedBox(height: 8),

                // Gallery
                if ((place.photos ?? const <String>[]).isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: PhotoGallery.fromPlace(
                      place,
                      crossAxisCount: 3,
                      spacing: 6,
                      radius: 10,
                      initialHeroPrefix: 'place-hero',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Location section (distance + directions + address + coords + booking + contact)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LocationSection(
                    place: place,
                    originLat: originLat,
                    originLng: originLng,
                    unit: UnitSystem.metric,
                    reserveUrl: reserveUrl,
                    bookingUrl: bookingUrl,
                    orderUrl: orderUrl,
                    showFavorite: onToggleFavorite != null,
                    onToggleFavorite: onToggleFavorite,
                    favoriteCount: favoriteCount,
                  ),
                ),

                const SizedBox(height: 12),

                // Hours
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TimingsSchedule.fromPlace(place),
                ),

                const SizedBox(height: 12),

                // Transport
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TransportInfo.fromPlace(place),
                ),

                const SizedBox(height: 12),

                // Parking
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ParkingInfo.fromPlace(place, currency: currency),
                ),

                const SizedBox(height: 12),

                // Reviews & ratings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ReviewsRatings.fromPlace(
                    place,
                    distribution: reviewDistribution,
                    reviews: reviews,
                    enableWrite: false,
                  ),
                ),

                const SizedBox(height: 12),

                // Suggested nearby carousel
                if (nearbyPlaces.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: SuggestedNearby(
                      places: nearbyPlaces,
                      originLat: originLat,
                      originLng: originLng,
                      onOpenPlace: onOpenNearby,
                      onSeeAll: onSeeAllNearby,
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    ); // CustomScrollView with slivers composes an expanding header and a sliver list body efficiently, following Flutter’s sliver architecture. [1][11]
  }
}
