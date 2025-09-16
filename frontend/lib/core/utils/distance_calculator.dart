// lib/core/utils/distance_calculator.dart

import 'dart:math' as math;

import '../../models/coordinates.dart';

/// Great-circle distance and navigation helpers using WGS84 spherical approximations. [10]
class DistanceCalculator {
  // Mean Earth radius in meters (WGS84 sphere approximation). [10]
  static const double earthRadiusMeters = 6371008.8;

  const DistanceCalculator._();

  // ----------------- Core math -----------------

  static double _toRad(double deg) => deg * (math.pi / 180.0); // [10]
  static double _toDeg(double rad) => rad * (180.0 / math.pi); // [10]

  /// Haversine distance in meters between two coordinates (shortest over Earth’s surface). [10]
  static double haversineMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final deltaPhi = _toRad(lat2 - lat1);
    final deltaLambda = _toRad(lon2 - lon1); // [10]

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2); // [10]
    final c = 2 * math.asin(math.min(1.0, math.sqrt(a))); // numeric safety [10]
    return earthRadiusMeters * c; // [10]
  }

  /// Haversine distance in kilometers. [10]
  static double haversineKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) =>
      haversineMeters(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2) / 1000.0; // [10]

  /// Initial bearing (forward azimuth) in degrees from point A to B (0..360). [19]
  static double initialBearingDegrees({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final deltaLambda = _toRad(lon2 - lon1); // [19]

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda); // [19]
    final theta = math.atan2(y, x);
    final bearing = (_toDeg(theta) + 360.0) % 360.0; // normalize to 0..360 [19]
    return bearing;
  }

  /// Destination point given start, initial bearing (deg), and distance (m). [19]
  static Coordinates destinationPoint({
    required double lat,
    required double lon,
    required double bearingDegrees,
    required double distanceMeters,
  }) {
    final delta = distanceMeters / earthRadiusMeters; // angular distance [19]
    final theta = _toRad(bearingDegrees);
    final phi1 = _toRad(lat);
    final lambda1 = _toRad(lon); // [19]

    final sinPhi1 = math.sin(phi1);
    final cosPhi1 = math.cos(phi1);
    final sinDelta = math.sin(delta);
    final cosDelta = math.cos(delta); // [19]

    final phi2 = math.asin(sinPhi1 * cosDelta + cosPhi1 * sinDelta * math.cos(theta)); // [19]
    final lambda2 = lambda1 +
        math.atan2(
          math.sin(theta) * sinDelta * cosPhi1,
          cosDelta - sinPhi1 * math.sin(phi2),
        ); // [19]

    final lat2 = _toDeg(phi2);
    var lon2 = _toDeg(lambda2);
    lon2 = ((lon2 + 540) % 360) - 180; // normalize to -180..180 [19]
    return Coordinates(latitude: lat2, longitude: lon2);
  }

  /// Midpoint between two coordinates along the great-circle. [19]
  static Coordinates midpoint({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final phi1 = _toRad(lat1);
    final lambda1 = _toRad(lon1);
    final phi2 = _toRad(lat2);
    final deltaLambda = _toRad(lon2 - lon1); // [19]

    final bx = math.cos(phi2) * math.cos(deltaLambda);
    final by = math.cos(phi2) * math.sin(deltaLambda); // [19]

    final phi3 = math.atan2(
      math.sin(phi1) + math.sin(phi2),
      math.sqrt((math.cos(phi1) + bx) * (math.cos(phi1) + bx) + by * by),
    ); // [19]
    final lambda3 = lambda1 + math.atan2(by, math.cos(phi1) + bx); // [19]

    final lat3 = _toDeg(phi3);
    var lon3 = _toDeg(lambda3);
    lon3 = ((lon3 + 540) % 360) - 180; // normalize [19]
    return Coordinates(latitude: lat3, longitude: lon3);
  }

  // ----------------- Bounding box helpers -----------------

  /// Approximate lat/lon bounding box for a radius in meters from a center. [19]
  static ({
    double minLat,
    double maxLat,
    double minLon,
    double maxLon,
  }) boundingBox({
    required double centerLat,
    required double centerLon,
    required double radiusMeters,
  }) {
    final latRad = _toRad(centerLat);
    final degLat = (radiusMeters / earthRadiusMeters) * (180 / math.pi);
    final degLon =
        (radiusMeters / (earthRadiusMeters * math.cos(latRad))) * (180 / math.pi); // [19]

    return (
      minLat: centerLat - degLat,
      maxLat: centerLat + degLat,
      minLon: centerLon - degLon,
      maxLon: centerLon + degLon,
    );
  }

  /// Checks if a coordinate lies within a bounding box. [19]
  static bool withinBounds({
    required double lat,
    required double lon,
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) {
    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon; // [19]
  }

  // ----------------- Aggregates and formatting -----------------

  /// Total length of a path in meters using Haversine; accepts a list of Coordinates. [10]
  static double pathLengthMeters(List<Coordinates> points) {
    if (points.length < 2) return 0; // [10]
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      total += haversineMeters(
        lat1: a.latitude,
        lon1: a.longitude,
        lat2: b.latitude,
        lon2: b.longitude,
      ); // [10]
    }
    return total;
  }

  /// Formats distance like "850 m" or "2.3 km" for UI badges/cards. [19]
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m'; // [19]
    final km = meters / 1000.0;
    return km >= 10 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km'; // [19]
  }

  /// Convenience km formatter from meters. [10]
  static String formatKm(double meters) =>
      (meters / 1000.0) >= 10 ? '${(meters / 1000).round()} km' : '${(meters / 1000).toStringAsFixed(1)} km'; // [10]
}
