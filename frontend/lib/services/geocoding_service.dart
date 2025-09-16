// lib/services/geocoding_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:geocoding/geocoding.dart';

import '../core/storage/local_storage.dart';

/// Minimal DTO for geocoding results.
class GeocodeResult {
  final double latitude;
  final double longitude;
  final String label; // formatted address or input query

  const GeocodeResult({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
      };

  factory GeocodeResult.fromJson(Map<String, dynamic> json) => GeocodeResult(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        label: (json['label'] as String?) ?? '',
      );
}

/// A singleton service wrapping the Flutter geocoding plugin with caching,
/// TTL, and a gentle rate limiter to avoid excessive calls.
class GeocodingService {
  GeocodingService._();
  static final GeocodingService _instance = GeocodingService._();
  static GeocodingService get instance => _instance;

  // In-memory cache for fast repeat lookups during a session
  final Map<String, GeocodeResult> _forwardCache = <String, GeocodeResult>{};
  final Map<String, String> _reverseCache = <String, String>{}; // key: "lat,lng" -> address

  // Simple rate limiter (per operation type)
  DateTime? _lastForwardCallAt;
  DateTime? _lastReverseCallAt;

  // Defaults
  static const Duration _defaultTtl = Duration(days: 7);
  static const Duration _minInterval = Duration(milliseconds: 300);

  // Storage keys
  static const String _kFwdPrefix = 'geocode_fwd_';
  static const String _kRevPrefix = 'geocode_rev_';

  // ------------- Public API -------------

  /// Forward geocoding: address/query -> coordinates.
  /// Cached with TTL using LocalStorage; returns null on failure.
  Future<GeocodeResult?> forwardGeocode(
    String query, {
    Duration ttl = _defaultTtl,
    bool cacheOnly = false,
  }) async {
    final norm = _normalizeQuery(query);
    if (norm.isEmpty) return null;

    // In-memory cache hit
    final memHit = _forwardCache[norm];
    if (memHit != null) return memHit;

    // Disk cache hit
    final diskHit = await _loadForwardFromDisk(norm, ttl: ttl);
    if (diskHit != null) {
      _forwardCache[norm] = diskHit;
      return diskHit;
    }

    if (cacheOnly) return null;

    // Throttle a bit
    await _respectMinInterval(forward: true);

    try {
      // geocoding: locationFromAddress returns List<Location>
      final locations = await locationFromAddress(norm);
      if (locations.isEmpty) return null;

      final loc = locations.first;
      final result = GeocodeResult(
        latitude: loc.latitude,
        longitude: loc.longitude,
        label: query,
      );

      _forwardCache[norm] = result;
      await _saveForwardToDisk(norm, result);

      return result;
    } catch (_) {
      // Network/plugin errors are possible; return null gracefully
      return null;
    }
  }

  /// Reverse geocoding: coordinates -> single-line address (best-effort).
  /// Cached with TTL using LocalStorage; returns null on failure.
  Future<String?> reverseGeocodeToLine(
    double latitude,
    double longitude, {
    Duration ttl = _defaultTtl,
    bool cacheOnly = false,
  }) async {
    final key = _coordKey(latitude, longitude);

    // In-memory cache
    final memHit = _reverseCache[key];
    if (memHit != null && memHit.isNotEmpty) return memHit;

    // Disk cache
    final diskHit = await _loadReverseFromDisk(key, ttl: ttl);
    if (diskHit != null && diskHit.isNotEmpty) {
      _reverseCache[key] = diskHit;
      return diskHit;
    }

    if (cacheOnly) return null;

    await _respectMinInterval(forward: false);

    try {
      // geocoding: placemarkFromCoordinates returns List<Placemark>
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final address = _formatPlacemark(placemarks.first);

      _reverseCache[key] = address;
      await _saveReverseToDisk(key, address);

      return address;
    } catch (_) {
      // Best-effort reverse geocoding; plugin or network may fail
      return null;
    }
  }

