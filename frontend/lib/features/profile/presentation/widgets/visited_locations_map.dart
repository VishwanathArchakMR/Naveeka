// lib/features/profile/presentation/widgets/visited_locations_map.dart

import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import '../../../places/presentation/widgets/nearby_places_map.dart'
    show NearbyMapBuilder, NearbyMapConfig, NearbyMarker; // Reuse the same map integration contract.
import '../../../places/presentation/widgets/directions_button.dart';
import '../../../places/presentation/widgets/distance_indicator.dart';

class VisitedLocationsMap extends StatefulWidget {
  const VisitedLocationsMap({
    super.key,
    required this.places,
    this.title = 'Visited locations',
    this.mapBuilder,
    this.height = 320,
    this.onRefresh,
    this.onOpenPlace,
    this.originLat,
    this.originLng,
  });

  /// Places the user has visited; coordinates should be present for mapping.
  final List<Place> places;

  /// Section title.
  final String title;

  /// Optional injected map builder (e.g., GoogleMap/Mapbox) that accepts NearbyMapConfig.
  final NearbyMapBuilder? mapBuilder;

  /// Fixed height for the card.
  final double height;

  /// Refresh callback to reload visited places.
  final Future<void> Function()? onRefresh;

  /// Open details for a tapped place.
  final void Function(Place place)? onOpenPlace;

  /// Optional origin for distances in the peek card.
  final double? originLat;
  final double? originLng;

  @override
  State<VisitedLocationsMap> createState() => _VisitedLocationsMapState();
}

class _VisitedLocationsMapState extends State<VisitedLocationsMap> {
  String? _selectedId;
  int? _year; // null => All

  @override
  Widget build(BuildContext context) {
    final data = _filtered(widget.places, _year);
    final markers = data.map((p) {
      final lat = _latOf(p), lng = _lngOf(p);
      if (lat == null || lng == null) return null;
      return NearbyMarker(
        id: _idOf(p),
        lat: lat,
        lng: lng,
        selected: _idOf(p) == _selectedId,
      );
    }).whereType<NearbyMarker>().toList(growable: false);

    final center = _centerOf(data);
    final map = widget.mapBuilder != null && center != null
        ? widget.mapBuilder!(
            context,
            NearbyMapConfig(
              centerLat: center.$1,
              centerLng: center.$2,
              markers: markers,
              initialZoom: 5,
              onMarkerTap: _onMarkerTap,
              onRecenter: _recenter,
            ),
          )
        : _placeholderMap(context);

    final selected = _selectedId == null
        ? null
        : data.cast<Place?>().firstWhere(
              (p) => p != null && _idOf(p) == _selectedId,
              orElse: () => null,
            );

    final years = _yearsFrom(widget.places);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // Map body
            Positioned.fill(child: map),

            // Top bar: title + controls
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  // Title
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const Spacer(),
                  // Recenter
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Recenter',
                      icon: const Icon(Icons.my_location),
                      onPressed: _recenter,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Refresh
                  if (widget.onRefresh != null)
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh),
                        onPressed: () async => widget.onRefresh!.call(),
                      ),
                    ),
                ],
              ),
            ),

            // Filter row (years)
            if (years.isNotEmpty)
              Positioned(
                top: 52,
                left: 8,
                right: 8,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: const Text('All'),
                          selected: _year == null,
                          onSelected: (_) => setState(() => _year = null),
                        ),
                      ),
                      ...years.map(
                        (y) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text('$y'),
                            selected: _year == y,
                            onSelected: (_) => setState(() => _year = y),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  onClose: () => setState(() => _selectedId = null),
                  onOpen: widget.onOpenPlace,
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
    // The injected map should honor NearbyMapConfig.onRecenter (camera move handled by the map implementation).
    setState(() {
      // no-op to trigger overlay updates if needed
    });
  }

  List<Place> _filtered(List<Place> items, int? year) {
    if (year == null) return items;
    return items.where((p) {
      final dt = _visitedAtOf(p);
      return dt != null && dt.year == year;
    }).toList(growable: false);
  }

  (double, double)? _centerOf(List<Place> items) {
    final coords = <(double, double)>[];
    for (final p in items) {
      final lat = _latOf(p), lng = _lngOf(p);
      if (lat != null && lng != null) coords.add((lat, lng));
    }
    if (coords.isEmpty) return null;
    final latAvg = coords.map((e) => e.$1).reduce((a, b) => a + b) / coords.length;
    final lngAvg = coords.map((e) => e.$2).reduce((a, b) => a + b) / coords.length;
    return (latAvg, lngAvg);
  }

  List<int> _yearsFrom(List<Place> items) {
    final s = <int>{};
    for (final p in items) {
      final dt = _visitedAtOf(p);
      if (dt != null) s.add(dt.year);
    }
    final out = s.toList()..sort((a, b) => b.compareTo(a));
    return out;
  }

  // ---------- Place helpers via toJson keys ----------

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  String _idOf(Place p) {
    final m = _json(p);
    return (m['id'] ?? m['_id'] ?? m['placeId'] ?? '').toString();
  }

  double? _latOf(Place p) {
    final m = _json(p);
    final v = m['lat'] ?? m['latitude'] ?? m['locationLat'] ?? m['coordLat'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  double? _lngOf(Place p) {
    final m = _json(p);
    final v = m['lng'] ?? m['longitude'] ?? m['locationLng'] ?? m['coordLng'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  DateTime? _visitedAtOf(Place p) {
    final m = _json(p);
    final v = m['visitedAt'] ?? m['lastVisited'];
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

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
  }
}

class _PeekCard extends StatelessWidget {
  const _PeekCard({
    required this.place,
    required this.onClose,
    required this.originLat,
    required this.originLng,
    this.onOpen,
  });

  final Place place;
  final VoidCallback onClose;
  final double? originLat;
  final double? originLng;
  final void Function(Place place)? onOpen;

  @override
  Widget build(BuildContext context) {
    final lat = _latOf(place), lng = _lngOf(place);
    final hasCoords = lat != null && lng != null;
    final hasOrigin = originLat != null && originLng != null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: title + close
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
                    unit: UnitSystem.metric,
                    compact: true,
                    labelSuffix: 'away',
                  ),
                if (hasOrigin && hasCoords) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _subtitle(place),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Actions: Directions + Open
            Row(
              children: [
                if (hasCoords)
                  DirectionsButton.fromPlace(
                    place,
                    mode: TravelMode.walking,
                    label: 'Directions',
                    expanded: false,
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onOpen == null ? null : () => onOpen!(place),
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

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  String _nameOf(Place p) {
    final m = _json(p);
    final v = (m['name'] ?? m['title'])?.toString().trim();
    return (v == null || v.isEmpty) ? 'Place' : v;
  }

  double? _latOf(Place p) {
    final m = _json(p);
    final v = m['lat'] ?? m['latitude'] ?? m['locationLat'] ?? m['coordLat'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  double? _lngOf(Place p) {
    final m = _json(p);
    final v = m['lng'] ?? m['longitude'] ?? m['locationLng'] ?? m['coordLng'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _subtitle(Place p) {
    final m = _json(p);
    final parts = <String>[];
    void addKey(String k) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) parts.add(v);
    }
    addKey('address');
    addKey('city');
    addKey('region');
    addKey('country');
    return parts.isEmpty ? '' : parts.join(', ');
  }
}
