// lib/features/quick_actions/presentation/booking/widgets/booking_map_view.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import '../../../../features/places/presentation/widgets/directions_button.dart';
import '../../../../features/places/presentation/widgets/distance_indicator.dart';

// Reuse the shared map builder contract if present in your app.
// This keeps your map implementation (Google/Mapbox) decoupled from UI widgets.
import '../../../../features/places/presentation/widgets/nearby_places_map.dart'
    show NearbyMapBuilder, NearbyMapConfig, NearbyMarker;

/// A full-bleed map widget for booking discovery:
/// - Pluggable mapBuilder (Google/Mapbox) via NearbyMapBuilder
/// - Markers from places with selection state
/// - Top-right actions: Filters and Recenter
/// - Bottom "peek" card: name, rating, distance, next availability, and booking action
class BookingMapView extends StatefulWidget {
  const BookingMapView({
    super.key,
    required this.places,
    this.mapBuilder,
    this.originLat,
    this.originLng,
    this.height = 420,
    this.onOpenFilters,
    this.onOpenPlace,
    this.onBook,
    this.nextAvailableById,
  });

  /// Places to display as markers; lat/lng should be populated for mapping.
  final List<Place> places;

  /// Map builder hook (Google/Mapbox), same contract used elsewhere in the app.
  final NearbyMapBuilder? mapBuilder;

  /// Optional origin coordinates for distance indicator.
  final double? originLat;
  final double? originLng;

  /// Fixed height if used in a card; use MediaQuery to make it full screen in a page.
  final double height;

  /// Open filters (e.g., BookingLocationFilterSheet or custom).
  final VoidCallback? onOpenFilters;

  /// Open the details page for a place.
  final void Function(Place place)? onOpenPlace;

  /// Initiate booking/availability flow for a place.
  final Future<void> Function(Place place)? onBook;

  /// Precomputed next availability (if fetched), keyed by place.id.
  final Map<String, DateTime>? nextAvailableById;

  @override
  State<BookingMapView> createState() => _BookingMapViewState();
}

class _BookingMapViewState extends State<BookingMapView> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final data = widget.places.where((p) => p.lat != null && p.lng != null).toList(growable: false);
    final markers = data
        .map((p) => NearbyMarker(
              id: p.id.toString(),
              lat: p.lat!,
              lng: p.lng!,
              selected: p.id.toString() == _selectedId,
            ))
        .toList(growable: false);

    final center = _centerOf(data);
    final map = widget.mapBuilder != null && center != null
        ? widget.mapBuilder!(
            context,
            NearbyMapConfig(
              centerLat: center.$1,
              centerLng: center.$2,
              markers: markers,
              initialZoom: 12,
              onMarkerTap: _onMarkerTap,
              onRecenter: _recenter,
            ),
          )
        : _placeholderMap(context);

    final selected = _selectedId == null
        ? null
        : data.firstWhere(
            (p) => p.id.toString() == _selectedId,
            orElse: () => data.isEmpty ? null : data.first,
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

            // Top-right actions: Filters + Recenter
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Filters',
                      icon: const Icon(Icons.tune),
                      onPressed: widget.onOpenFilters,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Recenter',
                      icon: const Icon(Icons.my_location),
                      onPressed: _recenter,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom peek card on selection
            if (selected != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _PeekBookingCard(
                  place: selected,
                  originLat: widget.originLat,
                  originLng: widget.originLng,
                  nextAt: widget.nextAvailableById?[selected.id.toString()],
                  onClose: () => setState(() => _selectedId = null),
                  onOpen: widget.onOpenPlace,
                  onBook: widget.onBook,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onMarkerTap(String id) {
    setState(() => _selectedId = id);
  }

  void _recenter() {
    // Camera recenter is handled by the injected map via NearbyMapConfig.onRecenter.
    setState(() {});
  }

  (double, double)? _centerOf(List<Place> items) {
    if (items.isEmpty) return null;
    final lat = items.map((e) => e.lat!).reduce((a, b) => a + b) / items.length;
    final lng = items.map((e) => e.lng!).reduce((a, b) => a + b) / items.length;
    return (lat, lng);
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

class _PeekBookingCard extends StatelessWidget {
  const _PeekBookingCard({
    required this.place,
    required this.onClose,
    required this.originLat,
    required this.originLng,
    this.nextAt,
    this.onOpen,
    this.onBook,
  });

  final Place place;
  final VoidCallback onClose;
  final double? originLat;
  final double? originLng;
  final DateTime? nextAt;
  final void Function(Place place)? onOpen;
  final Future<void> Function(Place place)? onBook;

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
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),

            // Meta row: rating + distance
            Row(
              children: [
                if (place.rating != null) _stars(place.rating!),
                if (place.rating != null && hasCoords && hasOrigin) const SizedBox(width: 8),
                if (hasOrigin && hasCoords)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: DistanceIndicator.fromPlace(
                        place,
                        originLat: originLat!,
                        originLng: originLng!,
                        unit: UnitSystem.metric,
                        compact: true,
                        labelSuffix: 'away',
                      ),
                    ),
                  ),
              ],
            ),

            // Next availability
            if (nextAt != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Next available: ${_fmtDateTime(context, nextAt!)}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ],

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
                    onPressed: () => DirectionsButton.fromPlace(
                      place,
                      mode: TravelMode.walking,
                      label: 'Directions',
                      expanded: false,
                    ).onPressed?.call(),
                    icon: const Icon(Icons.directions_outlined),
                    label: const Text('Directions'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onBook == null ? null : () => onBook!(place),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Check availability'),
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
      final icon = rating >= i - 0.25
          ? Icons.star
          : (rating >= i - 0.75 ? Icons.star_half : Icons.star_border);
      icons.add(icon);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons.map((ic) => Icon(ic, size: 16, color: Colors.amber)).toList(),
    );
  }

  String _fmtDateTime(BuildContext context, DateTime dt) {
    final local = dt.toLocal();
    final date = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time = TimeOfDay.fromDateTime(local);
    final tstr = MaterialLocalizations.of(context).formatTimeOfDay(time);
    return '$date · $tstr';
  }
}