  /// Reverse geocoding (raw): returns first Placemark or null on failure.
  Future<Placemark?> reverseGeocodePlacemark(
    double latitude,
    double longitude, {
    bool cacheOnly = false,
    Duration ttl = _defaultTtl,
  }) async {
    final line = await reverseGeocodeToLine(
      latitude,
      longitude,
      cacheOnly: cacheOnly,
      ttl: ttl,
    );
    if (line == null && cacheOnly) return null;

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      return placemarks.isEmpty ? null : placemarks.first;
    } catch (_) {
      return null;
    }
  }

  /// Clears geocoding caches from memory and disk (optionally only forward or reverse).
  Future<void> clearCache({bool forward = true, bool reverse = true}) async {
    if (forward) {
      _forwardCache.clear();
      final fwdKeys = await LocalStorage.instance.getKeysWithPrefix(_kFwdPrefix);
      for (final k in fwdKeys) {
        await LocalStorage.instance.remove(k);
      }
    }
    if (reverse) {
      _reverseCache.clear();
      final revKeys = await LocalStorage.instance.getKeysWithPrefix(_kRevPrefix);
      for (final k in revKeys) {
        await LocalStorage.instance.remove(k);
      }
    }
  }

  // ------------- Internals -------------

  Future<void> _respectMinInterval({required bool forward}) async {
    final now = DateTime.now();
    final last = forward ? _lastForwardCallAt : _lastReverseCallAt;
    if (last != null) {
      final diff = now.difference(last);
      if (diff < _minInterval) {
        await Future<void>.delayed(_minInterval - diff);
      }
    }
    if (forward) {
      _lastForwardCallAt = DateTime.now();
    } else {
      _lastReverseCallAt = DateTime.now();
    }
  }

  String _normalizeQuery(String q) => q.trim();

  String _coordKey(double lat, double lng) =>
      '$_kRevPrefix${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

  String _fwdKey(String normQuery) => '$_kFwdPrefix${base64Encode(utf8.encode(normQuery))}';

  String _formatPlacemark(Placemark p) {
    final parts = <String>[];
    if (p.subLocality != null && p.subLocality!.isNotEmpty) parts.add(p.subLocality!);
    if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
    if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) parts.add(p.administrativeArea!);
    if (p.country != null && p.country!.isNotEmpty) parts.add(p.country!);
    if (p.postalCode != null && p.postalCode!.isNotEmpty) parts.add(p.postalCode!);
    return parts.join(', ');
  }

  // ---- Disk cache (forward) ----

  Future<GeocodeResult?> _loadForwardFromDisk(String normQuery, {required Duration ttl}) async {
    final key = _fwdKey(normQuery);
    final ts = await LocalStorage.instance.getCacheTimestamp(key);
    if (ts == null) return null;
    if (DateTime.now().difference(ts) > ttl) return null;

    final data = await LocalStorage.instance.getJson(key);
    if (data == null) return null;
    try {
      return GeocodeResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveForwardToDisk(String normQuery, GeocodeResult result) async {
    final key = _fwdKey(normQuery);
    await LocalStorage.instance.setJson(key, result.toJson());
    await LocalStorage.instance.setCacheTimestamp(key, DateTime.now());
  }

  // ---- Disk cache (reverse) ----

  Future<String?> _loadReverseFromDisk(String coordKey, {required Duration ttl}) async {
    final ts = await LocalStorage.instance.getCacheTimestamp(coordKey);
    if (ts == null) return null;
    if (DateTime.now().difference(ts) > ttl) return null;

    final raw = await LocalStorage.instance.getString(coordKey);
    return raw;
  }

  Future<void> _saveReverseToDisk(String coordKey, String addressLine) async {
    await LocalStorage.instance.setString(coordKey, addressLine);
    await LocalStorage.instance.setCacheTimestamp(coordKey, DateTime.now());
  }
}
