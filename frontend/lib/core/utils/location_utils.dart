// lib/core/utils/location_utils.dart

import '../../models/coordinates.dart';

/// Location utilities for WGS84-style latitude/longitude handling:
/// - Validation and clamping to valid ranges
/// - Angle/bearing normalization
/// - Decimal and DMS formatting
/// - Parsing from decimal or DMS strings [4]

class LocationUtils {
  const LocationUtils._();

  // WGS84 ranges: latitude in [-90, 90], longitude in [-180, 180] [4]
  static bool isValidLatitude(double latitude) =>
      latitude >= -90.0 && latitude <= 90.0; // [4]

  static bool isValidLongitude(double longitude) =>
    longitude >= -180.0 && longitude <= 180.0; // [4]

  /// Returns a clamped copy so coordinates are always within WGS84 bounds [4]
  static Coordinates clampToWgs84(Coordinates c) => Coordinates(
        latitude: c.latitude.clamp(-90.0, 90.0),
        longitude: c.longitude.clamp(-180.0, 180.0),
      ); // [4]

  /// Normalizes a longitude to [-180, 180] degrees (inclusive of -180, exclusive of 180 by convention) [7]
  static double normalizeLon180(double lon) {
    var x = lon % 360.0;
    if (x > 180.0) x -= 360.0;
    if (x <= -180.0) x += 360.0;
    return x;
  } // [7]

  /// Normalizes an angle to [0, 360) degrees (bearing normalization) [7]
  static double normalize360(double angleDeg) {
    var x = angleDeg % 360.0;
    if (x < 0) x += 360.0;
    return x;
  } // [7]

  /// Rounds both latitude and longitude to the given fraction digits [8]
  static Coordinates round(Coordinates c, {int fractionDigits = 6}) {
    final lat = double.parse(c.latitude.toStringAsFixed(fractionDigits));
    final lon = double.parse(c.longitude.toStringAsFixed(fractionDigits));
    return Coordinates(latitude: lat, longitude: lon);
  } // [8]

  // ---------- Decimal formatting ----------

  /// Formats decimal degrees with a fixed number of fraction digits (default 6) [8]
  static String formatDecimal(Coordinates c, {int fractionDigits = 6}) {
    final lat = c.latitude.toStringAsFixed(fractionDigits);
    final lon = c.longitude.toStringAsFixed(fractionDigits);
    return '$lat, $lon';
  } // [8]

  // ---------- DMS formatting ----------

  /// Formats a single signed decimal degree as DMS with hemisphere letter [6]
  static String formatDmsSingle({
    required double decimalDegrees,
    required bool isLatitude,
    int secondsFractionDigits = 1,
  }) {
    final hemi = _hemisphere(decimalDegrees, isLatitude);
    final abs = decimalDegrees.abs();
    final deg = abs.floor();
    final remMin = (abs - deg) * 60.0;
    final min = remMin.floor();
    final sec = (remMin - min) * 60.0;

    final secStr = sec.toStringAsFixed(secondsFractionDigits);
    return '$deg° $min\' $secStr" $hemi';
  } // [6]

  /// Formats a coordinate pair as DMS strings with N/S and E/W hemispheres [6]
  static String formatDms(Coordinates c, {int secondsFractionDigits = 1}) {
    final latStr = formatDmsSingle(
      decimalDegrees: c.latitude,
      isLatitude: true,
      secondsFractionDigits: secondsFractionDigits,
    );
    final lonStr = formatDmsSingle(
      decimalDegrees: c.longitude,
      isLatitude: false,
      secondsFractionDigits: secondsFractionDigits,
    );
    return '$latStr, $lonStr';
  } // [6]

  static String _hemisphere(double dd, bool isLat) {
    if (isLat) return dd >= 0 ? 'N' : 'S';
    return dd >= 0 ? 'E' : 'W';
  } // [6]

  // ---------- Parsing ----------

