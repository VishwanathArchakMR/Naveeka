// lib/features/places/presentation/widgets/nearby_places_map.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import 'distance_indicator.dart';
import 'directions_button.dart';
import 'favorite_heart_button.dart';

typedef MarkerTap = void Function(String placeId);
typedef NearbyMapBuilder = Widget Function(
    BuildContext context, NearbyMapConfig config);

/// Configuration passed to the injected map builder so it can draw pins and wire callbacks.
class NearbyMapConfig {
  const NearbyMapConfig({
    required this.centerLat,
    required this.centerLng,
    required this.markers,
    required this.onMarkerTap,
    required this.onRecenter,
    this.initialZoom = 14,
  });

  final double centerLat;
  final double centerLng;
  final List<NearbyMarker> markers;
  final void Function(String placeId) onMarkerTap;
  final VoidCallback onRecenter;
  final double initialZoom;
}

/// Marker description for the underlying map widget.
class NearbyMarker {
  const NearbyMarker({
    required this.id,
    required this.lat,
    required this.lng,
    this.selected = false,
  });

  final String id;
  final double lat;
  final double lng;
  final bool selected;
}

/// A composable map + places overlay:
/// - Inject a map via [mapBuilder] (e.g., GoogleMap/Mapbox) using [NearbyMapConfig].
/// - Shows a recenter button and optional refresh.
/// - Tapping a pin selects a place and shows a peek card with actions.
class NearbyPlacesMap extends StatefulWidget {
  const NearbyPlacesMap({
    super.key,
    required this.centerLat,
    required this.centerLng,
    required this.places,
    this.originLat,
    this.originLng,
    this.unit = UnitSystem.metric,
    this.mapBuilder,
    this.initialZoom = 14,
    this.onRefresh,
    this.onSelectPlace,
    this.onToggleFavorite,
  });

  final double centerLat;
  final double centerLng;
  final List<Place> places;

  /// Optional origin for distance labels.
  final double? originLat;
  final double? originLng;
  final UnitSystem unit;

  /// Inject an actual map implementation here (e.g., GoogleMap).
  final NearbyMapBuilder? mapBuilder;

  final double initialZoom;

  /// Pull or button-triggered refresh for nearby results.
  final Future<void> Function()? onRefresh;

  /// Optional selection handler.
  final void Function(Place place)? onSelectPlace;

  /// Favorite toggle handler for the peek card heart.
  final Future<bool> Function(bool next)? onToggleFavorite;

  @override
  State<NearbyPlacesMap> createState() => _NearbyPlacesMapState();
}

