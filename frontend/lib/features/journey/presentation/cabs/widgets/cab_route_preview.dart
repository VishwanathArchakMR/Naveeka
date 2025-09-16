// lib/features/journey/presentation/cabs/widgets/cab_route_preview.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class CabRoutePreview extends StatelessWidget {
  const CabRoutePreview({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    this.routePoints, // optional decoded route polyline
    this.height = 260,
    this.initialZoom = 12,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.tileSubdomains = const ['a', 'b', 'c'],
    this.showDirectionsButton = true,
    this.onOpenExternalDirections,
  });

  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;

  /// Optional polyline points for preview; if null, draws a straight line. 
  final List<LatLng>? routePoints;

  final double height;
  final double initialZoom;
  final String tileUrl;
  final List<String> tileSubdomains;

  final bool showDirectionsButton;
  final VoidCallback? onOpenExternalDirections;

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(pickupLat, pickupLng);
    final drop = LatLng(dropLat, dropLng);

    final polyline = (routePoints != null && routePoints!.isNotEmpty)
        ? routePoints!
        : <LatLng>[pickup, drop]; // Fallback to straight segment when no shape is provided [6][12]

    final allPoints = <LatLng>[pickup, drop, ...polyline];

    // Prevent zero-area bounds by ensuring at least two distinct points; add a tiny delta if needed. 
    final bounds = allPoints.length >= 2
        ? LatLngBounds.fromPoints(allPoints)
        : LatLngBounds.fromPoints([
            allPoints.first,
            LatLng(allPoints.first.latitude + 0.0001, allPoints.first.longitude + 0.0001),
          ]); // CameraFit.bounds is used to auto-fit the viewport to the bounds with padding [1][4]

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                cameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(28),
                  maxZoom: 16,
                ), // CameraFit fits the view to bounds at build time with configurable padding and max zoom [1]
                initialZoom: initialZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  subdomains: tileSubdomains,
                  userAgentPackageName: 'com.example.app',
                ), // Standard OSM tile usage in flutter_map layers for a lightweight preview map [4]
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polyline,
                      strokeWidth: 4,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                  polylineCulling: true,
                ), // Draw route line using PolylineLayer for clarity of pickup→drop path [6][12]
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pickup,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const _Pin(
                        color: Colors.green,
                        icon: Icons.radio_button_checked,
                        tooltip: 'Pickup',
                      ),
                    ),
                    Marker(
                      point: drop,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const _Pin(
                        color: Colors.red,
                        icon: Icons.place_outlined,
                        tooltip: 'Drop',
                      ),
                    ),
                  ],
                ), // MarkerLayer allows arbitrary widgets as markers for interactive and styled pins [15]
              ],
            ),
            if (showDirectionsButton)
              Positioned(
                right: 12,
                top: 12,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: IconButton(
                    tooltip: 'Open directions',
                    icon: const Icon(Icons.navigation_outlined),
                    onPressed: () async {
                      onOpenExternalDirections?.call();
                      await _openDirections(pickup, drop);
                    },
                  ),
                ),
              ), // External navigation uses url_launcher with universal Google Maps URL for cross‑platform routing [13]
          ],
        ),
      ),
    );
  }

  Future<void> _openDirections(LatLng origin, LatLng dest) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&travelmode=driving&dir_action=navigate',
    ); // Universal Maps URL pattern that opens native app if present or falls back to browser [16][13]
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } // Launch via url_launcher with safe fallback modes for reliability in release builds [13][10]
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon, required this.tooltip});
  final Color color;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
