// lib/core/utils/location_utils.dart

import '../../models/coordinates.dart';

/// Location utilities for WGS84-style latitude/longitude handling:
/// - Validation and clamping to valid ranges
/// - Angle/bearing normalization
/// - Decimal and DMS formatting
/// - Parsing from decimal or DMS strings
class LocationUtils {
  const LocationUtils._();

  // WGS84 ranges: latitude in [-90, 90], longitude in [-180, 180]
  static bool isValidLatitude(double latitude) =>
      latitude >= -90.0 && latitude <= 90.0;

  static bool isValidLongitude(double longitude) =>
      longitude >= -180.0 && longitude <= 180.0;

  /// Returns a clamped copy so coordinates are always within WGS84 bounds
  static Coordinates clampToWgs84(Coordinates c) => Coordinates(
        latitude: c.latitude.clamp(-90.0, 90.0).toDouble(),
        longitude: c.longitude.clamp(-180.0, 180.0).toDouble(),
      );

  /// Normalizes a longitude to [-180, 180] degrees (inclusive of -180, exclusive of 180 by convention)
  static double normalizeLon180(double lon) {
    var x = lon % 360.0;
    if (x > 180.0) x -= 360.0;
    if (x <= -180.0) x += 360.0;
    return x;
  }

  /// Normalizes an angle to [0, 360) degrees (bearing normalization)
  static double normalize360(double angleDeg) {
    var x = angleDeg % 360.0;
    if (x < 0) x += 360.0;
    return x;
  }

  /// Rounds both latitude and longitude to the given fraction digits
  static Coordinates round(Coordinates c, {int fractionDigits = 6}) {
    final lat = double.parse(c.latitude.toStringAsFixed(fractionDigits));
    final lon = double.parse(c.longitude.toStringAsFixed(fractionDigits));
    return Coordinates(latitude: lat, longitude: lon);
  }

  // ---------- Decimal formatting ----------

  /// Formats decimal degrees with a fixed number of fraction digits (default 6)
  static String formatDecimal(Coordinates c, {int fractionDigits = 6}) {
    final lat = c.latitude.toStringAsFixed(fractionDigits);
    final lon = c.longitude.toStringAsFixed(fractionDigits);
    return '$lat, $lon';
  }

  // ---------- DMS formatting ----------

  /// Formats a single signed decimal degree as DMS with hemisphere letter
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
  }

  /// Formats a coordinate pair as DMS strings with N/S and E/W hemispheres
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
  }

  static String _hemisphere(double dd, bool isLat) {
    if (isLat) return dd >= 0 ? 'N' : 'S';
    return dd >= 0 ? 'E' : 'W';
  }

  // ---------- Parsing ----------

  /// Parses a string as decimal degrees pair "lat, lon" (e.g., "12.34, 77.12"); returns null on failure
  static Coordinates? parseDecimalLatLon(String input) {
    final s = input.trim();
    final parts = s.split(RegExp(r'\s*,\s*'));
    if (parts.length != 2) return null;

    // Use parts[0] and parts[1] as Strings for parsing
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;

    if (!isValidLatitude(lat) || !isValidLongitude(lon)) return null;
    return Coordinates(latitude: lat, longitude: lon);
  }

  /// Parses a single DMS token into signed decimal degrees, supporting:
  /// - 12° 34' 56" N
  /// - 12 34 56 N
  /// - 12°34'56"S
  /// - 12.5 N (treated as decimal)
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
      final dd = double.tryParse(parts[0]);
      if (dd == null) return null;
      final val = dd * sign;
      if (isLatitude && !isValidLatitude(val)) return null;
      if (!isLatitude && !isValidLongitude(val)) return null;
      return val;
    }

    // Parse components by indexing the list of strings
    degrees = double.tryParse(parts[0]) ?? 0;
    if (parts.length >= 2) minutes = double.tryParse(parts[1]) ?? 0;
    if (parts.length >= 3) seconds = double.tryParse(parts[2]) ?? 0;

    // Decimal Degrees = d + m/60 + s/3600
    double dd = degrees + (minutes / 60.0) + (seconds / 3600.0);
    dd *= sign;

    if (isLatitude && !isValidLatitude(dd)) return null;
    if (!isLatitude && !isValidLongitude(dd)) return null;
    return dd;
  }

  /// Parses a pair of DMS tokens like:
  /// - 12°34'56"N, 77°12'34"E
  /// - 12 34 56 N, 77 12 34 E
  /// - 12.5 N, 77.5 E
  static Coordinates? parseDmsPair(String input) {
    final parts = input.split(RegExp(r'\s*,\s*'));
    if (parts.length != 2) return null;

    // Pass each token string to parseDmsSingle
    final lat = parseDmsSingle(parts[0], isLatitude: true);
    final lon = parseDmsSingle(parts[1], isLatitude: false);
    if (lat == null || lon == null) return null;
    return Coordinates(latitude: lat, longitude: lon);
  }

  /// Parses either decimal ("lat, lon") or DMS pair, returning null if neither matches
  static Coordinates? parseLatLonFlexible(String input) {
    return parseDecimalLatLon(input) ?? parseDmsPair(input);
  }

  // ---------- Misc helpers ----------

  /// Converts decimal degrees to DMS tuple (deg, min, sec, hemisphere) without formatting
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
  }
}
