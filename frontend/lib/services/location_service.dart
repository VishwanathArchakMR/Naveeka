// lib/services/location_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../core/storage/local_storage.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  whileInUse,
  unknown,
}

class UserLocation {
  final double latitude;
  final double longitude;
  final double? accuracy; // meters
  final DateTime timestamp;
  final String? address;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
    this.address,
  });

  factory UserLocation.fromPosition(Position position, {String? address}) {
    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp ?? DateTime.now(),
      address: address,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
        'address': address,
      };

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    return UserLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      address: json['address'] as String?,
    );
  }

  /// Distance to lat/lng in meters using Geolocator’s Haversine under the hood. [3]
  double distanceMetersTo(double lat, double lng) {
    return Geolocator.distanceBetween(latitude, longitude, lat, lng);
  }

  /// Convenience: distance in km. [3]
  double distanceKmTo(double lat, double lng) => distanceMetersTo(lat, lng) / 1000.0;

  @override
  String toString() => 'UserLocation($latitude, $longitude)';
}

class LocationService {
  LocationService._internal();
  static final LocationService _instance = LocationService._internal();
  static LocationService get instance => _instance;

  UserLocation? _currentLocation;
  StreamSubscription<Position>? _positionStreamSub;
  final StreamController<UserLocation> _locationCtrl = StreamController<UserLocation>.broadcast();

  bool _isInitialized = false;
  bool _isTracking = false;

