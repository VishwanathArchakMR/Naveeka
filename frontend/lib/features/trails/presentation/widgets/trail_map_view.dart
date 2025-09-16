// lib/features/trails/presentation/widgets/trail_map_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../trails/data/trail_location_api.dart' show GeoPoint;

/// A compact map view for trails:
/// - Draws polyline geometry and start/end markers
/// - Fits camera to bounds of the trail
/// - Overlay controls to recenter and switch map type
/// - Uses Color.withValues (no withOpacity) and const where possible
class TrailMapView extends StatefulWidget {
  const TrailMapView({
    super.key,
    this.geometry = const <GeoPoint>[],
    this.trailheads = const <GeoPoint>[],
    this.markers = const <GeoPoint>[],
    this.initialCenter,
    this.initialZoom = 12,
    this.strokeColor = Colors.blue,
    this.strokeWidth = 4,
    this.padding = const EdgeInsets.all(12),
    this.onMapCreated,
    this.onTap,
  });

  /// Ordered polyline points of the trail.
  final List<GeoPoint> geometry;

  /// Typically start/end or key trailheads; if not provided, start/end of geometry are used.
  final List<GeoPoint> trailheads;

  /// Optional extra markers (POIs, viewpoints, etc.).
  final List<GeoPoint> markers;

  /// Fallback center if geometry is empty.
  final GeoPoint? initialCenter;

  /// Fallback zoom if geometry is empty.
  final double initialZoom;

  /// Polyline color.
  final Color strokeColor;

  /// Polyline stroke width in px.
  final int strokeWidth;

  /// Safe insets for map overlays and fit-to-bounds padding.
  final EdgeInsets padding;

  /// Hook for external controller usage.
  final void Function(GoogleMapController controller)? onMapCreated;

  /// Tap callback on the map surface.
  final void Function(LatLng latLng)? onTap;

  @override
  State<TrailMapView> createState() => _TrailMapViewState();
}

class _TrailMapViewState extends State<TrailMapView> {
  GoogleMapController? _controller;
  MapType _mapType = MapType.terrain; // default terrain for outdoors

  // Internal caches
  final Set<Marker> _markerSet = <Marker>{};
  final Set<Polyline> _polySet = <Polyline>{};
  bool _fitDone = false;

  @override
  void initState() {
    super.initState();
    _buildOverlays();
  }