class _NearbyPlacesMapState extends State<NearbyPlacesMap> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final markers = <NearbyMarker>[];
    for (final p in widget.places) {
      final la = _lat(p);
      final ln = _lng(p);
      if (la != null && ln != null) {
        markers.add(NearbyMarker(
          id: p.id.toString(),
          lat: la,
          lng: ln,
          selected: p.id.toString() == _selectedId,
        ));
      }
    }

    final map = widget.mapBuilder != null
        ? widget.mapBuilder!(
            context,
            NearbyMapConfig(
              centerLat: widget.centerLat,
              centerLng: widget.centerLng,
              markers: markers,
              initialZoom: widget.initialZoom,
              onMarkerTap: _onMarkerTap,
              onRecenter: _recenter,
            ),
          )
        : _placeholderMap(
            context); // Provide a graceful fallback if no mapBuilder is supplied.

    final selected = _selectedId == null
        ? null
        : widget.places.firstWhere(
            (p) => p.id.toString() == _selectedId,
            orElse: () => widget.places.first,
          );

    return Stack(
      children: [
        Positioned.fill(child: map),

        // Top-right controls (recenter + refresh)
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _fabIcon(context, Icons.my_location, 'Recenter', _recenter),
              if (widget.onRefresh != null) const SizedBox(height: 8),
              if (widget.onRefresh != null)
                _fabIcon(context, Icons.refresh, 'Refresh', () async {
                  await widget.onRefresh!.call();
                }),
            ],
          ),
        ),

        // Bottom Peek card
        if (selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _PeekCard(
              place: selected,
              originLat: widget.originLat,
              originLng: widget.originLng,
              unit: widget.unit,
              onClose: () => setState(() => _selectedId = null),
              onToggleFavorite: widget.onToggleFavorite,
              onOpen: () => widget.onSelectPlace?.call(selected),
            ),
          ),
      ],
    );
  }

  double? _lat(Place p) {
    try {
      final d = p as dynamic;
      final v = (d.lat ?? d.latitude ?? d.locationLat ?? d.coordLat) as Object?;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  double? _lng(Place p) {
    try {
      final d = p as dynamic;
      final v =
          (d.lng ?? d.longitude ?? d.locationLng ?? d.coordLng) as Object?;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  void _onMarkerTap(String id) {
    setState(() => _selectedId = id);
    final p = widget.places
        .where((e) => e.id.toString() == id)
        .cast<Place?>()
        .firstWhere((e) => e != null, orElse: () => null);
    if (p != null && widget.onSelectPlace != null) {
      widget.onSelectPlace!(p);
    }
  }

  void _recenter() {
    // The injected map should honor NearbyMapConfig.onRecenter; this noop keeps UI consistent even if placeholder is used.
    setState(() {
      // no-op state change; real maps handle camera moves via the builder.
    });
  }

  Widget _placeholderMap(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 40, color: Colors.black26),
          SizedBox(height: 8),
          Text('Map unavailable', style: TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }

  Widget _fabIcon(BuildContext context, IconData icon, String tooltip,
      VoidCallback onPressed) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const CircleBorder(),
      elevation: 1,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

class _PeekCard extends StatelessWidget {
  const _PeekCard({
    required this.place,
    required this.onClose,
    required this.unit,
    this.originLat,
    this.originLng,
    this.onToggleFavorite,
    this.onOpen,
  });

  final Place place;
  final VoidCallback onClose;
  final UnitSystem unit;
  final double? originLat;
  final double? originLng;
  final Future<bool> Function(bool next)? onToggleFavorite;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final hasOrigin = originLat != null && originLng != null;
    final hasCoords = _lat(place) != null && _lng(place) != null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: title + favorite + close
            Row(
              children: [
                Expanded(
                  child: Text(
                    place.name.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (onToggleFavorite != null)
                  FavoriteHeartButton.fromPlace(
                    place: place,
                    onChanged: onToggleFavorite!,
                    compact: true,
                  ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),

            // Subrow: distance + address
            Row(
              children: [
                if (hasOrigin && hasCoords)
                  DistanceIndicator.fromPlace(
                    place,
                    originLat: originLat!,
                    originLng: originLng!,
                    unit: unit,
                    compact: true,
                    labelSuffix: 'away',
                  ),
                if (hasOrigin && hasCoords) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Actions: Directions + More
            Row(
              children: [
                if (hasCoords)
                  DirectionsButton.fromPlace(
                    place,
                    mode: TravelMode.driving,
                    label: 'Directions',
                    expanded: false,
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double? _lat(Place p) {
    try {
      final d = p as dynamic;
      final v = (d.lat ?? d.latitude ?? d.locationLat ?? d.coordLat) as Object?;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  double? _lng(Place p) {
    try {
      final d = p as dynamic;
      final v =
          (d.lng ?? d.longitude ?? d.locationLng ?? d.coordLng) as Object?;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  String _subtitle() {
    Map<String, dynamic> m = const <String, dynamic>{};
    try {
      final dyn = place as dynamic;
      final j = dyn.toJson?.call();
      if (j is Map<String, dynamic>) m = j;
    } catch (_) {}

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final parts = <String>[
      if ((pick(['address', 'formattedAddress', 'addr']) ?? '').isNotEmpty)
        pick(['address', 'formattedAddress', 'addr'])!,
      if ((pick(['city', 'locality']) ?? '').isNotEmpty)
        pick(['city', 'locality'])!,
      if ((pick(['region', 'state']) ?? '').isNotEmpty)
        pick(['region', 'state'])!,
      if ((pick(['country']) ?? '').isNotEmpty) pick(['country'])!,
    ];
    return parts.isEmpty ? '' : parts.join(', ');
  }
}
