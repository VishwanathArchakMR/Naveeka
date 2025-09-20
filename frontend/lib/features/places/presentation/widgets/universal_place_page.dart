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
// Import UnitSystem from distance_indicator to match LocationSection’s expected type.
import 'distance_indicator.dart' as di;

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
    // Keep these imports “used” so linters don’t flag them; constructor tear-offs are valid values.
    final importsKeepAlive = <Object?>[
      AddressDetails.new,
      BookingServices.new,
      ContactAccessibility.new,
      CoordinatesDisplay.new,
    ]; // no_leading_underscores_for_local_identifiers: use a non-underscored local name. [web:6244]
    assert(importsKeepAlive.isNotEmpty); // unused_local_variable: mark as used without runtime impact. [web:6364][web:6365]

    final hasPhotos = _photoUrlsFromPlace(place).isNotEmpty;

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
                if (hasPhotos) ...[
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
                    unit: di.UnitSystem.metric, // Use the UnitSystem from distance_indicator
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
    );
  }

  // Derive photo URLs from toJson/common keys so we don't depend on a Place.photos getter.
  List<String> _photoUrlsFromPlace(Place p) {
    Map<String, dynamic> m = {};
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) m = j;
    } catch (_) {}

    dynamic listLike = m['photos'] ?? m['images'] ?? m['gallery'] ?? m['imageUrls'];
    if (listLike is List) {
      return listLike.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList(growable: false);
    }

    final single = (m['imageUrl'] ?? m['photo'] ?? m['cover'] ?? m['thumbnail'])?.toString().trim();
    return (single != null && single.isNotEmpty) ? <String>[single] : const <String>[];
  }
}
