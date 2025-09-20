// lib/features/quick_actions/presentation/favorites/widgets/favorites_by_location.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '/../../../models/place.dart';

// Alias the booking filter module and expose required symbols.
import '../../booking/widgets/booking_location_filter.dart' as filt
    show BookingLocationSelection, LocationMode, GeoPoint, BookingLocationFilterSheet, UnitSystem;

// Alias DistanceIndicator and its UnitSystem to avoid name conflicts.
import '../../../../places/presentation/widgets/distance_indicator.dart' as dist
    show DistanceIndicator, UnitSystem;

import '../../favorites/widgets/favorite_button.dart';

// Shared map contract (Google/Mapbox) used across the app.
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

// Map between the two UnitSystem enums (booking filter <-> distance widget).
dist.UnitSystem _fromFiltUnit(filt.UnitSystem u) =>
    u == filt.UnitSystem.imperial ? dist.UnitSystem.imperial : dist.UnitSystem.metric;

filt.UnitSystem _toFiltUnit(dist.UnitSystem u) =>
    u == dist.UnitSystem.imperial ? filt.UnitSystem.imperial : filt.UnitSystem.metric;

class FavoritesByLocation extends StatefulWidget {
  const FavoritesByLocation({
    super.key,
    required this.places,
    this.sectionTitle = 'Favorites by location',
    this.mapBuilder,
    this.originLat,
    this.originLng,
    this.initialUnit = dist.UnitSystem.metric,
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

  final dist.UnitSystem initialUnit;
  final double initialRadiusKm;

  final void Function(Place place)? onOpenPlace;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;

  final Future<filt.BookingLocationSelection?> Function()? onPickLocation;

  final double height;

  @override
  State<FavoritesByLocation> createState() => _FavoritesByLocationState();
}

class _FavoritesByLocationState extends State<FavoritesByLocation> {
  _ViewMode _mode = _ViewMode.map;
  dist.UnitSystem _unit = dist.UnitSystem.metric;
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
                  SegmentedButton<dist.UnitSystem>(
                    segments: const [
                      ButtonSegment<dist.UnitSystem>(
                        value: dist.UnitSystem.metric,
                        label: Text('km'),
                      ),
                      ButtonSegment<dist.UnitSystem>(
                        value: dist.UnitSystem.imperial,
                        label: Text('mi'),
                      ),
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
    if (widget.mapBuilder == null || center == null) {
      return _placeholderMap(context);
    }

    final markers = items
        .where((p) => _latOf(p) != null && _lngOf(p) != null)
        .map((p) => NearbyMarker(
              id: _idOf(p),
              lat: _latOf(p)!,
              lng: _lngOf(p)!,
              selected: _idOf(p) == _selectedMarkerId,
            ))
        .toList(growable: false);

    Place? selected;
    if (_selectedMarkerId != null && items.isNotEmpty) {
      selected = items.firstWhere(
        (p) => _idOf(p) == _selectedMarkerId,
        orElse: () => items.first,
      );
    }

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
      ],
    );
  }

  // ---------------- List ----------------

  Widget _buildList(BuildContext context, List<Place> items) {
    // Group by city/region/country via toJson
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
    );
  }

  // ---------------- Helpers ----------------

  Future<void> _pickLocation() async {
    if (widget.onPickLocation != null) {
      final sel = await widget.onPickLocation!.call();
      if (sel != null) {
        setState(() {
          _unit = _fromFiltUnit(sel.unit);
          _radiusKm = sel.radiusKm ?? _radiusKm;
          _originLat = sel.lat ?? _originLat;
          _originLng = sel.lng ?? _originLng;
        });
      }
      return;
    }
    // Default sheet
    final sel = await filt.BookingLocationFilterSheet.show(
      context,
      initial: filt.BookingLocationSelection(
        mode: _originLat == null ? filt.LocationMode.nearMe : filt.LocationMode.mapPin,
        lat: _originLat,
        lng: _originLng,
        radiusKm: _radiusKm,
        unit: _toFiltUnit(_unit),
      ),
      onResolveCurrentLocation: () async {
        // Resolve device location via platform APIs here if needed.
        return _originLat != null && _originLng != null ? filt.GeoPoint(_originLat!, _originLng!) : null;
      },
      onPickOnMap: () async {
        // Open a map picker and return a GeoPoint here if implemented.
        return _originLat != null && _originLng != null ? filt.GeoPoint(_originLat!, _originLng!) : null;
      },
      minKm: 0.5,
      maxKm: 50,
    );
    if (sel != null) {
      setState(() {
        _unit = _fromFiltUnit(sel.unit);
        _radiusKm = sel.radiusKm ?? _radiusKm;
        _originLat = sel.lat ?? _originLat;
        _originLng = sel.lng ?? _originLng;
      });
    }
  }

