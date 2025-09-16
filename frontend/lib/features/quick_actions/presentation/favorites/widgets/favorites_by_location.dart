// lib/features/quick_actions/presentation/favorites/widgets/favorites_by_location.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../models/place.dart';
import '../../../booking/widgets/booking_location_filter.dart';
import '../../../places/presentation/widgets/distance_indicator.dart';
import '../../../favorites/widgets/favorite_button.dart';

// Shared map contract (Google/Mapbox) used across the app.
// If your project already exports these from a central place, import from there instead.
typedef NearbyMapBuilder = Widget Function(BuildContext context, NearbyMapConfig config);

class NearbyMapConfig {
  NearbyMapConfig({
    required this.centerLat,
    required this.centerLng,
    required this.markers,
    this.initialZoom = 11,
    this.onMarkerTap,
    this.onRecenter,
  });
  final double centerLat;
  final double centerLng;
  final List<NearbyMarker> markers;
  final double initialZoom;
  final void Function(String id)? onMarkerTap;
  final VoidCallback? onRecenter;
}

class NearbyMarker {
  NearbyMarker({
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

enum _ViewMode { map, list }

class FavoritesByLocation extends StatefulWidget {
  const FavoritesByLocation({
    super.key,
    required this.places,
    this.sectionTitle = 'Favorites by location',
    this.mapBuilder,
    this.originLat,
    this.originLng,
    this.initialUnit = UnitSystem.metric,
    this.initialRadiusKm = 10.0,
    this.onOpenPlace,
    this.onToggleFavorite, // Future<bool> Function(Place place, bool next)
    this.onPickLocation,   // custom picker override; if null, uses BookingLocationFilterSheet
    this.height = 520,
  });

  final List<Place> places;
  final String sectionTitle;

  final NearbyMapBuilder? mapBuilder;
  final double? originLat;
  final double? originLng;

  final UnitSystem initialUnit;
  final double initialRadiusKm;

  final void Function(Place place)? onOpenPlace;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;

  final Future<BookingLocationSelection?> Function()? onPickLocation;

  final double height;

  @override
  State<FavoritesByLocation> createState() => _FavoritesByLocationState();
}

class _FavoritesByLocationState extends State<FavoritesByLocation> {
  _ViewMode _mode = _ViewMode.map;
  UnitSystem _unit = UnitSystem.metric;
  double? _originLat;
  double? _originLng;
  double _radiusKm = 10.0;
  String? _selectedMarkerId;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
    _originLat = widget.originLat;
    _originLng = widget.originLng;
    _radiusKm = widget.initialRadiusKm;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered(widget.places, _originLat, _originLng, _radiusKm);
    final center = _centerOf(filtered, fallback: (_originLat, _originLng));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cs.surfaceContainerHighest,
      child: SizedBox(
        height: widget.height,
        child: Column(
          children: [
            // Header + controls
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.sectionTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  // View toggle
                  SegmentedButton<_ViewMode>(
                    segments: const [
                      ButtonSegment(value: _ViewMode.map, label: Text('Map'), icon: Icon(Icons.map_outlined)),
                      ButtonSegment(value: _ViewMode.list, label: Text('List'), icon: Icon(Icons.list_alt_outlined)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                ],
              ),
            ),

            // Filter row (location + radius + unit toggle)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  // Location chooser
                  OutlinedButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.place_outlined),
                    label: Text(_locationLabel()),
                  ),
                  const SizedBox(width: 8),
                  // Unit
                  SegmentedButton<UnitSystem>(
                    segments: const [
                      ButtonSegment(value: UnitSystem.metric, label: Text('km')),
                      ButtonSegment(value: UnitSystem.imperial, label: Text('mi')),
                    ],
                    selected: {_unit},
                    onSelectionChanged: (s) => setState(() => _unit = s.first),
                  ),
                  const Spacer(),
                  // Radius display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.radar, size: 16),
                        const SizedBox(width: 6),
                        Text(_radiusLabel()),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _mode == _ViewMode.map
                  ? _buildMap(context, filtered, center)
                  : _buildList(context, filtered),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Map ----------------

  Widget _buildMap(BuildContext context, List<Place> items, (double, double)? center) {
    final cs = Theme.of(context).colorScheme;

    if (widget.mapBuilder == null || center == null) {
      return _placeholderMap(context);
    }

    final markers = items
        .where((p) => p.lat != null && p.lng != null)
        .map((p) => NearbyMarker(
              id: p.id.toString(),
              lat: p.lat!,
              lng: p.lng!,
              selected: p.id.toString() == _selectedMarkerId,
            ))
        .toList(growable: false);

    final selected = _selectedMarkerId == null
        ? null
        : items.firstWhere(
            (p) => p.id.toString() == _selectedMarkerId,
            orElse: () => items.isEmpty ? null : items.first,
          );

    return Stack(
      children: [
        Positioned.fill(
          child: widget.mapBuilder!(
            context,
            NearbyMapConfig(
              centerLat: center.$1,
              centerLng: center.$2,
              markers: markers,
              initialZoom: 11,
              onMarkerTap: (id) => setState(() => _selectedMarkerId = id),
              onRecenter: () => setState(() {}),
            ),
          ),
        ),
        if (selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _PeekCard(
              place: selected,
              originLat: _originLat,
              originLng: _originLng,
              unit: _unit,
              onClose: () => setState(() => _selectedMarkerId = null),
              onOpen: widget.onOpenPlace,
              onToggleFavorite: widget.onToggleFavorite,
            ),
          ),
        // Visual radius hint (badge)
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 1.0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('Radius: ${_radiusLabel()}'),
          ),
        ),
      ],
    ); // Map is delegated to a pluggable builder (Google/Mapbox) to reuse the existing integration reliably. [1][3]
  }

  // ---------------- List ----------------

  Widget _buildList(BuildContext context, List<Place> items) {
    // Group by city/region/country
    final groups = <String, List<Place>>{};
    for (final p in items) {
      final key = _placeKey(p);
      groups.putIfAbsent(key, () => <Place>[]).add(p);
    }
    final keys = groups.keys.toList()..sort();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: keys.length,
      separatorBuilder: (_, __) => const Divider(height: 0),
      itemBuilder: (context, i) {
        final k = keys[i];
        final list = groups[k]!..sort((a, b) => _distance(a).compareTo(_distance(b)));
        return _CitySection(
          title: k,
          unit: _unit,
          originLat: _originLat,
          originLng: _originLng,
          places: list,
          onOpen: widget.onOpenPlace,
          onToggleFavorite: widget.onToggleFavorite,
        );
      },
    ); // ListView.separated provides clear section separation with stable performance for large lists. [4][5]
  }

  // ---------------- Helpers ----------------

  Future<void> _pickLocation() async {
    if (widget.onPickLocation != null) {
      final sel = await widget.onPickLocation!.call();
      if (sel != null) {
        setState(() {
          _unit = sel.unit;
          _radiusKm = sel.radiusKm ?? _radiusKm;
          _originLat = sel.lat ?? _originLat;
          _originLng = sel.lng ?? _originLng;
        });
      }
      return;
    }
    // Default sheet
    final sel = await BookingLocationFilterSheet.show(
      context,
      initial: BookingLocationSelection(
        mode: _originLat == null ? LocationMode.nearMe : LocationMode.mapPin,
        lat: _originLat,
        lng: _originLng,
        radiusKm: _radiusKm,
        unit: _unit,
      ),
      onResolveCurrentLocation: () async {
        // TODO: resolve device location
        return _originLat != null && _originLng != null ? GeoPoint(_originLat!, _originLng!) : null;
      },
      onPickOnMap: () async {
        // TODO: open map picker
        return _originLat != null && _originLng != null ? GeoPoint(_originLat!, _originLng!) : null;
      },
      minKm: 0.5,
      maxKm: 50,
    );
    if (sel != null) {
      setState(() {
        _unit = sel.unit;
        _radiusKm = sel.radiusKm ?? _radiusKm;
        _originLat = sel.lat ?? _originLat;
        _originLng = sel.lng ?? _originLng;
      });
    }
  } // Location filter reuses the bottom-sheet picker to keep UX consistent across booking/favorites flows. [6]

  String _locationLabel() {
    if (_originLat == null || _originLng == null) return 'Set location';
    return 'Location set';
  }

  String _radiusLabel() {
    final v = _unit == UnitSystem.metric ? _radiusKm : _radiusKm * 0.621371;
    final unit = _unit == UnitSystem.metric ? 'km' : 'mi';
    return v >= 10 ? '${v.toStringAsFixed(0)} $unit' : '${v.toStringAsFixed(1)} $unit';
  }

  String _placeKey(Place p) {
    final parts = <String>[
      (p.city ?? '').trim(),
      (p.region ?? '').trim(),
      (p.country ?? '').trim(),
    ].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'Unknown' : parts.join(', ');
  }

  double _distance(Place p) {
    if (_originLat == null || _originLng == null || p.lat == null || p.lng == null) return double.infinity;
    final d = _haversine(_originLat!, _originLng!, p.lat!, p.lng!);
    return _unit == UnitSystem.metric ? d : d * 0.621371;
  }

  List<Place> _filtered(List<Place> src, double? lat, double? lng, double radiusKm) {
    if (lat == null || lng == null) return src;
    return src.where((p) {
      if (p.lat == null || p.lng == null) return false;
      final d = _haversine(lat, lng, p.lat!, p.lng!);
      return d <= radiusKm;
    }).toList(growable: false);
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

  // Haversine distance in km
  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  Widget _placeholderMap(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHigh,
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

// ---------------- Sections and tiles ----------------

class _CitySection extends StatelessWidget {
  const _CitySection({
    required this.title,
    required this.places,
    required this.unit,
    required this.originLat,
    required this.originLng,
    this.onOpen,
    this.onToggleFavorite,
  });

  final String title;
  final List<Place> places;
  final UnitSystem unit;
  final double? originLat;
  final double? originLng;
  final void Function(Place place)? onOpen;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh.withValues(alpha: 1.0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        // Items
        ...places.map((p) => _FavTile(
              place: p,
              unit: unit,
              originLat: originLat,
              originLng: originLng,
              onOpen: onOpen,
              onToggleFavorite: onToggleFavorite,
            )),
      ],
    );
  }
}

class _FavTile extends StatelessWidget {
  const _FavTile({
    required this.place,
    required this.unit,
    this.originLat,
    this.originLng,
    this.onOpen,
    this.onToggleFavorite,
  });

  final Place place;
  final UnitSystem unit;
  final double? originLat;
  final double? originLng;
  final void Function(Place place)? onOpen;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final hasCoords = place.lat != null && place.lng != null;
    final subtitle = _subtitle();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _thumb(place.photos),
      title: Text(
        (place.name ?? 'Place').trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (hasCoords && originLat != null && originLng != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
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
      trailing: FavoriteButton(
        isFavorite: place.isFavorite ?? (place.isWishlisted ?? false) == true,
        compact: true,
        size: 32,
        onChanged: onToggleFavorite == null ? null : (next) => onToggleFavorite!(place, next),
      ),
      onTap: onOpen == null ? null : () => onOpen!(place),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if ((place.category ?? '').toString().trim().isNotEmpty) parts.add('${place.category}'.trim());
    if (place.rating != null) {
      final r = place.rating!.toStringAsFixed(1);
      final rc = (place.reviewsCount ?? 0);
      parts.add(rc > 0 ? '$r · $rc' : r);
    }
    return parts.join(' · ');
  }

  Widget _thumb(List<String>? photos) {
    final url = (photos != null && photos.isNotEmpty && photos.first.trim().isNotEmpty) ? photos.first.trim() : null;
    if (url == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          height: 56,
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.place_outlined, color: Colors.black38),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
        ),
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
  });

  final Place place;
  final VoidCallback onClose;
  final double? originLat;
  final double? originLng;
  final UnitSystem unit;
  final void Function(Place place)? onOpen;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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

            // Meta
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
