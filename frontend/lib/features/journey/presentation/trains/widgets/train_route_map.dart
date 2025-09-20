// lib/features/journey/presentation/trains/widgets/train_route_map.dart

import 'package:flutter/material.dart';

class TrainRouteMap extends StatelessWidget {
  const TrainRouteMap({
    super.key,
    required this.stops,
    this.height = 220,
    this.initialZoom = 6, // kept for API compatibility (unused)
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // placeholder
    this.tileSubdomains = const ['a', 'b', 'c'], // placeholder
    this.strokeWidth = 3.0,
    this.showStopLabels = true,
    this.onTapStop,
  });

  /// Ordered stops defining the train path.
  /// Each stop: { lat, lng, code?, name? }
  final List<Map<String, dynamic>> stops;

  final double height;
  final double initialZoom;
  final String tileUrl;
  final List<String> tileSubdomains;
  final double strokeWidth;
  final bool showStopLabels;

  /// Optional callback when a station pin is tapped.
  final void Function(Map<String, dynamic> stop)? onTapStop;

  @override
  Widget build(BuildContext context) {
    // Convert and filter coordinates
    final points = <LatLng>[];
    for (final s in stops) {
      final p = _toLatLng(s['lat'], s['lng']);
      if (p != null) points.add(p);
    }

    // Fallback center (India centroid) if no points available
    const fallbackCenter = LatLng(20.5937, 78.9629);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, height);

          // Fit projector to points or a small bbox around fallback if empty
          final proj = points.isNotEmpty
              ? _Projector.fromPoints(_expandForSingle(points), size)
              : _Projector.fromPoints(
                  [
                    LatLng(fallbackCenter.latitude - 0.25, fallbackCenter.longitude - 0.25),
                    LatLng(fallbackCenter.latitude + 0.25, fallbackCenter.longitude + 0.25),
                  ],
                  size,
                );

          // Precompute station offsets
          final stationOffsets = <int, Offset>{};
          for (var i = 0; i < stops.length; i++) {
            final p = _toLatLng(stops[i]['lat'], stops[i]['lng']);
            if (p != null) stationOffsets[i] = proj.toOffset(p);
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Background + route painter
                CustomPaint(
                  size: size,
                  painter: _RoutePainter(
                    projector: proj,
                    points: points,
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: strokeWidth,
                  ),
                ),

                // Station pins
                for (var i = 0; i < stops.length; i++)
                  if (stationOffsets[i] != null)
                    Positioned(
                      left: (stationOffsets[i]!.dx) - (showStopLabels ? 34 : 10),
                      top: (stationOffsets[i]!.dy) - 24,
                      child: GestureDetector(
                        onTap: onTapStop != null ? () => onTapStop!(stops[i]) : null,
                        child: _StationPin(
                          label: showStopLabels
                              ? (() {
                                  final code = (stops[i]['code'] ?? '').toString();
                                  final name = (stops[i]['name'] ?? '').toString();
                                  return code.isNotEmpty ? code : (name.isNotEmpty ? name : '•');
                                })()
                              : null,
                          isStart: i == 0,
                          isEnd: i == stops.length - 1,
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

  // If single point, add tiny delta so projector has non-zero area
  List<LatLng> _expandForSingle(List<LatLng> pts) {
    if (pts.length != 1) return pts;
    final p = pts.first;
    return [p, LatLng(p.latitude + 0.0005, p.longitude + 0.0005)];
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

// Minimal LatLng to avoid external dependency
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

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.projector,
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  final _Projector projector;
  final List<LatLng> points;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle background
    final bg = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, Colors.grey.shade100],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Grid
    final grid = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const pad = 16.0;
    for (var x = pad; x < size.width - pad; x += 24) {
      canvas.drawLine(Offset(x, pad), Offset(x, size.height - pad), grid);
    }
    for (var y = pad; y < size.height - pad; y += 24) {
      canvas.drawLine(Offset(pad, y), Offset(size.width - pad, y), grid);
    }

    if (points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final first = projector.toOffset(points.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final o = projector.toOffset(points[i]);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, paint); // draw polyline

    // Optional station dots on the line
    final dot = Paint()..color = color.withValues(alpha: 0.9);
    for (final p in points) {
      final o = projector.toOffset(p);
      canvas.drawCircle(o, 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) {
    return points != old.points ||
        color != old.color ||
        strokeWidth != old.strokeWidth ||
        projector.size != old.projector.size;
  }
}

class _StationPin extends StatelessWidget {
  const _StationPin({this.label, required this.isStart, required this.isEnd});

  final String? label;
  final bool isStart;
  final bool isEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isStart
        ? theme.colorScheme.primary
        : (isEnd ? theme.colorScheme.secondary : Colors.white);
    final fg = (isStart || isEnd) ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (isStart || isEnd) ? Colors.transparent : Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: label == null
          ? const _Dot()
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isStart) const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                if (isEnd) const Icon(Icons.flag_rounded, size: 14, color: Colors.white),
                if (isStart || isEnd) const SizedBox(width: 4),
                Text(label!, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
              ],
            ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
    );
  }
}
