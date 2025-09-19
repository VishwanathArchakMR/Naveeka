// lib/features/journey/presentation/cabs/widgets/cab_route_preview.dart

import 'package:flutter/material.dart';
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
    this.initialZoom = 12, // kept for API compatibility
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // placeholder
    this.tileSubdomains = const ['a', 'b', 'c'], // placeholder
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
  final double initialZoom; // unused in placeholder
  final String tileUrl; // unused in placeholder
  final List<String> tileSubdomains; // unused in placeholder

  final bool showDirectionsButton;
  final VoidCallback? onOpenExternalDirections;

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(pickupLat, pickupLng);
    final drop = LatLng(dropLat, dropLng);

    final polyline = (routePoints != null && routePoints!.isNotEmpty)
        ? routePoints!
        : <LatLng>[pickup, drop];

    final allPoints = <LatLng>[pickup, drop, ...polyline];

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final projector = _Projector.fromPoints(allPoints, Size(w, height));
          final pick = projector.toOffset(pickup);
          final drp = projector.toOffset(drop);

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(w, height),
                  painter: _CabRoutePainter(
                    projector: projector,
                    polyline: polyline,
                    pickup: pickup,
                    drop: drop,
                    primary: Theme.of(context).colorScheme.primary,
                  ),
                ),
                // Pickup pin
                Positioned(
                  left: pick.dx - 14,
                  top: pick.dy - 14,
                  width: 28,
                  height: 28,
                  child: const _Pin(
                    color: Colors.green,
                    icon: Icons.radio_button_checked,
                    tooltip: 'Pickup',
                  ),
                ),
                // Drop pin
                Positioned(
                  left: drp.dx - 14,
                  top: drp.dy - 14,
                  width: 28,
                  height: 28,
                  child: const _Pin(
                    color: Colors.red,
                    icon: Icons.place_outlined,
                    tooltip: 'Drop',
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
                          await _openDirections(pickup, drop);
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

  Future<void> _openDirections(LatLng origin, LatLng dest) async {
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

class _CabRoutePainter extends CustomPainter {
  _CabRoutePainter({
    required this.projector,
    required this.polyline,
    required this.pickup,
    required this.drop,
    required this.primary,
  });

  final _Projector projector;
  final List<LatLng> polyline;
  final LatLng pickup;
  final LatLng drop;
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

    // Route polyline
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

    // If only two points present (straight segment), ensure a faint planned line exists
    if (polyline.length < 2) {
      final p1 = projector.toOffset(pickup);
      final p2 = projector.toOffset(drop);
      final planned = Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final path = Path()..moveTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy);
      canvas.drawPath(path, planned);
    }
  }

  @override
  bool shouldRepaint(covariant _CabRoutePainter oldDelegate) {
    return polyline != oldDelegate.polyline ||
        pickup != oldDelegate.pickup ||
        drop != oldDelegate.drop ||
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