  String _locationLabel() {
    if (_originLat == null || _originLng == null) return 'Set location';
    return 'Location set';
  }

  String _radiusLabel() {
    final v = _unit == dist.UnitSystem.metric ? _radiusKm : _radiusKm * 0.621371;
    final unit = _unit == dist.UnitSystem.metric ? 'km' : 'mi';
    return v >= 10 ? '${v.toStringAsFixed(0)} $unit' : '${v.toStringAsFixed(1)} $unit';
  }

  // Read address and other fields via toJson to avoid missing getters
  String _placeKey(Place p) {
    final j = _json(p);
    final city = (j['city'] ?? '').toString().trim();
    final region = (j['region'] ?? '').toString().trim();
    final country = (j['country'] ?? '').toString().trim();
    final parts = <String>[if (city.isNotEmpty) city, if (region.isNotEmpty) region, if (country.isNotEmpty) country];
    return parts.isEmpty ? 'Unknown' : parts.join(', ');
  }

  double _distance(Place p) {
    final lat = _latOf(p);
    final lng = _lngOf(p);
    if (_originLat == null || _originLng == null || lat == null || lng == null) return double.infinity;
    final d = _haversine(_originLat!, _originLng!, lat, lng);
    return _unit == dist.UnitSystem.metric ? d : d * 0.621371;
  }

  List<Place> _filtered(List<Place> src, double? lat, double? lng, double radiusKm) {
    if (lat == null || lng == null) return src;
    return src.where((p) {
      final pl = _latOf(p);
      final pn = _lngOf(p);
      if (pl == null || pn == null) return false;
      final d = _haversine(lat, lng, pl, pn);
      return d <= radiusKm;
    }).toList(growable: false);
  }

