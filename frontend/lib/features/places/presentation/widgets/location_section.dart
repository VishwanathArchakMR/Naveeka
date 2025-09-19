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
    final la = _latOf(place), ln = _lngOf(place); // read from toJson/keys robustly [web:5858]
    final hasCoords = la != null && ln != null;
    final hasOrigin = originLat != null && originLng != null;

    final actions = BookingServices.defaultActionsFromPlace(
      place,
      reserveUrl: reserveUrl,
      bookingUrl: bookingUrl,
      orderUrl: orderUrl,
    ); // Derive Website/Call/Directions, with optional partner links. [web:6261]

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
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

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
              ),

            if (hasOrigin && hasCoords) const SizedBox(height: 12),

            // Address
            AddressDetails.fromPlace(place),

            // Coordinates
            if (hasCoords) ...[
              const SizedBox(height: 12),
              CoordinatesDisplay.fromPlace(place),
            ],

            // Booking / Services quick actions
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              BookingServices(actions: actions),
            ],

            // Contact & Accessibility
            const SizedBox(height: 12),
            ContactAccessibility.fromPlace(place),
          ],
        ),
      ),
    );
  }

  // -------- Helpers to read coordinates from heterogeneous Place models --------

  static Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  } // Prefer toJson and Map access for flexible models. [web:5858]

  static double? _latOf(Place p) {
    final m = _json(p);
    final v = m['lat'] ?? m['latitude'] ?? m['locationLat'] ?? m['coordLat'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Parse numeric or string lat from known keys. [web:5858][web:6261]

  static double? _lngOf(Place p) {
    final m = _json(p);
    final v = m['lng'] ?? m['longitude'] ?? m['long'] ?? m['lon'] ?? m['locationLng'] ?? m['coordLng'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Parse numeric or string lng from known keys. [web:5858][web:6261]
}
