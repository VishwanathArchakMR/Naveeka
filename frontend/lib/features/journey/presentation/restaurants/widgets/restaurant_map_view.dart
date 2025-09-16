// lib/features/journey/presentation/restaurants/widgets/restaurant_map_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RestaurantMapView extends StatelessWidget {
  const RestaurantMapView({
    super.key,
    required this.restaurants,
    this.height = 280,
    this.initialZoom = 12,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.tileSubdomains = const ['a', 'b', 'c'],
    this.currency = '₹',
    this.onTapRestaurant,
    this.selectedRestaurantId,
    this.showPriceLevel = true, // when false, show rating in pin
  });

  /// Expected item shape:
  /// {
  ///   id, name, lat, lng,
  ///   rating? (double), reviewCount? (int),
  ///   priceLevel? (1..5) or costForTwo? (num),
  ///   openNow? (bool)
  /// }
  final List<Map<String, dynamic>> restaurants;

  final double height;
  final double initialZoom;
  final String tileUrl;
  final List<String> tileSubdomains;
  final String currency;

  final void Function(Map<String, dynamic> restaurant)? onTapRestaurant;
  final String? selectedRestaurantId;

  /// If true, pin shows ₹ symbols (priceLevel or cost); otherwise shows rating.
  final bool showPriceLevel;

  @override
  Widget build(BuildContext context) {
    // Parse coordinates
    final points = <LatLng>[];
    for (final r in restaurants) {
      final p = _toLatLng(r['lat'], r['lng']);
      if (p != null) points.add(p);
    }

    // Fallback center if none
    final fallbackCenter = const LatLng(20.5937, 78.9629); // India centroid

    // Bounds for auto-fit on first paint; add tiny delta if only one point
    LatLngBounds? bounds;
    if (points.isNotEmpty) {
      if (points.length == 1) {
        final p = points.first;
        bounds = LatLngBounds.fromPoints([p, LatLng(p.latitude + 0.0005, p.longitude + 0.0005)]);
      } else {
        bounds = LatLngBounds.fromPoints(points);
      }
    }

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            // Initial camera fit so all pins are visible with padding
            cameraFit: bounds != null
                ? CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(28),
                    maxZoom: 16,
                  )
                : CameraFit.coordinates(
                    coordinates: [fallbackCenter],
                    zoom: initialZoom,
                  ),
            initialZoom: initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.doubleTapZoom,
            ),
          ), // CameraFit.bounds configures initial viewport to include bounds; use coordinates when empty [9][6]
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: tileSubdomains,
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: [
                for (final r in restaurants)
                  if (_toLatLng(r['lat'], r['lng']) != null)
                    _restaurantMarker(
                      context: context,
                      restaurant: r,
                      point: _toLatLng(r['lat'], r['lng'])!,
                      currency: currency,
                      selected: selectedRestaurantId != null &&
                          (r['id']?.toString() ?? '') == selectedRestaurantId,
                      showPriceLevel: showPriceLevel,
                    ),
              ],
            ), // MarkerLayer accepts arbitrary widgets; add GestureDetector inside marker for taps per docs [1][2]
          ],
        ),
      ),
    );
  }

  Marker _restaurantMarker({
    required BuildContext context,
    required Map<String, dynamic> restaurant,
    required LatLng point,
    required String currency,
    required bool selected,
    required bool showPriceLevel,
  }) {
    final rating = (restaurant['rating'] is num) ? (restaurant['rating'] as num).toDouble() : null;
    final open = restaurant['openNow'] == true;
    final priceLevel = restaurant['priceLevel'] is int ? (restaurant['priceLevel'] as int) : null;
    final costForTwo = restaurant['costForTwo'] is num ? (restaurant['costForTwo'] as num) : null;

    return Marker(
      point: point,
      width: 72,
      height: 64,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onTapRestaurant != null ? () => onTapRestaurant!(restaurant) : null,
        child: _Pin(
          showPriceLevel: showPriceLevel,
          currency: currency,
          priceLevel: priceLevel,
          costForTwo: costForTwo,
          rating: rating,
          openNow: open,
          selected: selected,
        ),
      ),
    );
  }

  LatLng? _toLatLng(dynamic lat, dynamic lng) {
    double? d(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }
    final la = d(lat), ln = d(lng);
    if (la == null || ln == null) return null;
    return LatLng(la, ln);
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.showPriceLevel,
    required this.currency,
    required this.priceLevel,
    required this.costForTwo,
    required this.rating,
    required this.openNow,
    required this.selected,
  });

  final bool showPriceLevel;
  final String currency;
  final int? priceLevel;
  final num? costForTwo;
  final double? rating;
  final bool openNow;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Theme.of(context).colorScheme.primary : Colors.white;
    final fg = selected ? Theme.of(context).colorScheme.onPrimary : Colors.black87;

    final label = showPriceLevel
        ? _priceLabel()
        : (rating != null ? rating!.toStringAsFixed(1) : '—');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.black12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Icon(openNow ? Icons.circle : Icons.circle_outlined, size: 10, color: openNow ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  String _priceLabel() {
    if (priceLevel != null && priceLevel! > 0) {
      final n = priceLevel!.clamp(1, 5);
      return List.filled(n, currency).join();
    }
    if (costForTwo != null) {
      final v = costForTwo!;
      final whole = v is int ? v : v.toDouble();
      return '$currency${whole.toStringAsFixed(0)}';
    }
    return '—';
  }
}
