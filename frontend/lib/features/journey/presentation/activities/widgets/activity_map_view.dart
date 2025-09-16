// lib/features/journey/presentation/activities/widgets/activity_map_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'activity_card.dart';

class ActivityMapView extends StatefulWidget {
  const ActivityMapView({
    super.key,
    required this.activities,
    this.initialCenter,
    this.initialZoom = 12.0,
    this.onSelect,
    this.mapHeight = 320,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.tileSubdomains = const ['a', 'b', 'c'],
  });

  /// A list of activity maps with keys:
  /// { id, title, lat, lng, imageUrl?, rating?, ratingCount?, priceFrom?, currency?, durationLabel?, locationLabel? }
  final List<Map<String, dynamic>> activities;

  /// Center of the map; if null, centers on the first valid marker.
  final LatLng? initialCenter;

  /// Initial zoom level for the map.
  final double initialZoom;

  /// Callback when a marker is selected.
  final void Function(Map<String, dynamic> activity)? onSelect;

  /// Fixed height for the embedded map.
  final double mapHeight;

  /// Tile layer URL template (defaults to OpenStreetMap).
  final String tileUrl;

  /// Tile server subdomains.
  final List<String> tileSubdomains;

  @override
  State<ActivityMapView> createState() => _ActivityMapViewState();
}

class _ActivityMapViewState extends State<ActivityMapView> {
  final MapController _mapController = MapController();

  LatLng? _resolveInitialCenter() {
    if (widget.initialCenter != null) return widget.initialCenter;
    for (final a in widget.activities) {
      final lat = _asDouble(a['lat']);
      final lng = _asDouble(a['lng']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return const LatLng(12.9716, 77.5946); // Bengaluru fallback
  }

  @override
  Widget build(BuildContext context) {
    final center = _resolveInitialCenter();

    return SizedBox(
      height: widget.mapHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center!,
            initialZoom: widget.initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: widget.tileUrl,
              subdomains: widget.tileSubdomains,
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(markers: _buildMarkers(context)),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers(BuildContext context) {
    final markers = <Marker>[];
    for (final a in widget.activities) {
      final lat = _asDouble(a['lat']);
      final lng = _asDouble(a['lng']);
      if (lat == null || lng == null) continue;

      final point = LatLng(lat, lng);
      markers.add(
        Marker(
          point: point,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => _onMarkerTap(context, a),
            child: _MarkerDot(label: null),
          ),
        ),
      );
    }
    return markers;
  }

  void _onMarkerTap(BuildContext context, Map<String, dynamic> activity) {
    widget.onSelect?.call(activity);
    // Use a modal bottom sheet to show the activity card in-place
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ActivityCard(
                id: (activity['id'] ?? '').toString(),
                title: (activity['title'] ?? '').toString(),
                imageUrl: activity['imageUrl'] as String?,
                rating: _asDouble(activity['rating']),
                ratingCount: _asInt(activity['ratingCount']),
                priceFrom: _asNum(activity['priceFrom']),
                currency: (activity['currency'] ?? '₹').toString(),
                durationLabel: activity['durationLabel'] as String?,
                locationLabel: activity['locationLabel'] as String?,
                lat: _asDouble(activity['lat']),
                lng: _asDouble(activity['lng']),
                onTap: () {
                  Navigator.of(ctx).maybePop();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  double? _asDouble(Object? v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  num? _asNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }
}

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -6,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        if (label != null)
          Positioned(
            top: -28,
            child: Material(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  label!,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
