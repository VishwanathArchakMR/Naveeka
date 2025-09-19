// lib/models/geo_point.dart

import 'dart:math' as math;

class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Calculate distance to another GeoPoint in meters using the haversine formula.
  double distanceTo(GeoPoint other) {
    const double earthRadius = 6371000.0; // meters
    final double lat1Rad = _deg2rad(latitude);
    final double lat2Rad = _deg2rad(other.latitude);
    final double deltaLatRad = _deg2rad(other.latitude - latitude);
    final double deltaLngRad = _deg2rad(other.longitude - longitude);

    final double sinDLat = math.sin(deltaLatRad / 2.0);
    final double sinDLng = math.sin(deltaLngRad / 2.0);

    final double a = sinDLat * sinDLat +
        math.cos(lat1Rad) * math.cos(lat2Rad) * sinDLng * sinDLng;

    // More numerically stable than 2 * asin(sqrt(a))
    final double c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));

    return earthRadius * c;
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GeoPoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return Object.hash(latitude, longitude);
  }

  @override
  String toString() {
    return 'GeoPoint(lat: $latitude, lng: $longitude)';
  }
}
