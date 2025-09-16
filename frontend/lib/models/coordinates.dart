// lib/models/coordinates.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Geographic coordinates in decimal degrees using WGS84-like bounds:
/// latitude ∈ [-90, 90], longitude ∈ [-180, 180]. [12]
@immutable
class Coordinates {
  const Coordinates({
    required this.latitude,
    required this.longitude,
  });

  /// Latitude in decimal degrees (south is negative). [12]
  final double latitude;

  /// Longitude in decimal degrees (west is negative). [12]
  final double longitude;

  /// Tolerant parser:
  /// - latitude: latitude | lat | y
  /// - longitude: longitude | lng | lon | x
  factory Coordinates.fromJson(Map<String, dynamic> json) {
    double? numToDouble(dynamic v) =>
        v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

    final lat = numToDouble(json['latitude'] ?? json['lat'] ?? json['y']) ?? 0.0;
    final lon = numToDouble(json['longitude'] ?? json['lng'] ?? json['lon'] ?? json['x']) ?? 0.0;
    return Coordinates(latitude: lat, longitude: lon);
  } // Avoid leading underscores in local identifiers per lint. [1][2]

  /// Serialize as { latitude, longitude } to preserve backward compatibility. [7]
  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  /// Alternative serializer commonly used in mapping payloads: { lat, lng }. [7]
  Map<String, dynamic> toLatLngJson() => {
        'lat': latitude,
        'lng': longitude,
      };

  /// GeoJSON Point representation: { "type":"Point", "coordinates":[lng, lat] }. [7]
  Map<String, dynamic> toGeoJson() => {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      };

  /// Construct from a "lat,lng" or "lat lon" string; returns null if parse fails. [7]
  static Coordinates? parse(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.isEmpty) return null;
    final parts = t.contains(',') ? t.split(',') : t.split(RegExp(r'\s+'));
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lon = double.tryParse(parts[1].trim());
    if (lat == null || lon == null) return null;
    return Coordinates(latitude: lat, longitude: lon);
  }

  /// Returns a copy with updated values. [7]
  Coordinates copyWith({
    double? latitude,
    double? longitude,
  }) {
    return Coordinates(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// True if latitude and longitude fall in typical WGS84 bounds. [12]
  bool get isValid =>
      latitude >= -90.0 &&
      latitude <= 90.0 &&
      longitude >= -180.0 &&
      longitude <= 180.0;

  /// Clamp to valid WGS84 bounds (useful after arithmetic). [12]
  Coordinates clamped() {
    final lat = latitude.clamp(-90.0, 90.0);
    // Wrap longitude to [-180,180]
    var lon = longitude;
    lon = (lon + 180.0) % 360.0;
    if (lon < 0) lon += 360.0;
    lon -= 180.0;
    return Coordinates(latitude: lat.toDouble(), longitude: lon);
  }

  /// Rounded coordinate for display or grouping. [7]
  Coordinates rounded({int fractionDigits = 6}) {
    return Coordinates(
      latitude: double.parse(latitude.toStringAsFixed(fractionDigits)),
      longitude: double.parse(longitude.toStringAsFixed(fractionDigits)),
    );
  }

  /// Haversine great-circle distance to [other] in meters (R≈6,371,000 m). [12][9]
  double distanceTo(Coordinates other, {double earthRadiusMeters = 6371000.0}) {
    final phi1 = _degToRad(latitude);
    final phi2 = _degToRad(other.latitude);
    final dPhi = _degToRad(other.latitude - latitude);
    final dLambda = _degToRad(other.longitude - longitude);

    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  } // Haversine is standard for great-circle distance on a sphere. [12][9]

  /// Initial great-circle bearing (forward azimuth) in degrees [0,360). [12]
  double bearingTo(Coordinates other) {
    final phi1 = _degToRad(latitude);
    final phi2 = _degToRad(other.latitude);
    final dLambda = _degToRad(other.longitude - longitude);
    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    final brng = _radToDeg(math.atan2(y, x));
    return (brng + 360.0) % 360.0;
  } // Spherical initial bearing using atan2(y,x). [12]

  /// Midpoint along the great-circle path to [other]. [12]
  Coordinates midpointTo(Coordinates other) {
    final phi1 = _degToRad(latitude);
    final lambda1 = _degToRad(longitude);
    final phi2 = _degToRad(other.latitude);
    final lambda2 = _degToRad(other.longitude);

    final bx = math.cos(phi2) * math.cos(lambda2 - lambda1);
    final by = math.cos(phi2) * math.sin(lambda2 - lambda1);
    final phi3 = math.atan2(
      math.sin(phi1) + math.sin(phi2),
      math.sqrt((math.cos(phi1) + bx) * (math.cos(phi1) + bx) + by * by),
    );
    final lambda3 = lambda1 + math.atan2(by, math.cos(phi1) + bx);
    return Coordinates(
      latitude: _radToDeg(phi3),
      longitude: ((_radToDeg(lambda3) + 540.0) % 360.0) - 180.0,
    );
  } // Spherical midpoint formula. [12]

  /// Destination point given distance (m) and bearing (deg) from this coordinate. [12]
  Coordinates offsetBy({required double distanceMeters, required double bearingDegrees, double earthRadiusMeters = 6371000.0}) {
    final delta = distanceMeters / earthRadiusMeters;
    final theta = _degToRad(bearingDegrees);

    final phi1 = _degToRad(latitude);
    final lambda1 = _degToRad(longitude);

    final phi2 = math.asin(math.sin(phi1) * math.cos(delta) + math.cos(phi1) * math.sin(delta) * math.cos(theta));
    final lambda2 = lambda1 +
        math.atan2(
          math.sin(theta) * math.sin(delta) * math.cos(phi1),
          math.cos(delta) - math.sin(phi1) * math.sin(phi2),
        );

    return Coordinates(
      latitude: _radToDeg(phi2),
      longitude: ((_radToDeg(lambda2) + 540.0) % 360.0) - 180.0,
    );
  } // Spherical direct/geodesic destination. [12]

  @override
  String toString() => 'Coordinates($latitude, $longitude)'; // [7]

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Coordinates &&
          other.latitude == latitude &&
          other.longitude == longitude); // [7]

  @override
  int get hashCode => Object.hash(latitude, longitude); // [7]

  // ----- Private helpers -----

  static double _degToRad(double d) => d * (math.pi / 180.0); // [12]
  static double _radToDeg(double r) => r * (180.0 / math.pi); // [12]
}

