// lib/features/journey/presentation/activities/widgets/activity_map_view.dart

import 'package:flutter/material.dart';

import 'activity_card.dart';

class ActivityMapView extends StatefulWidget {
  const ActivityMapView({
    super.key,
    required this.activities,
    this.initialCenter, // kept for API compatibility
    this.initialZoom = 12.0, // kept for API compatibility
    this.onSelect,
    this.mapHeight = 320,
    this.tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // unused placeholder
    this.tileSubdomains = const ['a', 'b', 'c'], // unused placeholder
  });

  /// A list of activity maps with keys:
  /// { id, title, lat, lng, imageUrl?, rating?, ratingCount?, priceFrom?, currency?, durationLabel?, locationLabel? }
  final List<Map<String, dynamic>> activities;

  /// Center of the map; type kept flexible so callers don’t need changes (ignored in placeholder).
  final Object? initialCenter;

  /// Initial zoom level (ignored in placeholder).
  final double initialZoom;

  /// Callback when a marker is selected.
  final void Function(Map<String, dynamic> activity)? onSelect;

  /// Fixed height for the embedded map.
  final double mapHeight;

  /// Tile layer URL template (kept for signature compatibility).
  final String tileUrl;

  /// Tile server subdomains (kept for signature compatibility).
  final List<String> tileSubdomains;

  @override
  State<ActivityMapView> createState() => _ActivityMapViewState();
}

class _ActivityMapViewState extends State<ActivityMapView> {
  @override
  Widget build(BuildContext context) {
    // “Map-like” placeholder: a rounded panel with a faint grid of tappable dots for each activity that has lat/lng.
    final points = widget.activities.where((a) {
      final lat = _asDouble(a['lat']);
      final lng = _asDouble(a['lng']);
      return lat != null && lng != null;
    }).toList();

    return SizedBox(
      height: widget.mapHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surfaceContainerHighest,
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: points.isEmpty
              ? const Center(child: Text('Map preview unavailable')) // graceful fallback without external deps
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: points.length,
                    itemBuilder: (context, i) {
                      final a = points[i];
                      return GestureDetector(
                        onTap: () => _onMarkerTap(context, a),
                        child: const _MarkerDot(label: null),
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  void _onMarkerTap(BuildContext context, Map<String, dynamic> activity) {
    widget.onSelect?.call(activity);
    // Use a modal bottom sheet to show the activity card in-place.
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
