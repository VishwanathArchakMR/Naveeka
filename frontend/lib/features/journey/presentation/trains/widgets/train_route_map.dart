// lib/features/journey/presentation/trains/widgets/train_route_map.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TrainRouteMap extends StatelessWidget {
  const TrainRouteMap({
    super.key,
    required this.stops,
    this.height = 220,
    this.initialZoom = 6,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.tileSubdomains = const ['a', 'b', 'c'],
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
    final fallbackCenter = const LatLng(20.5937, 78.9629);

    // Compute bounds for auto-fit; guard single-point case with tiny delta
    LatLngBounds? bounds;
    if (points.isNotEmpty) {
      if (points.length == 1) {
        final p = points.first;
        bounds = LatLngBounds.fromPoints([p, LatLng(p.latitude + 0.0005, p.longitude + 0.0005)]);
      } else {
        bounds = LatLngBounds.fromPoints(points);
      }
    }

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            // Initial framing to include all stops with padding, capped zoom
            cameraFit: bounds != null
                ? CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(24),
                    maxZoom: 10,
                  )
                : CameraFit.coordinates(
                    coordinates: [fallbackCenter],
                    zoom: initialZoom,
                  ),
            initialZoom: initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
            ),
          ), // CameraFit.bounds sets initial view from LatLngBounds with padding and optional maxZoom for a neat frame [9]
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: tileSubdomains,
              userAgentPackageName: 'com.example.app',
            ),
            if (points.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: strokeWidth,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
                polylineCulling: true,
              ), // Draws lines using PolylineLayer from an ordered list of LatLng points, ideal for routes with known stations [2][3]
            MarkerLayer(
              markers: [
                for (int i = 0; i < stops.length; i++)
                  if (_toLatLng(stops[i]['lat'], stops[i]['lng']) != null)
                    _stationMarker(
                      context: context,
                      stop: stops[i],
                      point: _toLatLng(stops[i]['lat'], stops[i]['lng'])!,
                      isStart: i == 0,
                      isEnd: i == stops.length - 1,
                    ),
              ],
            ), // MarkerLayer places arbitrary widgets at station coordinates; tap handling can be added via GestureDetector [13][10]
          ],
        ),
      ),
    );
  }

  Marker _stationMarker({
    required BuildContext context,
    required Map<String, dynamic> stop,
    required LatLng point,
    required bool isStart,
    required bool isEnd,
  }) {
    final code = (stop['code'] ?? '').toString();
    final name = (stop['name'] ?? '').toString();

    return Marker(
      point: point,
      width: showStopLabels ? 68 : 20,
      height: 48,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onTapStop != null ? () => onTapStop!(stop) : null,
        child: _StationPin(
          label: showStopLabels
              ? (code.isNotEmpty ? code : (name.isNotEmpty ? name : '•'))
              : null,
          isStart: isStart,
          isEnd: isEnd,
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
