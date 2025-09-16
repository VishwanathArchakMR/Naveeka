// lib/services/directions_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/coordinates.dart';

/// Supported travel modes; map providers will translate these to their profiles. [driving|walking|bicycling|transit]
enum TravelMode { driving, walking, bicycling, transit }

/// Units for distance display if needed by providers or formatting layers.
enum DistanceUnit { metric, imperial }

/// Top-level request to fetch directions.
@immutable
class DirectionsRequest {
  const DirectionsRequest({
    required this.origin,
    required this.destination,
    this.waypoints = const <Coordinates>[],
    this.mode = TravelMode.driving,
    this.departureTime, // for transit and traffic-aware requests
    this.alternatives = false,
    this.avoidTolls = false,
    this.avoidHighways = false,
    this.unit = DistanceUnit.metric,
    this.language, // e.g., "en", "hi"
  });

  final Coordinates origin;
  final Coordinates destination;
  final List<Coordinates> waypoints;
  final TravelMode mode;
  final DateTime? departureTime;
  final bool alternatives;
  final bool avoidTolls;
  final bool avoidHighways;
  final DistanceUnit unit;
  final String? language;

  DirectionsRequest copyWith({
    Coordinates? origin,
    Coordinates? destination,
    List<Coordinates>? waypoints,
    TravelMode? mode,
    DateTime? departureTime,
    bool? alternatives,
    bool? avoidTolls,
    bool? avoidHighways,
    DistanceUnit? unit,
    String? language,
  }) {
    return DirectionsRequest(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      waypoints: waypoints ?? this.waypoints,
      mode: mode ?? this.mode,
      departureTime: departureTime ?? this.departureTime,
      alternatives: alternatives ?? this.alternatives,
      avoidTolls: avoidTolls ?? this.avoidTolls,
      avoidHighways: avoidHighways ?? this.avoidHighways,
      unit: unit ?? this.unit,
      language: language ?? this.language,
    );
  }
}

/// A single instruction step; instruction text is provider-specific and optional.
@immutable
class DirectionsStep {
  const DirectionsStep({
    this.instruction,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.polyline, // encoded polyline for this step, if present
    this.start,
    this.end,
  });

  final String? instruction;
  final int distanceMeters;
  final int durationSeconds;
  final String? polyline;
  final Coordinates? start;
  final Coordinates? end;

