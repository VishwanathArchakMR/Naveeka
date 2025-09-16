// lib/features/journey/presentation/buses/widgets/bus_route_map.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class BusRouteMap extends StatelessWidget {
  const BusRouteMap({
    super.key,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    this.stops = const <Map<String, dynamic>>[], // [{name, lat, lng, time?}]
    this.routePoints, // optional decoded route geometry
    this.height = 260,
    this.initialZoom = 12,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.tileSubdomains = const ['a', 'b', 'c'],
    this.showDirectionsButton = true,
    this.onOpenExternalDirections,
    this.onTapStop,
  });

  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;

  /// Optional intermediate stops: { name, lat, lng, time? }
  final List<Map<String, dynamic>> stops;

  /// Optional full route shape; when null, draws a straight segment between endpoints.
  final List<LatLng>? routePoints;

  final double height;
  final double initialZoom;
  final String tileUrl;
  final List<String> tileSubdomains;

  final bool showDirectionsButton;
  final VoidCallback? onOpenExternalDirections;

  /// Called when a stop marker is tapped with the stop map.
  final void Function(Map<String, dynamic> stop)? onTapStop;

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(originLat, originLng);
    final destination = LatLng(destinationLat, destinationLng);

    final stopPoints = stops
        .map((s) => _toLatLng(s['lat'], s['lng']))
        .whereType<LatLng>()
        .toList(growable: false);

    final polyline = (routePoints != null && routePoints!.isNotEmpty)
        ? routePoints!
        : <LatLng>[origin, destination];

    final allPoints = <LatLng>[
      origin,
      destination,
      ...stopPoints,
      ...polyline,
    ];

    // Safety: if allPoints collapses to one coordinate, CameraFit.bounds can misbehave; add a tiny delta. [6]
    final bounds = allPoints.length >= 2
        ? LatLngBounds.fromPoints(allPoints)
        : LatLngBounds.fromPoints([
            allPoints.first,
            LatLng(allPoints.first.latitude + 0.0001, allPoints.first.longitude + 0.0001),
          ]);

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
                  maxZoom: 16, // keep a sensible upper bound for close fits [9]
                ),
                initialZoom: initialZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
              ), // CameraFit.bounds auto-fits the viewport to include all points with padding [9]
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  subdomains: tileSubdomains,
                  userAgentPackageName: 'com.example.app',
                ), // Standard OSM tile layer usage with flutter_map [11]
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polyline,
                      strokeWidth: 4,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                  polylineCulling: true,
                ), // Draws the route as a polyline for visual guidance [12]
                MarkerLayer(
                  markers: [
                    // Origin
                    Marker(
                      point: origin,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const _Pin(color: Colors.green, icon: Icons.radio_button_checked, tooltip: 'Origin'),
                    ),
                    // Destination
                    Marker(
                      point: destination,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const _Pin(color: Colors.red, icon: Icons.flag_outlined, tooltip: 'Destination'),
                    ),
                    // Stops
                    ...stops.map((s) {
                      final p = _toLatLng(s['lat'], s['lng']);
                      if (p == null) return const Marker(point: LatLng(0, 0), child: SizedBox.shrink());
                      return Marker(
                        point: p,
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: onTapStop != null ? () => onTapStop!(s) : null,
                          child: const _Pin(color: Colors.blue, icon: Icons.stop_circle_outlined, tooltip: 'Stop'),
                        ),
                      );
                    }),
                  ],
                ), // MarkerLayer supports arbitrary widgets and custom tap handling for markers [1][3]
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

  Future<void> _openDirections(LatLng origin, LatLng dest) async {
    // Universal Google Maps URL; opens native app when available, else browser via url_launcher [13][10]
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
