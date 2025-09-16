// lib/core/storage/location_cache.dart

import 'dart:async';

import '../utils/location_utils.dart';
import '../storage/local_storage.dart';

/// Lightweight snapshot used for caching last-known location without
/// depending on service-layer types.
class LocationSnapshot {
  final double latitude;
  final double longitude;
  final double? accuracy; // meters
  final DateTime timestamp;
  final String? address;

  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
    this.address,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
        'address': address,
      };

  factory LocationSnapshot.fromJson(Map<String, dynamic> json) {
    return LocationSnapshot(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      address: json['address'] as String?,
    );
  }
}

/// Location cache API:
/// - Persist last known location (JSON + timestamp key).
/// - TTL freshness checks.
/// - In-memory derived-distance cache (ephemeral).
/// - Broadcast change events for reactive widgets/providers.
class LocationCache {
  LocationCache._();
  static final LocationCache instance = LocationCache._();

  // Keys to remain compatible with LocationService usage.
  static const String _kLastLocationJson = 'cached_location';
  static const String _kLastLocationTs = 'location';

  // Change events for consumers that want to refresh on updates.
  final StreamController<LocationSnapshot> _changes =
      StreamController<LocationSnapshot>.broadcast();

  Stream<LocationSnapshot> get changes => _changes.stream;

  LocationSnapshot? _memoryLast;

  // Ephemeral in-memory cache for derived distances (e.g., list items)
  // key convention: "<type>/<id>"
  final Map<String, double> _distanceMeters = <String, double>{};
  final Map<String, DateTime> _distanceTs = <String, DateTime>{};

  // ---------- Last known location persistence ----------

  Future<void> saveLast(LocationSnapshot snapshot) async {
    // Clamp to WGS84 and round to reduce noise in cache churn.
    final clamped = LocationUtils.clampToWgs84(
      (LocationUtils.round(
        Coordinates(latitude: snapshot.latitude, longitude: snapshot.longitude),
        fractionDigits: 6,
      )),
    );
    final normalized = LocationSnapshot(
      latitude: clamped.latitude,
      longitude: clamped.longitude,
      accuracy: snapshot.accuracy,
      timestamp: snapshot.timestamp,
      address: snapshot.address,
    );

    await LocalStorage.instance.setJson(_kLastLocationJson, normalized.toJson());
    await LocalStorage.instance
        .setCacheTimestamp(_kLastLocationTs, normalized.timestamp);
    _memoryLast = normalized;

    if (_changes.hasListener) {
      _changes.add(normalized);
    }
  }

  /// Returns the last known location if present and optionally fresh under a TTL.
  Future<LocationSnapshot?> getLast({Duration? maxAge}) async {
    if (_memoryLast != null) {
      if (maxAge == null) return _memoryLast;
      final fresh = DateTime.now().difference(_memoryLast!.timestamp) <= maxAge;
      if (fresh) return _memoryLast;
    }

    final ts = await LocalStorage.instance.getCacheTimestamp(_kLastLocationTs);
    if (ts == null) return null;
    if (maxAge != null && DateTime.now().difference(ts) > maxAge) return null;

    final json = await LocalStorage.instance.getJson(_kLastLocationJson);
    if (json == null) return null;
    final snap = LocationSnapshot.fromJson(json);
    _memoryLast = snap;
    return snap;
  }

  Future<bool> hasFresh(Duration maxAge) async {
    final ts = await LocalStorage.instance.getCacheTimestamp(_kLastLocationTs);
    if (ts == null) return false;
    return DateTime.now().difference(ts) <= maxAge;
  }

  Future<void> clearLast() async {
    _memoryLast = null;
    await LocalStorage.instance.remove(_kLastLocationJson);
    // Keep timestamp removal to mark as stale
    await LocalStorage.instance.remove('cache_timestamp_$_kLastLocationTs');
  }

  // ---------- Derived distances (ephemeral memory cache) ----------

  /// Store a derived distance (meters) for a key like "place/123".
  void putDistance(String key, double meters) {
    _distanceMeters[key] = meters;
    _distanceTs[key] = DateTime.now();
  }

  /// Get a cached distance if present and not older than maxAge.
  double? getDistance(String key, {Duration? maxAge}) {
    final v = _distanceMeters[key];
    if (v == null) return null;
    if (maxAge == null) return v;
    final ts = _distanceTs[key];
    if (ts == null) return null;
    return DateTime.now().difference(ts) <= maxAge ? v : null;
  }

  /// Clear a specific cached distance or the entire distance cache.
  void clearDistance([String? key]) {
    if (key == null) {
      _distanceMeters.clear();
      _distanceTs.clear();
    } else {
      _distanceMeters.remove(key);
      _distanceTs.remove(key);
    }
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}

/// Minimal coordinate model to avoid importing models layer here.
class Coordinates {
  final double latitude;
  final double longitude;
  const Coordinates({required this.latitude, required this.longitude});
}
