// lib/features/journey/presentation/flights/widgets/flight_route_map.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

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
    this.initialZoom = 3, // kept for API compatibility
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // placeholder
    this.tileSubdomains = const ['a', 'b', 'c'], // placeholder
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
  final double initialZoom; // unused in placeholder
  final String tileUrl; // unused in placeholder
  final List<String> tileSubdomains; // unused in placeholder

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
    }

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, height);
          final projector = _Projector.fromPoints([...stops, ...polyPoints], size);

          // Compute pin positions
          final originO = projector.toOffset(origin);
          final destO = projector.toOffset(dest);
          final layoverOffsets = <Offset, String>{};
          for (final m in layovers) {
            final p = _toLatLng(m['lat'], m['lng']);
            if (p != null) {
              layoverOffsets[projector.toOffset(p)] = (m['code'] ?? 'LAY').toString();
            }
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Route painter
                CustomPaint(
                  size: size,
                  painter: _FlightArcPainter(
                    projector: projector,
                    points: polyPoints,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                // Airport pins
                Positioned(
                  left: originO.dx - 27,
                  top: originO.dy - 20,
                  child: _AirportPin(code: fromCode ?? 'FROM'),
                ),
                for (final e in layoverOffsets.entries)
                  Positioned(
                    left: e.key.dx - 27,
                    top: e.key.dy - 20,
                    child: _AirportPin(code: e.value),
                  ),
                Positioned(
                  left: destO.dx - 27,
                  top: destO.dy - 20,
                  child: _AirportPin(code: toCode ?? 'TO'),
                ),
              ],
            ),
          );
        },
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
  List<LatLng> _greatCircle(LatLng a, LatLng b, {int samples = 64}) {
    // Convert to radians
    final lat1 = _degToRad(a.latitude);
    final lon1 = _degToRad(a.longitude);
    final lat2 = _degToRad(b.latitude);
    final lon2 = _degToRad(b.longitude);

    // Angular distance via haversine
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    final sinDLat2 = math.sin(dLat / 2);
    final sinDLon2 = math.sin(dLon / 2);
    final h = sinDLat2 * sinDLat2 + math.cos(lat1) * math.cos(lat2) * sinDLon2 * sinDLon2;
    final ang = 2 * math.atan2(math.sqrt(h), math.sqrt(math.max(0.0, 1 - h)));

    if (ang.abs() < 1e-9) return [a, b];

    final sinAng = math.sin(ang);

    final pts = <LatLng>[];
    final n = math.max(2, samples);
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
}

// Minimal LatLng type to avoid external dependency
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

// Projects geo bounds to canvas coordinates with padding
class _Projector {
  final double minLat, maxLat, minLng, maxLng;
  final double sx, sy;
  final double pad;
  final Size size;

  _Projector({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.sx,
    required this.sy,
    required this.pad,
    required this.size,
  });

  factory _Projector.fromPoints(List<LatLng> pts, Size size, {double pad = 16}) {
    if (pts.isEmpty) {
      return _Projector(
        minLat: 0,
        maxLat: 1,
        minLng: 0,
        maxLng: 1,
        sx: 1,
        sy: 1,
        pad: pad,
        size: size,
      );
    }
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // Avoid degenerate scale if bounds collapse
    if ((maxLat - minLat).abs() < 1e-9) {
      minLat -= 0.0001;
      maxLat += 0.0001;
    }
    if ((maxLng - minLng).abs() < 1e-9) {
      minLng -= 0.0001;
      maxLng += 0.0001;
    }
    final dx = (maxLng - minLng).abs();
    final dy = (maxLat - minLat).abs();
    final sx = (size.width - 2 * pad) / dx;
    final sy = (size.height - 2 * pad) / dy;
    return _Projector(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      sx: sx,
      sy: sy,
      pad: pad,
      size: size,
    );
  }

  Offset toOffset(LatLng p) {
    final w = size.width, h = size.height;
    final x = pad + (p.longitude - minLng) * sx;
    final y = h - pad - (p.latitude - minLat) * sy; // invert Y for canvas
    return Offset(x.clamp(0, w), y.clamp(0, h));
  }
}

class _FlightArcPainter extends CustomPainter {
  _FlightArcPainter({
    required this.projector,
    required this.points,
    required this.color,
  });

  final _Projector projector;
  final List<LatLng> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient + subtle grid
    final bg = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white,
          Colors.grey.shade100,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const pad = 16.0;
    for (var x = pad; x < size.width - pad; x += 24) {
      canvas.drawLine(Offset(x, pad), Offset(x, size.height - pad), gridPaint);
    }
    for (var y = pad; y < size.height - pad; y += 24) {
      canvas.drawLine(Offset(pad, y), Offset(size.width - pad, y), gridPaint);
    }

    if (points.isEmpty) return;

    final routePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final first = projector.toOffset(points.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final o = projector.toOffset(points[i]);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant _FlightArcPainter old) {
    return points != old.points || color != old.color || projector.size != old.projector.size;
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
