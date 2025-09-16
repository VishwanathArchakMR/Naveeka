// lib/features/quick_actions/presentation/favorites/widgets/favorites_map_view.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import '../../../places/presentation/widgets/distance_indicator.dart';
import '../../../../ui/components/buttons/favorite_button.dart';
import '../../../booking/widgets/booking_location_filter.dart' show UnitSystem;

// Reuse the shared map contract used elsewhere (Google/Mapbox builder).
import '../../../places/presentation/widgets/nearby_places_map.dart'
    show NearbyMapBuilder, NearbyMapConfig, NearbyMarker;

/// A full-bleed map for favorite places with:
/// - Pluggable mapBuilder (Google/Mapbox)
/// - Marker selection + bottom peek card
/// - Top-right actions: Filters and Recenter
/// - Uses Color.withValues(...) (no deprecated withOpacity)
class FavoritesMapView extends StatefulWidget {
  const FavoritesMapView({
    super.key,
    required this.places,
    this.mapBuilder,
    this.originLat,
    this.originLng,
    this.unit = UnitSystem.metric,
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
  final UnitSystem unit;
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
    final items = widget.places.where((p) => p.lat != null && p.lng != null).toList(growable: false);
    final center = _centerOf(items, fallback: (widget.originLat, widget.originLng));
    final markers = items
        .map((p) => NearbyMarker(
              id: p.id.toString(),
              lat: p.lat!,
              lng: p.lng!,
              selected: p.id.toString() == _selectedId,
            ))
        .toList(growable: false);

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
        : _placeholderMap(context);

    final selected = _selectedId == null
        ? null
        : items.firstWhere(
            (p) => p.id.toString() == _selectedId,
            orElse: () => items.isEmpty ? null : items.first,
          );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // Map
            Positioned.fill(child: map),

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
      final pts = items.where((e) => e.lat != null && e.lng != null).toList();
      if (pts.isNotEmpty) {
        final lat = pts.map((e) => e.lat!).reduce((a, b) => a + b) / pts.length;
        final lng = pts.map((e) => e.lng!).reduce((a, b) => a + b) / pts.length;
        return (lat, lng);
      }
    }
    final (fl, fn) = fallback ?? (null, null);
    if (fl != null && fn != null) return (fl!, fn!);
    return null;
  }

  Widget _placeholderMap(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.map_outlined, size: 40, color: Colors.black26),
          SizedBox(height: 8),
          Text('Map unavailable', style: TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }
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
  final UnitSystem unit;
  final void Function(Place place)? onOpen;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;
  final Future<void> Function(Place place)? onDirections;

  @override
  Widget build(BuildContext context) {
    final hasCoords = place.lat != null && place.lng != null;
    final hasOrigin = originLat != null && originLng != null;

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
                    (place.name ?? 'Place').trim(),
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
                if (place.rating != null) _stars(place.rating!),
                if (place.rating != null && hasCoords && hasOrigin) const SizedBox(width: 8),
                if (hasCoords && hasOrigin)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: DistanceIndicator.fromPlace(
                        place,
                        originLat: originLat!,
                        originLng: originLng!,
                        unit: unit,
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
                  isFavorite: place.isFavorite ?? (place.isWishlisted ?? false) == true,
                  compact: true,
                  onChanged: onToggleFavorite == null ? null : (next) => onToggleFavorite!(place, next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
  }
}