  DirectionsStep copyWith({
    String? instruction,
    int? distanceMeters,
    int? durationSeconds,
    String? polyline,
    Coordinates? start,
    Coordinates? end,
  }) {
    return DirectionsStep(
      instruction: instruction ?? this.instruction,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      polyline: polyline ?? this.polyline,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}

/// A leg between two stops in a route; most simple routes have 1 leg. 
@immutable
class DirectionsLeg {
  const DirectionsLeg({
    required this.start,
    required this.end,
    this.startAddress,
    this.endAddress,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.steps = const <DirectionsStep>[],
  });

  final Coordinates start;
  final Coordinates end;
  final String? startAddress;
  final String? endAddress;
  final int distanceMeters;
  final int durationSeconds;
  final List<DirectionsStep> steps;

  DirectionsLeg copyWith({
    Coordinates? start,
    Coordinates? end,
    String? startAddress,
    String? endAddress,
    int? distanceMeters,
    int? durationSeconds,
    List<DirectionsStep>? steps,
  }) {
    return DirectionsLeg(
      start: start ?? this.start,
      end: end ?? this.end,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      steps: steps ?? this.steps,
    );
  }
}

/// A complete route with one or more legs and an overview polyline for rendering.
@immutable
class DirectionsRoute {
  const DirectionsRoute({
    this.summary,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.legs = const <DirectionsLeg>[],
    this.overviewPolyline,
    this.provider, // e.g., "google", "openrouteservice", "fallback"
  });

  final String? summary;
  final int distanceMeters;
  final int durationSeconds;
  final List<DirectionsLeg> legs;
  final String? overviewPolyline;
  final String? provider;

  DirectionsRoute copyWith({
    String? summary,
    int? distanceMeters,
    int? durationSeconds,
    List<DirectionsLeg>? legs,
    String? overviewPolyline,
    String? provider,
  }) {
    return DirectionsRoute(
      summary: summary ?? this.summary,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      legs: legs ?? this.legs,
      overviewPolyline: overviewPolyline ?? this.overviewPolyline,
      provider: provider ?? this.provider,
    );
  }
}

/// The fetched result; often multiple routes if alternatives=true.
@immutable
class DirectionsResult {
  const DirectionsResult({
    this.routes = const <DirectionsRoute>[],
    this.raw, // keep raw provider response for diagnostics if desired
  });

  final List<DirectionsRoute> routes;
  final Map<String, dynamic>? raw;

  bool get hasRoute => routes.isNotEmpty;
  DirectionsRoute? get firstRoute => hasRoute ? routes.first : null;

  DirectionsResult copyWith({
    List<DirectionsRoute>? routes,
    Map<String, dynamic>? raw,
  }) {
    return DirectionsResult(
      routes: routes ?? this.routes,
      raw: raw ?? this.raw,
    );
  }
}

/// Contract for any directions provider implementation (Google/ORS/Mapbox/custom).
abstract class DirectionsProvider {
  Future<DirectionsResult> fetch(DirectionsRequest request);
}

/// A safe no-network fallback: returns a single-leg route using great-circle distance
/// and a straight-line polyline between points, estimating duration by mode. 
class HaversineFallbackProvider implements DirectionsProvider {
  const HaversineFallbackProvider();

  @override
  Future<DirectionsResult> fetch(DirectionsRequest request) async {
    final points = <Coordinates>[
      request.origin,
      ...request.waypoints,
      request.destination,
    ];

    // Total distance = sum of segment distances using Coordinates.distanceTo (meters).
    int distance = 0;
    for (var i = 0; i < points.length - 1; i++) {
      distance += points[i].distanceTo(points[i + 1]).round();
    }

    // Crude duration model (seconds) per mode. Tune as needed.
    // driving: ~50 km/h, walking: ~5 km/h, bicycling: ~15 km/h, transit: ~30 km/h placeholder.
    final speedKmh = switch (request.mode) {
      TravelMode.driving => 50.0,
      TravelMode.walking => 5.0,
      TravelMode.bicycling => 15.0,
      TravelMode.transit => 30.0,
    };
    final duration = (distance / 1000.0) / speedKmh * 3600.0;

    final leg = DirectionsLeg(
      start: request.origin,
      end: request.destination,
      distanceMeters: distance,
      durationSeconds: duration.round(),
      steps: const <DirectionsStep>[],
    );

    final overview = PolylineCodec.encode(points); // Google-style encoded polyline
    final route = DirectionsRoute(
      summary: 'Direct',
      distanceMeters: distance,
      durationSeconds: duration.round(),
      legs: <DirectionsLeg>[leg],
      overviewPolyline: overview,
      provider: 'fallback',
    );

    return DirectionsResult(routes: <DirectionsRoute>[route], raw: null);
  }
}

/// Utility for Google Encoded Polyline Algorithm (precision 5 by default). 
/// See specification for details. [1]
class PolylineCodec {
  static String encode(List<Coordinates> coords, {int precision = 5}) {
    int lastLat = 0;
    int lastLng = 0;
    final factor = pow10(precision);
    final StringBuffer result = StringBuffer();

    for (final c in coords) {
      final lat = (c.latitude * factor).round();
      final lng = (c.longitude * factor).round();

      _encodeValue(lat - lastLat, result);
      _encodeValue(lng - lastLng, result);

      lastLat = lat;
      lastLng = lng;
    }
    return result.toString();
  }

  static List<Coordinates> decode(String polyline, {int precision = 5}) {
    final coords = <Coordinates>[];
    final int len = polyline.length;
    int index = 0;
    int lat = 0;
    int lng = 0;
    final factor = pow10(precision).toDouble();

    while (index < len) {
      final dlat = _decodeValue(polyline, index);
      index = dlat.nextIndex;
      lat += dlat.value;

      final dlng = _decodeValue(polyline, index);
      index = dlng.nextIndex;
      lng += dlng.value;

      coords.add(Coordinates(
        latitude: lat / factor,
        longitude: lng / factor,
      ));
    }
    return coords;
  }

  static void _encodeValue(int v, StringBuffer out) {
    var value = v < 0 ? ~(v << 1) : (v << 1);
    while (value >= 0x20) {
      final nextValue = (0x20 | (value & 0x1f)) + 63;
      out.writeCharCode(nextValue);
      value >>= 5;
    }
    out.writeCharCode(value + 63);
  } // Based on Google’s encoded polyline bit-packing. [1]

  static _DecodeResult _decodeValue(String s, int index) {
    int result = 0;
    int shift = 0;
    int b;
    do {
      b = s.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    return _DecodeResult(value: value, nextIndex: index);
  } // Mirrors decoding rules of the spec. [1]

  static int pow10(int exp) {
    var r = 1;
    for (var i = 0; i < exp; i++) {
      r *= 10;
    }
    return r;
  }
}

@immutable
class _DecodeResult {
  const _DecodeResult({required this.value, required this.nextIndex});
  final int value;
  final int nextIndex;
}

/// Top-level service with pluggable provider; default uses a safe offline fallback.
/// Wire this to real providers (Google/ORS) without changing calling code.
class DirectionsService {
  DirectionsService({DirectionsProvider? provider})
      : _provider = provider ?? const HaversineFallbackProvider();

  final DirectionsProvider _provider;

  Future<DirectionsResult> getDirections(DirectionsRequest request) {
    return _provider.fetch(request);
  }
}

/// Sketch: Google Directions provider (HTTP not included here).
/// Translate TravelMode to Google modes and parse their JSON into DirectionsResult. [7]
abstract class GoogleDirectionsAdapter implements DirectionsProvider {
  String get apiKey;

  @protected
  String googleMode(TravelMode mode) {
    return switch (mode) {
      TravelMode.driving => 'driving',
      TravelMode.walking => 'walking',
      TravelMode.bicycling => 'bicycling',
      TravelMode.transit => 'transit',
    };
  } // Maps app modes to Google’s mode strings. [7]

  // Implement fetch() in an app-specific data layer using your HTTP client, then
  // map the JSON into DirectionsResult using the shared models and PolylineCodec.
}

/// Sketch: OpenRouteService provider (HTTP not included here).
/// Translate TravelMode to ORS profiles (e.g., driving-car, foot-walking) and parse JSON. [6][15]
abstract class OpenRouteServiceAdapter implements DirectionsProvider {
  String get apiKey;

  @protected
  String orsProfile(TravelMode mode) {
    return switch (mode) {
      TravelMode.driving => 'driving-car',
      TravelMode.walking => 'foot-walking',
      TravelMode.bicycling => 'cycling-regular',
      TravelMode.transit => 'driving-car', // ORS directions is not public-transit; use fallback or other APIs
    };
  } // Profiles based on ORS docs; transit requires separate services. [6][18]

  // Implement fetch() with your HTTP client, mapping JSON to DirectionsResult.
}
