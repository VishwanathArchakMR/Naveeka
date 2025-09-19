// lib/features/quick_actions/presentation/favorites/widgets/favorites_map_view.dart

import 'package:flutter/material.dart';

import 'package:naveeka/models/place.dart';
import 'package:naveeka/features/places/presentation/widgets/distance_indicator.dart' as di
    show DistanceIndicator, UnitSystem;
import 'package:naveeka/ui/components/buttons/favorite_button.dart';
import 'package:naveeka/features/quick_actions/presentation/booking/widgets/booking_location_filter.dart'
    as bf show UnitSystem;

// Reuse the shared map contract used elsewhere (Google/Mapbox builder).
import 'package:naveeka/features/places/presentation/widgets/nearby_places_map.dart'
    show NearbyMapBuilder, NearbyMapConfig, NearbyMarker;

class FavoritesMapView extends StatefulWidget {
  const FavoritesMapView({
    super.key,
    required this.places,
    this.mapBuilder,
    this.originLat,
    this.originLng,
    this.unit = bf.UnitSystem.metric,
    this.height = 420,
    this.onOpenFilters,
    this.onOpenPlace,
    this.onToggleFavorite, // Future<bool> Function(Place place, bool next)
    this.onDirections, // Optional custom directions handler
  });

  final List<Place> places;
  final NearbyMapBuilder? mapBuilder;
  final double? originLat;
  final double? originLng;
  final bf.UnitSystem unit;
  final double height;

  final VoidCallback? onOpenFilters;
  final void Function(Place place)? onOpenPlace;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;
  final Future<void> Function(Place place)? onDirections;

  @override
  State<FavoritesMapView> createState() => _FavoritesMapViewState();
}