  /// Parses a string as decimal degrees pair "lat, lon" (e.g., "12.34, 77.12"); returns null on failure [4]
  static Coordinates? parseDecimalLatLon(String input) {
    final s = input.trim();
    final parts = s.split(RegExp(r'\s*,\s*'));
    if (parts.length != 2) return null;

    final lat = double.tryParse(parts);
    final lon = double.tryParse(parts);
    if (lat == null || lon == null) return null;

    if (!isValidLatitude(lat) || !isValidLongitude(lon)) return null;
    return Coordinates(latitude: lat, longitude: lon);
  } // [4]

  /// Parses a single DMS token into signed decimal degrees, supporting:
  /// - 12° 34' 56" N
  /// - 12 34 56 N
  /// - 12°34'56"S
  /// - 12.5 N (treated as decimal) [6]
  static double? parseDmsSingle(String token, {required bool isLatitude}) {
    final t = token.trim().toUpperCase();

    // Optional hemisphere suffix
    String hemi = '';
    if (t.endsWith('N') || t.endsWith('S') || t.endsWith('E') || t.endsWith('W')) {
      hemi = t.substring(t.length - 1);
    }

    // Strip hemisphere and symbols, replace delimiters with spaces
    final core = t
        .replaceAll(RegExp(r'[NSEW]$', caseSensitive: false), '')
        .replaceAll('°', ' ')
        .replaceAll('\'', ' ')
        .replaceAll('"', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final parts = core.split(' ');
    if (parts.isEmpty) return null;

    double sign = 1.0;
    if (hemi == 'S' || hemi == 'W') sign = -1.0;

    double degrees = 0, minutes = 0, seconds = 0;

    if (parts.length == 1) {
      // Decimal-only fallback
      final dd = double.tryParse(parts);
      if (dd == null) return null;
      final val = dd * sign;
      if (isLatitude && !isValidLatitude(val)) return null;
      if (!isLatitude && !isValidLongitude(val)) return null;
      return val;
    }

    degrees = double.tryParse(parts) ?? 0;
    if (parts.length >= 2) minutes = double.tryParse(parts) ?? 0;
    if (parts.length >= 3) seconds = double.tryParse(parts) ?? 0;

    // Decimal Degrees = d + m/60 + s/3600 [6]
    double dd = degrees + (minutes / 60.0) + (seconds / 3600.0);
    dd *= sign;

    if (isLatitude && !isValidLatitude(dd)) return null;
    if (!isLatitude && !isValidLongitude(dd)) return null;
    return dd;
  } // [6]

  /// Parses a pair of DMS tokens like:
  /// - 12°34'56"N, 77°12'34"E
  /// - 12 34 56 N, 77 12 34 E
  /// - 12.5 N, 77.5 E [6]
  static Coordinates? parseDmsPair(String input) {
    final parts = input.split(RegExp(r'\s*,\s*'));
    if (parts.length != 2) return null;

    final lat = parseDmsSingle(parts, isLatitude: true);
    final lon = parseDmsSingle(parts, isLatitude: false);
    if (lat == null || lon == null) return null;
    return Coordinates(latitude: lat, longitude: lon);
  } // [6]

  /// Parses either decimal ("lat, lon") or DMS pair, returning null if neither matches [6]
  static Coordinates? parseLatLonFlexible(String input) {
    return parseDecimalLatLon(input) ?? parseDmsPair(input);
  } // [6]

  // ---------- Misc helpers ----------

  /// Converts decimal degrees to DMS tuple (deg, min, sec, hemisphere) without formatting [6]
  static (int deg, int min, double sec, String hemi) toDmsComponents({
    required double decimalDegrees,
    required bool isLatitude,
  }) {
    final hemi = _hemisphere(decimalDegrees, isLatitude);
    final abs = decimalDegrees.abs();
    final deg = abs.floor();
    final remMin = (abs - deg) * 60.0;
    final min = remMin.floor();
    final sec = (remMin - min) * 60.0;
    return (deg, min, sec, hemi);
  } // [6]
}