  @override
  void didUpdateWidget(covariant TrailMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geometry != widget.geometry ||
        oldWidget.trailheads != widget.trailheads ||
        oldWidget.markers != widget.markers ||
        oldWidget.strokeColor != widget.strokeColor ||
        oldWidget.strokeWidth != widget.strokeWidth) {
      _buildOverlays();
      // Re-fit on updates
      _fitDone = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToBoundsIfPossible());
    }
  }

  void _buildOverlays() {
    _polySet
      ..clear()
      ..add(Polyline(
        polylineId: const PolylineId('trail-geometry'),
        points: widget.geometry.map((p) => LatLng(p.lat, p.lng)).toList(growable: false),
        width: widget.strokeWidth,
        color: widget.strokeColor,
        geodesic: true,
      ));

    _markerSet.clear();

    // Start/end markers from geometry if available
    if (widget.geometry.isNotEmpty) {
      final start = widget.geometry.first;
      final end = widget.geometry.last;
      _markerSet.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(start.lat, start.lng),
        infoWindow: const InfoWindow(title: 'Start'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
      _markerSet.add(Marker(
        markerId: const MarkerId('end'),
        position: LatLng(end.lat, end.lng),
        infoWindow: const InfoWindow(title: 'End'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    // Explicit trailheads (if provided)
    for (var i = 0; i < widget.trailheads.length; i++) {
      final t = widget.trailheads[i];
      _markerSet.add(Marker(
        markerId: MarkerId('trailhead-$i'),
        position: LatLng(t.lat, t.lng),
        infoWindow: InfoWindow(title: i == 0 ? 'Trailhead' : 'Point ${i + 1}'),
      ));
    }

    // POI markers
    for (var i = 0; i < widget.markers.length; i++) {
      final p = widget.markers[i];
      _markerSet.add(Marker(
        markerId: MarkerId('poi-$i'),
        position: LatLng(p.lat, p.lng),
      ));
    }
  }

  CameraPosition _initialCamera() {
    if (widget.geometry.isNotEmpty) {
      final mid = widget.geometry[widget.geometry.length ~/ 2];
      return CameraPosition(target: LatLng(mid.lat, mid.lng), zoom: 13);
    }
    final c = widget.initialCenter ?? const GeoPoint(37.773972, -122.431297); // SF fallback
    return CameraPosition(target: LatLng(c.lat, c.lng), zoom: widget.initialZoom);
  }

  Future<void> _fitToBoundsIfPossible() async {
    if (_fitDone || _controller == null) return;
    final all = <LatLng>[
      ...widget.geometry.map((p) => LatLng(p.lat, p.lng)),
      ...widget.trailheads.map((p) => LatLng(p.lat, p.lng)),
      ...widget.markers.map((p) => LatLng(p.lat, p.lng)),
    ];
    if (all.isEmpty) return;

    final bounds = _computeBounds(all);
    try {
      await _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, _fitPadding(widget.padding)),
      );
      _fitDone = true;
    } catch (_) {
      // Some devices need a small delay before fitting bounds after creation
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted && _controller != null) {
        await _controller!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, _fitPadding(widget.padding)),
        );
        _fitDone = true;
      }
    }
  }

  LatLngBounds _computeBounds(List<LatLng> pts) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = (minLat == null) ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = (maxLat == null) ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = (minLng == null) ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = (maxLng == null) ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  double _fitPadding(EdgeInsets insets) {
    // Use average of horizontal/vertical for a single padding value expected by CameraUpdate.newLatLngBounds.
    final avg = (insets.left + insets.right + insets.top + insets.bottom) / 4.0;
    return avg.clamp(24.0, 160.0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        GoogleMap(
          mapType: _mapType,
          initialCameraPosition: _initialCamera(),
          polylines: _polySet,
          markers: _markerSet,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
          onTap: widget.onTap,
          onMapCreated: (c) {
            _controller = c;
            widget.onMapCreated?.call(c);
            // Fit after a tick to ensure tiles/layout are ready
            WidgetsBinding.instance.addPostFrameCallback((_) => _fitToBoundsIfPossible());
          },
        ),

        // Top-right controls
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _RoundIconButton(
                icon: Icons.my_location,
                tooltip: 'Recenter',
                onTap: _fitToBoundsIfPossible,
              ),
              const SizedBox(height: 8),
              _MapTypeToggle(
                mapType: _mapType,
                onChanged: (t) => setState(() => _mapType = t),
              ),
            ],
          ),
        ),

        // Bottom-left info (distance hint if geometry exists)
        if (widget.geometry.isNotEmpty)
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.route, color: cs.onInverseSurface, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.geometry.length} pts',
                    style: TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Tooltip(message: tooltip, child: Icon(icon, color: Colors.white, size: 20)),
        ),
      ),
    );
  }
}

class _MapTypeToggle extends StatelessWidget {
  const _MapTypeToggle({required this.mapType, required this.onChanged});
  final MapType mapType;
  final ValueChanged<MapType> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    MapType next(MapType t) {
      switch (t) {
        case MapType.normal:
          return MapType.terrain;
        case MapType.terrain:
          return MapType.satellite;
        case MapType.satellite:
          return MapType.hybrid;
        case MapType.hybrid:
          return MapType.normal;
        default:
          return MapType.terrain;
      }
    }

    String label(MapType t) {
      switch (t) {
        case MapType.normal:
          return 'Normal';
        case MapType.terrain:
          return 'Terrain';
        case MapType.satellite:
          return 'Satellite';
        case MapType.hybrid:
          return 'Hybrid';
        default:
          return 'Map';
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(next(mapType)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers, color: cs.onInverseSurface, size: 16),
            const SizedBox(width: 6),
            Text(label(mapType), style: TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