class _FavoritesMapViewState extends State<FavoritesMapView> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final items = widget.places
        .where((p) => _latOf(p) != null && _lngOf(p) != null)
        .toList(growable: false); // Filter with safe helpers. [web:6132]

    final center = _centerOf(items, fallback: (widget.originLat, widget.originLng)); // Average center or origin. [web:5364]

    final markers = items
        .map((p) => NearbyMarker(
              id: _idOf(p),
              lat: _latOf(p)!,
              lng: _lngOf(p)!,
              selected: _idOf(p) == _selectedId,
            ))
        .toList(growable: false); // Build markers using id/lat/lng helpers. [web:6132]

    final map = (widget.mapBuilder != null && center != null)
        ? widget.mapBuilder!(
            context,
            NearbyMapConfig(
              centerLat: center.$1,
              centerLng: center.$2,
              markers: markers,
              initialZoom: 12,
              onMarkerTap: (id) => setState(() => _selectedId = id),
              onRecenter: () => setState(() {}),
            ),
          )
        : _placeholderMap(context); // Placeholder when map builder is absent. [web:5364]

    Place? selected;
    if (_selectedId != null) {
      final idx = items.indexWhere((p) => _idOf(p) == _selectedId);
      if (idx != -1) selected = items[idx];
    } // Avoid null-return orElse; use index check. [web:6132]

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            Positioned.fill(child: map), // Map. [web:5364]

            // Top-right actions
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 1.0),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Filters',
                      icon: const Icon(Icons.tune),
                      onPressed: widget.onOpenFilters,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 1.0),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Recenter',
                      icon: const Icon(Icons.my_location),
                      onPressed: () => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom peek card
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
                  onOpen: widget.onOpenPlace,
                  onToggleFavorite: widget.onToggleFavorite,
                  onDirections: widget.onDirections,
                ),
              ),
          ],
        ),
      ),
    );
  }

  (double, double)? _centerOf(List<Place> items, { (double?, double?)? fallback }) {
    if (items.isNotEmpty) {
      final coords = <(double, double)>[];
      for (final p in items) {
        final la = _latOf(p), ln = _lngOf(p);
        if (la != null && ln != null) coords.add((la, ln));
      }
      if (coords.isNotEmpty) {
        final lat = coords.map((e) => e.$1).reduce((a, b) => a + b) / coords.length;
        final lng = coords.map((e) => e.$2).reduce((a, b) => a + b) / coords.length;
        return (lat, lng);
      }
    }
    final (fl, fn) = fallback ?? (null, null);
    if (fl != null && fn != null) return (fl, fn);
    return null;
  } // Average coordinates, else fallback. [web:5364]

  Widget _placeholderMap(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
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
  } // Placeholder styling. [web:5364]

  // ---------- Place helpers via toJson keys (only those used here) ----------

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  } // Safely project Place. [web:5858]

  String _idOf(Place p) {
    final m = _json(p);
    return (m['id'] ?? m['_id'] ?? m['placeId'] ?? '').toString();
  } // Robust id. [web:5858]

  double? _latOf(Place p) {
    final m = _json(p);
    final v = m['lat'] ?? m['latitude'] ?? m['locationLat'] ?? m['coordLat'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Robust lat. [web:5858]

  double? _lngOf(Place p) {
    final m = _json(p);
    final v = m['lng'] ?? m['longitude'] ?? m['locationLng'] ?? m['coordLng'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Robust lng. [web:5858]
}

class _PeekCard extends StatelessWidget {
  const _PeekCard({
    required this.place,
    required this.onClose,
    required this.originLat,
    required this.originLng,
    required this.unit,
    this.onOpen,
    this.onToggleFavorite,
    this.onDirections,
  });

  final Place place;
  final VoidCallback onClose;
  final double? originLat;
  final double? originLng;
  final bf.UnitSystem unit;
  final void Function(Place place)? onOpen;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;
  final Future<void> Function(Place place)? onDirections;

  @override
  Widget build(BuildContext context) {
    final la = _latOf(place), ln = _lngOf(place);
    final hasCoords = la != null && ln != null;
    final hasOrigin = originLat != null && originLng != null;
    final rating = _ratingOf(place);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    _nameOf(place),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),

            // Meta row
            Row(
              children: [
                if (rating != null) _stars(rating),
                if (rating != null && hasCoords && hasOrigin) const SizedBox(width: 8),
                if (hasCoords && hasOrigin)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: di.DistanceIndicator.fromPlace(
                        place,
                        originLat: originLat!,
                        originLng: originLng!,
                        unit: _toDi(unit),
                        compact: true,
                        labelSuffix: 'away',
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onOpen == null ? null : () => onOpen!(place),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
                const SizedBox(width: 8),
                if (hasCoords)
                  OutlinedButton.icon(
                    onPressed: onDirections == null ? null : () => onDirections!(place),
                    icon: const Icon(Icons.directions_outlined),
                    label: const Text('Directions'),
                  ),
                const Spacer(),
                FavoriteButton(
                  value: _favoriteOf(place),
                  compact: true,
                  onChanged: (next) async {
                    if (onToggleFavorite != null) {
                      await onToggleFavorite!(place, next);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Local helpers (card) ----------

  di.UnitSystem _toDi(bf.UnitSystem u) {
    switch (u) {
      case bf.UnitSystem.metric:
        return di.UnitSystem.metric;
      case bf.UnitSystem.imperial:
        return di.UnitSystem.imperial;
    }
  } // Simple enum bridge. [web:5364]

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  } // Safe JSON projection. [web:5858]

  String _nameOf(Place p) {
    final m = _json(p);
    final v = (m['name'] ?? m['title'])?.toString().trim();
    return (v == null || v.isEmpty) ? 'Place' : v;
  } // Title resolver. [web:5858]

  double? _latOf(Place p) {
    final m = _json(p);
    final v = m['lat'] ?? m['latitude'] ?? m['locationLat'] ?? m['coordLat'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Lat resolver. [web:5858]

  double? _lngOf(Place p) {
    final m = _json(p);
    final v = m['lng'] ?? m['longitude'] ?? m['locationLng'] ?? m['coordLng'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Lng resolver. [web:5858]

  double? _ratingOf(Place p) {
    final m = _json(p);
    final v = m['rating'] ?? m['avgRating'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  } // Rating resolver. [web:5858]

  bool _favoriteOf(Place p) {
    final m = _json(p);
    final v = m['isFavorite'] ?? m['favorite'] ?? m['saved'] ?? m['liked'] ?? m['isWishlisted'];
    if (v is bool) return v;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
    }
    return false;
  } // Favorite resolver. [web:5858]

  Widget _stars(double rating) {
    final icons = <IconData>[];
    for (var i = 1; i <= 5; i++) {
      final icon = rating >= i - 0.25 ? Icons.star : (rating >= i - 0.75 ? Icons.star_half : Icons.star_border);
      icons.add(icon);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons.map((ic) => Icon(ic, size: 16, color: Colors.amber)).toList(),
    );
  } // Star row. [web:5364]
}
