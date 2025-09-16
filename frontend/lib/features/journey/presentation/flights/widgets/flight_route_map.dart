// lib/features/journey/presentation/flights/widgets/flight_route_map.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FlightRouteMap extends StatelessWidget {
  const FlightRouteMap({
    super.key,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    this.fromCode,
    this.toCode,
    this.layovers = const <Map<String, dynamic>>[], // [{lat,lng,code?}]
    this.height = 220,
    this.initialZoom = 3,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.tileSubdomains = const ['a', 'b', 'c'],
    this.curveSamples = 64, // points per great-circle segment
  });

  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;

  final String? fromCode;
  final String? toCode;

  /// Optional intermediate airports: each {lat,lng,code?}
  final List<Map<String, dynamic>> layovers;

  final double height;
  final double initialZoom;
  final String tileUrl;
  final List<String> tileSubdomains;

  /// Number of interpolation points per segment when drawing great‑circle arcs.
  final int curveSamples;

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(fromLat, fromLng);
    final dest = LatLng(toLat, toLng);

    final stops = [
      origin,
      ...layovers.map((m) => _toLatLng(m['lat'], m['lng'])).whereType<LatLng>(),
      dest,
    ];

    // Build great-circle polylines per leg (origin -> layover1 -> ... -> dest).
    final polyPoints = <LatLng>[];
    for (var i = 0; i < stops.length - 1; i++) {
      final a = stops[i];
      final b = stops[i + 1];
      polyPoints.addAll(_greatCircle(a, b, samples: curveSamples));
    } // Polyline points are consumed by PolylineLayer to render the route path efficiently [3][1]

    // Bounds for auto-fit
    final bounds = LatLngBounds.fromPoints([
      ...stops,
      ...polyPoints,
    ]);

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            // Auto-fit on first paint; padding ensures pins/curve are comfortably visible
            cameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(24),
              maxZoom: 8,
            ), // CameraFit.bounds sets initial view to include the provided bounds with padding and optional maxZoom [9][6]
            initialZoom: initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
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
                  points: polyPoints,
                  strokeWidth: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
              polylineCulling: true,
            ), // PolylineLayer draws lines from LatLng points; enable culling for perf outside viewport [3][2]
            MarkerLayer(
              markers: [
                _airportMarker(origin, code: fromCode ?? 'FROM'),
                for (final m in layovers)
                  if (_toLatLng(m['lat'], m['lng']) != null)
                    _airportMarker(_toLatLng(m['lat'], m['lng'])!, code: (m['code'] ?? 'LAY').toString()),
                _airportMarker(dest, code: toCode ?? 'TO'),
              ],
            ), // MarkerLayer places arbitrary widgets as markers for airports and layovers [1]
          ],
        ),
      ),
    );
  }

  // Convert to LatLng with safety around number parsing.
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

  // Great-circle interpolation between two coordinates using spherical linear interpolation (slerp).
  // This approximates the geodesic arc on a sphere; sufficient for preview-scale mapping. [10][15]
  List<LatLng> _greatCircle(LatLng a, LatLng b, {int samples = 64}) {
    // Convert to radians
    final lat1 = _degToRad(a.latitude);
    final lon1 = _degToRad(a.longitude);
    final lat2 = _degToRad(b.latitude);
    final lon2 = _degToRad(b.longitude);

    // Compute the angular distance using the haversine formula
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    final sinDLat2 = math.sin(dLat / 2);
    final sinDLon2 = math.sin(dLon / 2);
    final h = sinDLat2 * sinDLat2 + math.cos(lat1) * math.cos(lat2) * sinDLon2 * sinDLon2;
    final ang = 2 * math.atan2(math.sqrt(h), math.sqrt(math.max(0.0, 1 - h))); // central angle [15][7]

    // If nearly zero distance, just return endpoints
    if (ang.abs() < 1e-9) return [a, b];

    final sinAng = math.sin(ang);

    List<LatLng> pts = [];
    final n = math.max(2, samples); // at least endpoints
    for (int i = 0; i <= n; i++) {
      final f = i / n;
      final A = math.sin((1 - f) * ang) / sinAng;
      final B = math.sin(f * ang) / sinAng;

      // Slerp on unit sphere
      final x = A * math.cos(lat1) * math.cos(lon1) + B * math.cos(lat2) * math.cos(lon2);
      final y = A * math.cos(lat1) * math.sin(lon1) + B * math.cos(lat2) * math.sin(lon2);
      final z = A * math.sin(lat1) + B * math.sin(lat2);

      final lat = math.atan2(z, math.sqrt(x * x + y * y));
      final lon = math.atan2(y, x);

      pts.add(LatLng(_radToDeg(lat), _radToDeg(lon)));
    }
    return pts;
  }

  double _degToRad(double d) => d * math.pi / 180.0;
  double _radToDeg(double r) => r * 180.0 / math.pi;

  Marker _airportMarker(LatLng p, {required String code}) {
    return Marker(
      point: p,
      width: 54,
      height: 54,
      alignment: Alignment.center,
      child: _AirportPin(code: code),
    );
  }
}

class _AirportPin extends StatelessWidget {
  const _AirportPin({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primaryContainer;
    final fg = Theme.of(context).colorScheme.onPrimaryContainer;
    return Tooltip(
      message: code,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
        ),
        child: Text(
          code,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