  (double, double)? _centerOf(List<Place> items, { (double?, double?)? fallback }) {
    if (items.isNotEmpty) {
      final pts = items.where((e) => _latOf(e) != null && _lngOf(e) != null).toList();
      if (pts.isNotEmpty) {
        final lats = pts.map((e) => _latOf(e)!).toList();
        final lngs = pts.map((e) => _lngOf(e)!).toList();
        final lat = lats.reduce((a, b) => a + b) / lats.length;
        final lng = lngs.reduce((a, b) => a + b) / lngs.length;
        return (lat, lng);
      }
    }
    final (fl, fn) = fallback ?? (null, null);
    if (fl != null && fn != null) return (fl, fn);
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

  // JSON helpers to normalize Place fields
  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  String _idOf(Place p) {
    final j = _json(p);
    return (j['id'] ?? j['_id'] ?? j['placeId'] ?? '').toString();
  }

  double? _latOf(Place p) {
    final j = _json(p);
    return _d(j['lat'] ?? j['latitude'] ?? j['coord_lat'] ?? j['location_lat']);
  }

  double? _lngOf(Place p) {
    final j = _json(p);
    return _d(j['lng'] ?? j['lon'] ?? j['longitude'] ?? j['coord_lng'] ?? j['location_lng']);
  }

  double? _d(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Widget _placeholderMap(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerHigh,
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

// ---------------- Peek card (map selection) ----------------

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
  final dist.UnitSystem unit;
  final void Function(Place place)? onOpen;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    // Promote public fields to locals for safe checks across toolchains
    final olat = originLat;
    final olng = originLng;

    final j = _json(place);
    final name = (j['name'] ?? j['title'] ?? j['label'] ?? 'Place').toString().trim();
    final rating = _ratingOf(place);
    final hasCoords = _latOf(place) != null && _lngOf(place) != null;
    final hasOrigin = olat != null && olng != null;

    // Capture handler locally to avoid redundant non-null assertions in closures.
    final favHandler = onToggleFavorite;

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
                    name,
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
                if (rating != null) _stars(rating),
                if (rating != null && hasCoords && hasOrigin) const SizedBox(width: 8),
                if (hasCoords && hasOrigin)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: dist.DistanceIndicator.fromPlace(
                        place,
                        originLat: olat,
                        originLng: olng,
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
                  isFavorite: _isFavorite(place),
                  compact: true,
                  onChanged: favHandler == null ? null : (next) => favHandler(place, next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Local helpers for _PeekCard

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  double? _latOf(Place p) {
    final j = _json(p);
    return _d(j['lat'] ?? j['latitude'] ?? j['coord_lat'] ?? j['location_lat']);
  }

  double? _lngOf(Place p) {
    final j = _json(p);
    return _d(j['lng'] ?? j['lon'] ?? j['longitude'] ?? j['coord_lng'] ?? j['location_lng']);
  }

  double? _ratingOf(Place p) {
    final j = _json(p);
    final v = j['rating'] ?? j['avgRating'] ?? j['averageRating'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool _isFavorite(Place p) {
    final j = _json(p);
    final f = j['isFavorite'];
    final w = j['isWishlisted'] ?? j['wishlisted'];
    final fv = (f is bool) ? f : (f is String ? f.toLowerCase() == 'true' : false);
    final wv = (w is bool) ? w : (w is String ? w.toLowerCase() == 'true' : false);
    return fv || wv;
  }

  double? _d(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
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
  final dist.UnitSystem unit;
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
        ...places.map((p) {
          final handler = onToggleFavorite;
          return _FavTile(
            place: p,
            unit: unit,
            originLat: originLat,
            originLng: originLng,
            onOpen: onOpen,
            onToggleFavorite: handler,
          );
        }),
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
  final dist.UnitSystem unit;
  final double? originLat;
  final double? originLng;
  final void Function(Place place)? onOpen;
  final Future<bool> Function(Place place, bool next)? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final name = (() {
      final j = _json(place);
      return (j['name'] ?? j['title'] ?? j['label'] ?? 'Place').toString().trim();
    })();
    final photos = _photosOf(place);
    final hasCoords = _latOf(place) != null && _lngOf(place) != null;

    final subtitle = _subtitle();

    final favHandler = onToggleFavorite;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: _thumb(photos),
      title: Text(
        name,
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
                child: dist.DistanceIndicator.fromPlace(
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
        isFavorite: _isFavorite(place),
        compact: true,
        size: 32,
        onChanged: favHandler == null ? null : (next) => favHandler(place, next),
      ),
      onTap: onOpen == null ? null : () => onOpen!(place),
    );
  }

  String _subtitle() {
    final j = _json(place);
    final parts = <String>[];
    final cat = (j['category'] ?? '').toString().trim();
    if (cat.isNotEmpty) parts.add(cat);
    final r = _ratingOf(place);
    final rc = _reviewsCountOf(place);
    if (r != null) parts.add(rc > 0 ? '${r.toStringAsFixed(1)} · $rc' : r.toStringAsFixed(1));
    return parts.join(' · ');
  }

  Widget _thumb(List<String> photos) {
    final url = (photos.isNotEmpty && photos.first.trim().isNotEmpty) ? photos.first.trim() : null;
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

  // Local JSON helpers for the tile

  Map<String, dynamic> _json(Place p) {
    try {
      final dyn = p as dynamic;
      final j = dyn.toJson();
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  double? _latOf(Place p) {
    final j = _json(p);
    return _d(j['lat'] ?? j['latitude'] ?? j['coord_lat'] ?? j['location_lat']);
  }

  double? _lngOf(Place p) {
    final j = _json(p);
    return _d(j['lng'] ?? j['lon'] ?? j['longitude'] ?? j['coord_lng'] ?? j['location_lng']);
  }

  double? _ratingOf(Place p) {
    final j = _json(p);
    final v = j['rating'] ?? j['avgRating'] ?? j['averageRating'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int _reviewsCountOf(Place p) {
    final j = _json(p);
    final v = j['reviewsCount'] ?? j['reviewCount'] ?? j['reviews'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }

  List<String> _photosOf(Place p) {
    final j = _json(p);
    final v = j['photos'] ?? j['images'] ?? j['gallery'];
    if (v is List) return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList(growable: false);
    return const <String>[];
  }

  bool _isFavorite(Place p) {
    final j = _json(p);
    final f = j['isFavorite'];
    final w = j['isWishlisted'] ?? j['wishlisted'];
    final fv = (f is bool) ? f : (f is String ? f.toLowerCase() == 'true' : false);
    final wv = (w is bool) ? w : (w is String ? w.toLowerCase() == 'true' : false);
    return fv || wv;
  }

  double? _d(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
