// lib/features/journey/presentation/bookings/widgets/booking_route_map.dart

import 'package:flutter/material.dart';
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
    this.initialZoom = 12, // kept for API compatibility
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // placeholder
    this.tileSubdomains = const ['a', 'b', 'c'], // placeholder
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
  final double initialZoom; // unused in placeholder
  final String tileUrl; // unused in placeholder
  final List<String> tileSubdomains; // unused in placeholder

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
            // Placeholder “map-like” canvas with scaled route
            CustomPaint(
              size: Size(double.infinity, height),
              painter: _RoutePainter(
                points: allPoints,
                origin: origin,
                destination: destination,
                primary: Theme.of(context).colorScheme.primary,
              ),
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

// Minimal LatLng type to avoid external dependency
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.points,
    required this.origin,
    required this.destination,
    required this.primary,
  });

  final List<LatLng> points;
  final LatLng origin;
  final LatLng destination;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Compute bounds
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Padding for aesthetics
    const pad = 16.0;
    final w = size.width;
    final h = size.height;
    final dx = (maxLng - minLng).abs();
    final dy = (maxLat - minLat).abs();
    final sx = dx == 0 ? 1.0 : (w - 2 * pad) / dx;
    final sy = dy == 0 ? 1.0 : (h - 2 * pad) / dy;

    Offset toOffset(LatLng p) {
      // y inverted to put higher latitudes near the top
      final x = pad + (p.longitude - minLng) * sx;
      final y = h - pad - (p.latitude - minLat) * sy;
      return Offset(x.clamp(0, w), y.clamp(0, h));
    }

    // Background grid
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var x = pad; x < w - pad; x += 24) {
      canvas.drawLine(Offset(x, pad), Offset(x, h - pad), gridPaint);
    }
    for (var y = pad; y < h - pad; y += 24) {
      canvas.drawLine(Offset(pad, y), Offset(w - pad, y), gridPaint);
    }

    // Route polyline
    final routePaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final first = toOffset(points.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final o = toOffset(points[i]);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, routePaint);

    // Origin pin
    final o = toOffset(origin);
    _drawPin(canvas, o, Colors.green, Icons.radio_button_checked);

    // Destination pin
    final d = toOffset(destination);
    _drawPin(canvas, d, Colors.red, Icons.place);
  }

  void _drawPin(Canvas canvas, Offset at, Color color, IconData icon) {
    final r = 14.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0);
    // Shadow
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(at.translate(0, 2), r, shadow);
    // Circle
    canvas.drawCircle(at, r, paint);
    // Icon
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
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return points != oldDelegate.points ||
        origin != oldDelegate.origin ||
        destination != oldDelegate.destination ||
        primary != oldDelegate.primary;
  }
}
