// lib/features/places/presentation/widgets/location_section.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';

// Reuse the widgets we created earlier
import 'address_details.dart';
import 'coordinates_display.dart';
import 'directions_button.dart';
import 'distance_indicator.dart';
import 'booking_services.dart';
import 'contact_accessibility.dart';
import 'favorite_heart_button.dart';

class LocationSection extends StatelessWidget {
  const LocationSection({
    super.key,
    required this.place,
    this.originLat,
    this.originLng,
    this.unit = UnitSystem.metric,
    this.reserveUrl,
    this.bookingUrl,
    this.orderUrl,
    this.showFavorite = true,
    this.onToggleFavorite, // Future<bool> Function(bool next)
    this.favoriteCount,
    this.sectionTitle = 'Location',
  });

  final Place place;

  /// Optional origin coordinates to compute distance and show "away" label.
  final double? originLat;
  final double? originLng;

  /// Unit system for distance formatting.
  final UnitSystem unit;

  /// Optional partner links to enrich booking actions.
  final Uri? reserveUrl;
  final Uri? bookingUrl;
  final Uri? orderUrl;

  /// Favorite heart visibility and handler.
  final bool showFavorite;
  final Future<bool> Function(bool next)? onToggleFavorite;
  final int? favoriteCount;

  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    final hasCoords = place.lat != null && place.lng != null;
    final hasOrigin = originLat != null && originLng != null;

    final actions = BookingServices.defaultActionsFromPlace(
      place,
      reserveUrl: reserveUrl,
      bookingUrl: bookingUrl,
      orderUrl: orderUrl,
    ); // Use a helper to derive sensible defaults like Website/Call/Directions, with optional partner links for reservations/tickets. [1]

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const Icon(Icons.place_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sectionTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (showFavorite && onToggleFavorite != null)
                  FavoriteHeartButton.fromPlace(
                    place: place,
                    onChanged: onToggleFavorite!,
                    count: favoriteCount,
                    compact: true,
                    tooltip: 'Save',
                  ),
              ],
            ), // Header uses a simple Row with an icon and bold title, a common pattern paired with ListTile-like content below. [1][4]

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8), // Divider visually separates the header from content for scannability. [15][18]

            // Distance + Directions (top utility row)
            if (hasOrigin && hasCoords)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DistanceIndicator.fromPlace(
                    place,
                    originLat: originLat!,
                    originLng: originLng!,
                    unit: unit,
                    compact: true,
                    labelSuffix: 'away',
                  ),
                  DirectionsButton.fromPlace(
                    place,
                    mode: TravelMode.driving,
                    label: 'Directions',
                    expanded: false,
                  ),
                ],
              ), // DistanceIndicator computes great‑circle distance via haversine, and DirectionsButton launches Maps URLs for native navigation. [21][22]

            if (hasOrigin && hasCoords) const SizedBox(height: 12),

            // Address
            AddressDetails.fromPlace(place),
            // AddressDetails presents address, call, website, and open-in-maps actions using Material ListTiles. [1]

            // Coordinates
            if (hasCoords) ...[
              const SizedBox(height: 12),
              CoordinatesDisplay.fromPlace(place),
            ], // CoordinatesDisplay shows decimal and DMS with copy and maps shortcuts for clarity and utility. [23][24]

            // Booking / Services quick actions
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              BookingServices(actions: actions),
            ], // BookingServices renders action buttons (Reserve/Book/Order/Website/Call/Directions) with safe URL intents. [23]

            // Contact & Accessibility
            const SizedBox(height: 12),
            ContactAccessibility.fromPlace(place),
            // ContactAccessibility lists contact channels and accessibility amenities with clear labels and Semantics. [25]
          ],
        ),
      ),
    );
  }
}
