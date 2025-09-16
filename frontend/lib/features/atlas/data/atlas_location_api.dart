// lib/features/atlas/data/atlas_location_api.dart

import 'dart:math' as math;

import '../../../models/place.dart';
import '../../../services/location_service.dart';

typedef JsonMap = Map<String, dynamic>;

/// A small DTO for geocoding results independent of any package.
class GeocodeResult {
  final double latitude;
  final double longitude;
  final String label; // formatted address or place label

  const GeocodeResult({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

/// A helper class that exposes location-centric operations for Atlas.
/// - Works with current seed data and LocationService now.
/// - Allows injecting real geocoding in the future without breaking callers.
/// - Uses Haversine for distance calculations between coordinates.
class AtlasLocationApi {
  AtlasLocationApi({
    GeocodeResult Function(String query)? forwardGeocoderSync,
    Future<GeocodeResult> Function(String query)? forwardGeocoderAsync,
    GeocodeResult Function(double lat, double lon)? reverseGeocoderSync,
    Future<GeocodeResult> Function(double lat, double lon)? reverseGeocoderAsync,
  })  : _forwardSync = forwardGeocoderSync,
        _forwardAsync = forwardGeocoderAsync,
        _reverseSync = reverseGeocoderSync,
        _reverseAsync = reverseGeocoderAsync;

  // Optional injected geocoders for future real data
  final GeocodeResult Function(String query)? _forwardSync;
  final Future<GeocodeResult> Function(String query)? _forwardAsync;
  final GeocodeResult Function(double lat, double lon)? _reverseSync;
  final Future<GeocodeResult> Function(double lat, double lon)? _reverseAsync;

  /// Returns the latest user location from the LocationService.
  Future<UserLocation?> getCurrentLocation() async {
    try {
      return await LocationService.instance.getCurrentLocation();
    } catch (_) {
      return null;
    }
  }

  /// Forward geocode an address or place query.
  /// Today returns a minimal fallback if no geocoder is injected.
  Future<GeocodeResult?> geocode(String query) async {
    if (query.trim().isEmpty) return null;
    if (_forwardAsync != null) return _forwardAsync!(query);
    if (_forwardSync != null) return _forwardSync!(query);
    // Fallback: no real geocoder wired yet.
    return null;
  }

  /// Reverse geocode coordinates to a human-readable label.
  /// Today returns a minimal fallback if no geocoder is injected.
  Future<GeocodeResult?> reverseGeocode(double latitude, double longitude) async {
    if (_reverseAsync != null) return _reverseAsync!(latitude, longitude);
    if (_reverseSync != null) return _reverseSync!(latitude, longitude);
    // Fallback: basic lat,lng label
    return GeocodeResult(
      latitude: latitude,
      longitude: longitude,
      label: '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
    );
  }

  /// Computes great-circle distance in kilometers using the Haversine formula.
  /// Inputs in degrees. Output in km. Earth radius assumed 6371 km.
  double haversineKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const r = 6371.0; // km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.asin(math.min(1.0, math.sqrt(a)));
    return r * c;
  }

  /// Formats a compact distance string like "850 m" or "2.3 km".
  String formatDistance(double km) {
    if (km < 1.0) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
  }

  /// Filters a list of places by a given center and radius (km).
  /// If a place has no precomputed distanceFromUser, distance is computed on the fly.
  List<Place> filterByRadius({
    required List<Place> places,
    required double centerLat,
    required double centerLon,
    required double radiusKm,
  }) {
    return places.where((p) {
      final d = p.location.distanceFromUser ??
          haversineKm(
            lat1: centerLat,
            lon1: centerLon,
            lat2: p.location.coordinates.latitude,
            lon2: p.location.coordinates.longitude,
          );
      return d <= radiusKm;
    }).toList();
  }

  /// Sorts places by distance from a center (ascending), computing if needed.
  List<Place> sortByDistance({
    required List<Place> places,
    required double centerLat,
    required double centerLon,
  }) {
    final copy = List<Place>.from(places);
    copy.sort((a, b) {
      final da = a.location.distanceFromUser ??
          haversineKm(
            lat1: centerLat,
            lon1: centerLon,
            lat2: a.location.coordinates.latitude,
            lon2: a.location.coordinates.longitude,
          );
      final db = b.location.distanceFromUser ??
          haversineKm(
            lat1: centerLat,
            lon1: centerLon,
            lat2: b.location.coordinates.latitude,
            lon2: b.location.coordinates.longitude,
          );
      return da.compareTo(db);
    });
    return copy;
  }

  /// Computes distances for each place from a center and returns a map by place.id (km).
  Map<String, double> computeDistancesKm({
    required List<Place> places,
    required double centerLat,
    required double centerLon,
  }) {
    final out = <String, double>{};
    for (final p in places) {
      final d = p.location.distanceFromUser ??
          haversineKm(
            lat1: centerLat,
            lon1: centerLon,
            lat2: p.location.coordinates.latitude,
            lon2: p.location.coordinates.longitude,
          );
      out[p.id] = d;
    }
    return out;
  }

  /// Convenience: gets current user location, then filters/sorts nearby places
  /// within radiusKm and returns the sorted list. If user location is unavailable,
  /// returns places unchanged (caller may handle empty/disabled location case).
  Future<List<Place>> getNearbySorted({
    required List<Place> allPlaces,
    required double radiusKm,
  }) async {
    final loc = await getCurrentLocation();
    if (loc == null) return allPlaces;

    final filtered = filterByRadius(
      places: allPlaces,
      centerLat: loc.latitude,
      centerLon: loc.longitude,
      radiusKm: radiusKm,
    );

    return sortByDistance(
      places: filtered,
      centerLat: loc.latitude,
      centerLon: loc.longitude,
    );
  }

  /// Calculates an approximate bounding box (lat/lon degrees) for a radial distance (km).
  /// Useful for pre-filtering before a more precise distance check.
  /// Note: Longitude delta depends on latitude.
  ({
    double minLat,
    double maxLat,
    double minLon,
    double maxLon,
  }) boundingBox({
    required double centerLat,
    required double centerLon,
    required double radiusKm,
  }) {
    const earthRadiusKm = 6371.0;
    final latDelta = (radiusKm / earthRadiusKm) * (180 / math.pi);
    // Account for shrinking longitude degrees with latitude
    final lonDelta = (radiusKm / (earthRadiusKm * math.cos(_toRad(centerLat)))) * (180 / math.pi);

    return (
      minLat: centerLat - latDelta,
      maxLat: centerLat + latDelta,
      minLon: centerLon - lonDelta,
      maxLon: centerLon + lonDelta,
    );
  }

  /// Quick pre-filter: check if a coordinate is within a bounding box.
  bool withinBounds({
    required double lat,
    required double lon,
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) {
    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }

  double _toRad(double deg) => deg * (math.pi / 180.0);
}
