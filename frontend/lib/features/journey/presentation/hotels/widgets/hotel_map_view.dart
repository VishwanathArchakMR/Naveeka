// lib/features/journey/presentation/hotels/widgets/hotel_map_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HotelMapView extends StatelessWidget {
  const HotelMapView({
    super.key,
    required this.hotels,
    this.height = 280,
    this.initialZoom = 12,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.tileSubdomains = const ['a', 'b', 'c'],
    this.currency = '₹',
    this.onTapHotel,
    this.selectedHotelId,
  });

  /// Expected hotel item shape:
  /// { id, name, lat, lng, price (num)?, rating (double)? }
  final List<Map<String, dynamic>> hotels;

  final double height;
  final double initialZoom;
  final String tileUrl;
  final List<String> tileSubdomains;
  final String currency;

  /// Callback when a marker is tapped.
  final void Function(Map<String, dynamic> hotel)? onTapHotel;

  /// Optionally highlight a selected hotel marker.
  final String? selectedHotelId;

  @override
  Widget build(BuildContext context) {
    // Convert hotel maps into LatLng points with safe parsing.
    final points = <LatLng>[];
    for (final h in hotels) {
      final p = _toLatLng(h['lat'], h['lng']);
      if (p != null) points.add(p);
    }

    // Fallback center if no valid coordinates.
    final fallbackCenter = const LatLng(20.5937, 78.9629); // India centroid as neutral fallback

    // Compute bounds for auto-fit on first paint; add tiny delta if only one point.
    LatLngBounds? bounds;
    if (points.isNotEmpty) {
      if (points.length == 1) {
        final p = points.first;
        bounds = LatLngBounds.fromPoints([
          p,
          LatLng(p.latitude + 0.0005, p.longitude + 0.0005),
        ]);
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
            // Prefer CameraFit.bounds to auto-fit initial viewport to hotel markers.
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
          ), // CameraFit.* sets initial positioning with padding/limits for a clear view of all markers [9]
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: tileSubdomains,
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: [
                for (final h in hotels)
                  if (_toLatLng(h['lat'], h['lng']) != null)
                    _hotelMarker(
                      context: context,
                      hotel: h,
                      point: _toLatLng(h['lat'], h['lng'])!,
                      currency: currency,
                      selected: selectedHotelId != null &&
                          (h['id']?.toString() ?? '') == selectedHotelId,
                    ),
              ],
            ), // MarkerLayer supports any Flutter widget as a marker with custom tap handling via GestureDetector [1][2]
          ],
        ),
      ),
    );
  }

  Marker _hotelMarker({
    required BuildContext context,
    required Map<String, dynamic> hotel,
    required LatLng point,
    required String currency,
    required bool selected,
  }) {
    final price = hotel['price'];
    final rating = hotel['rating'] is num ? (hotel['rating'] as num).toDouble() : null;
    final name = (hotel['name'] ?? '').toString();

    return Marker(
      point: point,
      width: 64,
      height: 64,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onTapHotel != null ? () => onTapHotel!(hotel) : null,
        child: _PricePin(
          label: price is num ? '$currency${price.toStringAsFixed(0)}' : (name.isNotEmpty ? name : 'Hotel'),
          selected: selected,
          rating: rating,
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

class _PricePin extends StatelessWidget {
  const _PricePin({
    required this.label,
    required this.selected,
    required this.rating,
  });

  final String label;
  final bool selected;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.white;
    final fg = selected ? Theme.of(context).colorScheme.onPrimary : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
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
          if (rating != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.star_rate_rounded, size: 14, color: selected ? fg : Colors.amber),
            Text(
              rating!.toStringAsFixed(1),
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
