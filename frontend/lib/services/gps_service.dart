// lib/services/gps_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/coordinates.dart';

/// Permission states modeled to cover Android/iOS flows.
enum GpsPermissionStatus {
  granted,
  denied,
  deniedForever,
  restricted,
  serviceDisabled,
  unknown,
}

/// Desired accuracy tiers to map to underlying providers.
enum GpsAccuracy { lowest, low, medium, high, bestForNavigation }

/// Immutable position sample compatible with app models.
@immutable
class GpsPosition {
  const GpsPosition({
    required this.coordinates,
    this.accuracyMeters,
    this.altitudeMeters,
    this.speedMps,
    this.bearingDegrees,
    required this.timestamp,
  });

  final Coordinates coordinates;
  final double? accuracyMeters;
  final double? altitudeMeters;
  final double? speedMps;
  final double? bearingDegrees;
  final DateTime timestamp;

  GpsPosition copyWith({
    Coordinates? coordinates,
    double? accuracyMeters,
    double? altitudeMeters,
    double? speedMps,
    double? bearingDegrees,
    DateTime? timestamp,
  }) {
    return GpsPosition(
      coordinates: coordinates ?? this.coordinates,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      altitudeMeters: altitudeMeters ?? this.altitudeMeters,
      speedMps: speedMps ?? this.speedMps,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Streaming configuration for continuous updates.
@immutable
class GpsSettings {
  const GpsSettings({
    this.accuracy = GpsAccuracy.high,
    this.distanceFilterMeters = 10, // suppress noise with a default filter
    this.intervalMs = 2000, // provider may ignore if distanceFilter dominates
    this.allowBackground = false, // platform setup required if true
  });

  final GpsAccuracy accuracy;
  final int distanceFilterMeters;
  final int intervalMs;
  final bool allowBackground;

  GpsSettings copyWith({
    GpsAccuracy? accuracy,
    int? distanceFilterMeters,
    int? intervalMs,
    bool? allowBackground,
  }) {
    return GpsSettings(
      accuracy: accuracy ?? this.accuracy,
      distanceFilterMeters: distanceFilterMeters ?? this.distanceFilterMeters,
      intervalMs: intervalMs ?? this.intervalMs,
      allowBackground: allowBackground ?? this.allowBackground,
    );
  }
}

/// Provider contract to integrate concrete plugins (e.g., Geolocator, Location).
abstract class GpsProvider {
  Future<bool> isServiceEnabled();
  Future<GpsPermissionStatus> checkPermission();
  Future<GpsPermissionStatus> requestPermission();

  Future<GpsPosition> getCurrentPosition({GpsAccuracy accuracy = GpsAccuracy.high});

  Stream<GpsPosition> getPositionStream(GpsSettings settings);
}

/// A mock provider for testing/dev without device sensors.
class MockGpsProvider implements GpsProvider {
  const MockGpsProvider({this.path = const <Coordinates>[], this.period = const Duration(seconds: 1)});

  final List<Coordinates> path;
  final Duration period;

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<GpsPermissionStatus> checkPermission() async => GpsPermissionStatus.granted;

  @override
  Future<GpsPermissionStatus> requestPermission() async => GpsPermissionStatus.granted;

  @override
  Future<GpsPosition> getCurrentPosition({GpsAccuracy accuracy = GpsAccuracy.high}) async {
    final c = path.isNotEmpty ? path.first : const Coordinates(latitude: 0, longitude: 0);
    return GpsPosition(coordinates: c, timestamp: DateTime.now().toUtc());
  }

  @override
  Stream<GpsPosition> getPositionStream(GpsSettings settings) async* {
    if (path.isEmpty) {
      while (true) {
        yield GpsPosition(coordinates: const Coordinates(latitude: 0, longitude: 0), timestamp: DateTime.now().toUtc());
        await Future<void>.delayed(period);
      }
    } else {
      var i = 0;
      while (true) {
        final now = DateTime.now().toUtc();
        final curr = path[i % path.length];
        final prev = path[(i - 1) < 0 ? 0 : (i - 1) % path.length];
        final dist = prev.distanceTo(curr); // meters
        final speed = (dist / period.inMilliseconds) * 1000; // m/s
        final bearing = prev == curr ? 0.0 : prev.bearingTo(curr);
        yield GpsPosition(
          coordinates: curr,
          speedMps: speed.isFinite ? speed : null,
          bearingDegrees: bearing.isFinite ? bearing : null,
          timestamp: now,
        );
        i++;
        await Future<void>.delayed(period);
      }
    }
  }
}

/// High-level GPS service with permission flow, single shot, and streaming APIs.
/// Wire a real provider (Geolocator/Location) or the mock provider.
class GpsService {
  GpsService({required GpsProvider provider}) : _provider = provider;

  final GpsProvider _provider;

  StreamSubscription<GpsPosition>? _sub;
  final StreamController<GpsPosition> _controller = StreamController<GpsPosition>.broadcast();

  Stream<GpsPosition> get stream => _controller.stream;

  Future<bool> isServiceEnabled() => _provider.isServiceEnabled();

  Future<GpsPermissionStatus> checkPermission() => _provider.checkPermission();

  Future<GpsPermissionStatus> ensurePermission() async {
    final current = await _provider.checkPermission();
    if (current == GpsPermissionStatus.granted) return current;
    final requested = await _provider.requestPermission();
    return requested;
  }

  Future<GpsPosition> getCurrentPosition({GpsAccuracy accuracy = GpsAccuracy.high}) async {
    final enabled = await _provider.isServiceEnabled();
    if (!enabled) {
      return Future.error('Location services are disabled.');
    }
    final perm = await ensurePermission();
    if (perm != GpsPermissionStatus.granted) {
      return Future.error('Location permission not granted: $perm');
    }
    return _provider.getCurrentPosition(accuracy: accuracy);
  }

  Future<void> start(GpsSettings settings) async {
    await stop();

    final enabled = await _provider.isServiceEnabled();
    if (!enabled) {
      throw StateError('Location services are disabled.');
    }
    final perm = await ensurePermission();
    if (perm != GpsPermissionStatus.granted) {
      throw StateError('Location permission not granted: $perm');
    }

    _sub = _provider.getPositionStream(settings).listen(
      (pos) {
        if (!_controller.isClosed) {
          _controller.add(pos);
        }
      },
      onError: (e, st) {
        if (!_controller.isClosed) {
          _controller.addError(e, st);
        }
      },
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}

/// Optional: a thin adapter base showing how to map app enums to plugin enums.
/// Implementations should live in a separate file that imports the chosen plugin.
abstract class GeolocatorAdapterBase implements GpsProvider {
  const GeolocatorAdapterBase();

  // Map app accuracy to Geolocator's LocationAccuracy.
  dynamic mapAccuracy(GpsAccuracy a) {
    switch (a) {
      case GpsAccuracy.lowest:
        return 'lowest';
      case GpsAccuracy.low:
        return 'low';
      case GpsAccuracy.medium:
        return 'medium';
      case GpsAccuracy.high:
        return 'high';
      case GpsAccuracy.bestForNavigation:
        return 'bestForNavigation';
    }
  }

  // Convert plugin permission enum to app enum.
  GpsPermissionStatus mapPermission(dynamic pluginStatus) {
    final s = pluginStatus?.toString().toLowerCase() ?? '';
    if (s.contains('deniedforever')) return GpsPermissionStatus.deniedForever;
    if (s.contains('denied')) return GpsPermissionStatus.denied;
    if (s.contains('restricted')) return GpsPermissionStatus.restricted;
    if (s.contains('granted') || s.contains('whileinuse') || s.contains('always')) {
      return GpsPermissionStatus.granted;
    }
    return GpsPermissionStatus.unknown;
  }
}
