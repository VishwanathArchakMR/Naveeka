// lib/features/journey/presentation/buses/widgets/bus_route_map.dart

import 'package:flutter/material.dart';
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
    this.initialZoom = 12, // kept for API compatibility
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // placeholder
    this.tileSubdomains = const ['a', 'b', 'c'], // placeholder
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
  final double initialZoom; // unused in placeholder
  final String tileUrl; // unused in placeholder
  final List<String> tileSubdomains; // unused in placeholder

  final bool showDirectionsButton;
  final VoidCallback? onOpenExternalDirections;

  /// Called when a stop marker is tapped with the stop map.
  final void Function(Map<String, dynamic> stop)? onTapStop;

  @override
  Widget build(BuildContext context) {
    final origin = LatLng(originLat, originLng);
    final destination = LatLng(destinationLat, destinationLng);

    final stopPoints = stops.map((s) => _toLatLng(s['lat'], s['lng'])).whereType<LatLng>().toList(growable: false);

    final polyline = (routePoints != null && routePoints!.isNotEmpty) ? routePoints! : <LatLng>[origin, destination];

    final allPoints = <LatLng>[
      origin,
      destination,
      ...stopPoints,
      ...polyline,
    ];

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          // Build projector from geo -> canvas space
          final proj = _Projector.fromPoints(allPoints, Size(w, height));

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Route and pins painter
                CustomPaint(
                  size: Size(w, height),
                  painter: _BusRoutePainter(
                    projector: proj,
                    polyline: polyline,
                    origin: origin,
                    destination: destination,
                    primary: Theme.of(context).colorScheme.primary,
                  ),
                ),

                // Tappable stop overlays
                ...stops.map((s) {
                  final p = _toLatLng(s['lat'], s['lng']);
                  if (p == null) return const SizedBox.shrink();
                  final o = proj.toOffset(p);
                  return Positioned(
                    left: o.dx - 14,
                    top: o.dy - 14,
                    width: 28,
                    height: 28,
                    child: GestureDetector(
                      onTap: onTapStop != null ? () => onTapStop!(s) : null,
                      child: const _Pin(
                        color: Colors.blue,
                        icon: Icons.stop_circle_outlined,
                        tooltip: 'Stop',
                      ),
                    ),
                  );
                }),

                // Directions button
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
          );
        },
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
    // Universal Google Maps URL; opens native app when available, else browser via url_launcher
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},'
      '${origin.longitude}&destination=${dest.latitude},${dest.longitude}&travelmode=driving&dir_action=navigate',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
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
    final dx = (maxLng - minLng).abs();
    final dy = (maxLat - minLat).abs();
    final sx = dx == 0 ? 1.0 : (size.width - 2 * pad) / dx;
    final sy = dy == 0 ? 1.0 : (size.height - 2 * pad) / dy;
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

class _BusRoutePainter extends CustomPainter {
  _BusRoutePainter({
    required this.projector,
    required this.polyline,
    required this.origin,
    required this.destination,
    required this.primary,
  });

  final _Projector projector;
  final List<LatLng> polyline;
  final LatLng origin;
  final LatLng destination;
  final Color primary;

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

    // Route path
    final routePaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (polyline.isNotEmpty) {
      final path = Path();
      final first = projector.toOffset(polyline.first);
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < polyline.length; i++) {
        final o = projector.toOffset(polyline[i]);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, routePaint);
    }

    // Origin pin
    _drawPin(canvas, projector.toOffset(origin), Colors.green, Icons.radio_button_checked);

    // Destination pin
    _drawPin(canvas, projector.toOffset(destination), Colors.red, Icons.flag_outlined);
  }

  void _drawPin(Canvas canvas, Offset at, Color color, IconData icon) {
    const r = 14.0;
    final paint = Paint()..color = color;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(at.translate(0, 2), r, shadow);
    canvas.drawCircle(at, r, paint);

    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 14,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BusRoutePainter oldDelegate) {
    return polyline != oldDelegate.polyline ||
        origin != oldDelegate.origin ||
        destination != oldDelegate.destination ||
        primary != oldDelegate.primary ||
        projector.size != oldDelegate.projector.size;
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
