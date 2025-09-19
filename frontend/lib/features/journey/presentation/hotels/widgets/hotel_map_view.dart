// lib/features/journey/presentation/hotels/widgets/hotel_map_view.dart

import 'package:flutter/material.dart';

class HotelMapView extends StatelessWidget {
  const HotelMapView({
    super.key,
    required this.hotels,
    this.height = 280,
    this.initialZoom = 12, // kept for API compatibility
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // placeholder
    this.tileSubdomains = const ['a', 'b', 'c'], // placeholder
    this.currency = '₹',
    this.onTapHotel,
    this.selectedHotelId,
  });

  /// Expected hotel item shape:
  /// { id, name, lat, lng, price (num)?, rating (double)? }
  final List<Map<String, dynamic>> hotels;

  final double height;
  final double initialZoom; // unused in placeholder
  final String tileUrl; // unused in placeholder
  final List<String> tileSubdomains; // unused in placeholder
  final String currency;

  /// Callback when a marker is tapped.
  final void Function(Map<String, dynamic> hotel)? onTapHotel;

  /// Optionally highlight a selected hotel marker.
  final String? selectedHotelId;

  @override
  Widget build(BuildContext context) {
    // Collect valid points.
    final points = <LatLng>[];
    for (final h in hotels) {
      final p = _toLatLng(h['lat'], h['lng']);
      if (p != null) points.add(p);
    }

    // If no points, create a tiny bbox around India centroid for a neutral view.
    const fallbackCenter = LatLng(20.5937, 78.9629);
    final hasPoints = points.isNotEmpty;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, height);

          // Build projector from either hotel points or a small box around fallback.
          final proj = hasPoints
              ? _Projector.fromPoints(points, size)
              : _Projector.fromPoints(
                  [
                    LatLng(fallbackCenter.latitude - 0.25, fallbackCenter.longitude - 0.25),
                    LatLng(fallbackCenter.latitude + 0.25, fallbackCenter.longitude + 0.25),
                  ],
                  size,
                );

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Backdrop (subtle grid/gradient)
                CustomPaint(
                  size: size,
                  painter: _BackdropPainter(),
                ),

                // Hotel pins
                ...hotels.map((h) {
                  final p = _toLatLng(h['lat'], h['lng']);
                  if (p == null) return const SizedBox.shrink();
                  final o = proj.toOffset(p);
                  final selected = selectedHotelId != null && (h['id']?.toString() ?? '') == selectedHotelId;
                  final price = h['price'];
                  final rating = h['rating'] is num ? (h['rating'] as num).toDouble() : null;
                  final name = (h['name'] ?? '').toString();
                  final label = price is num ? '$currency${price.toStringAsFixed(0)}' : (name.isNotEmpty ? name : 'Hotel');

                  return Positioned(
                    left: o.dx - 32, // center the 64px pin
                    top: o.dy - 32,
                    width: 64,
                    height: 64,
                    child: GestureDetector(
                      onTap: onTapHotel != null ? () => onTapHotel!(h) : null,
                      child: _PricePin(
                        label: label,
                        selected: selected,
                        rating: rating,
                      ),
                    ),
                  );
                }),
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

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Gradient background
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

    // Subtle grid
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
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => false;
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
