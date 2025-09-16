// lib/features/journey/presentation/bookings/widgets/booking_route_map.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingRouteMap extends StatelessWidget {
  const BookingRouteMap({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    this.routePoints, // optional decoded route to draw as polyline
    this.height = 260,
    this.initialZoom = 12,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.tileSubdomains = const ['a', 'b', 'c'],
    this.onOpenExternalDirections,
    this.showDirectionsButton = true,
  });

  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;

  /// Optional pre-computed route geometry; if null, a straight line between origin/destination is drawn.
  final List<LatLng>? routePoints;

  final double height;
  final double initialZoom;
  final String tileUrl;
  final List<String> tileSubdomains;

  final VoidCallback? onOpenExternalDirections;
  final bool showDirectionsButton;

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(originLat, originLng);
    final destination = LatLng(destinationLat, destinationLng);

    final polyline = (routePoints != null && routePoints!.isNotEmpty)
        ? routePoints!
        : <LatLng>[origin, destination];

    final allPoints = <LatLng>[origin, destination, ...polyline];

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                // Auto-fit camera to include origin, destination, and the route with padding
                cameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(allPoints),
                  padding: const EdgeInsets.all(28),
                ),
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
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polyline,
                      strokeWidth: 4,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                  // Enable culling to skip drawing outside viewport for performance
                  polylineCulling: true,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: origin,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: _MarkerPin(
                        color: Colors.green,
                        icon: Icons.radio_button_checked,
                        tooltip: 'Origin',
                      ),
                    ),
                    Marker(
                      point: destination,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: _MarkerPin(
                        color: Colors.red,
                        icon: Icons.place,
                        tooltip: 'Destination',
                      ),
                    ),
                  ],
                ),
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
                      await _openDirections(origin, destination);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirections(LatLng origin, LatLng dest) async {
    // Universal Google Maps URL works across platforms; app if installed, else browser
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&travelmode=driving&dir_action=navigate',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({
    required this.color,
    required this.icon,
    required this.tooltip,
  });

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
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