  // Location request configuration
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // meters
  );

  // Cache keys
  static const String _cacheKeyLocation = 'cached_location';
  static const String _cacheKeyTs = 'location';

  /// Initialize service: load cached, ensure permission, get a fresh fix when possible. [13][3]
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _loadCachedLocation();

      final hasPermission = await _checkAndRequestPermissions();
      if (hasPermission) {
        await _getCurrentLocationOnce();
      }
    } catch (e) {
      debugPrint('LocationService init error: $e');
    } finally {
      _isInitialized = true;
    }
  }

  /// Check services + permission and request if needed. [13][10]
  Future<bool> _checkAndRequestPermissions() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever.');
        return false;
      }

      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied.');
        return false;
      }

      // Record that location is enabled for app UX
      await LocalStorage.instance.setLocationEnabled(true);
      return true;
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  /// Get current position once with timeout and last-known fallback. [3][1]
  Future<UserLocation?> _getCurrentLocationOnce() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final loc = UserLocation.fromPosition(position);
      // Kick off reverse-geocode without blocking UI.
      unawaited(_reverseGeocodeAndUpdate(loc));

      _currentLocation = loc;
      _locationCtrl.add(loc);
      await _cacheLocation(loc);
      return loc;
    } on TimeoutException {
      // Try last-known when current fix times out. [3][1]
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final loc = UserLocation.fromPosition(last);
          unawaited(_reverseGeocodeAndUpdate(loc));
          _currentLocation = loc;
          _locationCtrl.add(loc);
          await _cacheLocation(loc);
          return loc;
        }
      } catch (_) {}
      return _currentLocation; // maybe from cache
    } catch (e) {
      debugPrint('Get current location error: $e');
      return _currentLocation; // maybe from cache
    }
  }

  /// Start continuous tracking with position stream and address enrichment. [3]
  Future<void> startTracking() async {
    if (_isTracking) return;
    final hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) return;

    try {
      _positionStreamSub = Geolocator.getPositionStream(locationSettings: _locationSettings).listen(
        (Position position) {
          final loc = UserLocation.fromPosition(position);
          _currentLocation = loc;
          _locationCtrl.add(loc);
          unawaited(_cacheLocation(loc));
          // Reverse-geocode in the background to avoid blocking stream. [9]
          unawaited(_reverseGeocodeAndUpdate(loc));
        },
        onError: (error) => debugPrint('Location stream error: $error'),
      );
      _isTracking = true;
    } catch (e) {
      debugPrint('Start tracking error: $e');
    }
  }

  /// Stop streaming updates.
  void stopTracking() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _isTracking = false;
  }

  /// Public API: get latest location (fresh or cached). [3]
  Future<UserLocation?> getCurrentLocation({bool forceRefresh = false}) async {
    if (!_isInitialized) {
      await init();
    }
    if (forceRefresh || _currentLocation == null) {
      return _getCurrentLocationOnce();
    }
    return _currentLocation;
  }

  /// Reverse-geocodes and updates the cached location with address. [9][12]
  Future<void> _reverseGeocodeAndUpdate(UserLocation loc) async {
    try {
      final placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
      if (placemarks.isEmpty) return;
      final address = _formatAddress(placemarks.first);

      final updated = UserLocation(
        latitude: loc.latitude,
        longitude: loc.longitude,
        accuracy: loc.accuracy,
        timestamp: loc.timestamp,
        address: address,
      );

      _currentLocation = updated;
      _locationCtrl.add(updated);
      await _cacheLocation(updated);
    } catch (e) {
      // Reverse geocoding can fail due to network; keep silent fallback. [19]
      if (kDebugMode) {
        debugPrint('Reverse geocode failed: $e');
      }
    }
  }

  /// Simple, human-readable address line for UI badges. [9]
  String _formatAddress(Placemark p) {
    final parts = <String>[];
    if (p.subLocality?.isNotEmpty == true) parts.add(p.subLocality!);
    if (p.locality?.isNotEmpty == true) parts.add(p.locality!);
    if (p.administrativeArea?.isNotEmpty == true) parts.add(p.administrativeArea!);
    if (p.country?.isNotEmpty == true) parts.add(p.country!);
    return parts.join(', ');
  }

  /// Cache location JSON and timestamp using LocalStorage helpers. [21]
  Future<void> _cacheLocation(UserLocation location) async {
    try {
      await LocalStorage.instance.setJson(_cacheKeyLocation, location.toJson());
      await LocalStorage.instance.setCacheTimestamp(_cacheKeyTs, location.timestamp);
    } catch (e) {
      debugPrint('Cache location error: $e');
    }
  }

  /// Load cached location if fresh (< 1 hour). [21]
  Future<void> _loadCachedLocation() async {
    try {
      final ts = await LocalStorage.instance.getCacheTimestamp(_cacheKeyTs);
      if (ts == null) return;
      if (DateTime.now().difference(ts) > const Duration(hours: 1)) return;

      final data = await LocalStorage.instance.getJson(_cacheKeyLocation);
      if (data == null) return;
      final loc = UserLocation.fromJson(data);
      _currentLocation = loc;
      _locationCtrl.add(loc);
    } catch (e) {
      debugPrint('Load cached location error: $e');
    }
  }

  /// Utilities

  /// Distance between two points in meters. [3]
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

  /// Distance in kilometers. [3]
  static double distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) =>
      distanceMeters(lat1, lng1, lat2, lng2) / 1000.0;

  /// Formats distance like "850 m" or "2.3 km".
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000.0;
    return km >= 10 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
  }

  /// True if within a radius (meters).
  static bool isWithinRadiusMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    double radiusMeters,
  ) =>
      distanceMeters(lat1, lng1, lat2, lng2) <= radiusMeters;

  /// Permission status mapping.
  Future<LocationPermissionStatus> getPermissionStatus() async {
    try {
      final p = await Geolocator.checkPermission();
      switch (p) {
        case LocationPermission.always:
          return LocationPermissionStatus.granted;
        case LocationPermission.whileInUse:
          return LocationPermissionStatus.whileInUse;
        case LocationPermission.denied:
          return LocationPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return LocationPermissionStatus.deniedForever;
        case LocationPermission.unableToDetermine:
          return LocationPermissionStatus.unknown;
      }
    } catch (_) {
      return LocationPermissionStatus.unknown;
    }
  }

  /// Open app settings for permissions page. [3]
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// Open OS location settings (enable GPS). [3]
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  // Getters
  UserLocation? get currentLocation => _currentLocation;
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;
  Stream<UserLocation> get locationStream => _locationCtrl.stream;

  /// Dispose resources (call on app shutdown).
  void dispose() {
    stopTracking();
    _locationCtrl.close();
  }
}

