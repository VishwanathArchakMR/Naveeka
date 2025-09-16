// lib/services/distance_service.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../models/coordinates.dart';

/// Distance units for formatting and display preferences.
enum DistanceUnit { metric, imperial }

/// A distance measurement with value and unit for consistent formatting.
@immutable
class Distance {
  const Distance({
    required this.meters,
    this.unit = DistanceUnit.metric,
  });

  /// Distance in meters (always stored as base unit).
  final double meters;
  
  /// Preferred display unit.
  final DistanceUnit unit;

  /// Kilometers (metric).
  double get kilometers => meters / 1000.0;

  /// Miles (imperial).
  double get miles => meters * 0.000621371;

  /// Feet (imperial).
  double get feet => meters * 3.28084;

  /// Human-readable distance string with appropriate unit and precision.
  String get formatted {
    switch (unit) {
      case DistanceUnit.metric:
        if (meters < 1000) {
          return '${meters.round()}m';
        } else if (kilometers < 10) {
          return '${kilometers.toStringAsFixed(1)}km';
        } else {
          return '${kilometers.round()}km';
        }
      case DistanceUnit.imperial:
        if (feet < 1000) {
          return '${feet.round()}ft';
        } else if (miles < 10) {
          return '${miles.toStringAsFixed(1)}mi';
        } else {
          return '${miles.round()}mi';
        }
    }
  }

  /// Short format for compact UI (e.g., list items, chips).
  String get compact {
    switch (unit) {
      case DistanceUnit.metric:
        return meters < 1000 ? '${meters.round()}m' : '${kilometers.toStringAsFixed(kilometers < 10 ? 1 : 0)}k';
      case DistanceUnit.imperial:
        return feet < 1000 ? '${feet.round()}f' : '${miles.toStringAsFixed(miles < 10 ? 1 : 0)}m';
    }
  }

  /// "Away" suffix format commonly used in discovery lists.
  String get away => '$formatted away';

  Distance copyWith({double? meters, DistanceUnit? unit}) {
    return Distance(meters: meters ?? this.meters, unit: unit ?? this.unit);
  }

  @override
  bool operator ==(Object other) => other is Distance && other.meters == meters && other.unit == unit;

  @override
  int get hashCode => Object.hash(meters, unit);

  @override
  String toString() => formatted;
}

/// Result of a proximity calculation with the target item and computed distance.
@immutable
class ProximityResult<T> {
  const ProximityResult({
    required this.item,
    required this.distance,
  });

  final T item;
  final Distance distance;

  @override
  bool operator ==(Object other) => 
      other is ProximityResult<T> && other.item == item && other.distance == distance;

  @override
  int get hashCode => Object.hash(item, distance);
}

/// Contract for anything that has a location (coordinates).
abstract class Locatable {
  Coordinates? get coordinates;
}

/// Mixin for models that implement Locatable to get distance calculations.
mixin LocationAware {
  Coordinates? get coordinates;

  /// Calculate distance to another coordinate.
  Distance? distanceTo(Coordinates? other, {DistanceUnit unit = DistanceUnit.metric}) {
    if (coordinates == null || other == null) return null;
    return Distance(meters: coordinates!.distanceTo(other), unit: unit);
  }

  /// Calculate distance to another locatable entity.
  Distance? distanceToLocatable(Locatable other, {DistanceUnit unit = DistanceUnit.metric}) {
    return distanceTo(other.coordinates, unit: unit);
  }
}

/// Efficient distance calculations and proximity operations.
class DistanceService {
  const DistanceService({
    this.defaultUnit = DistanceUnit.metric,
    this.cacheEnabled = true,
  });

  final DistanceUnit defaultUnit;
  final bool cacheEnabled;

  // Simple cache for repeated distance calculations (same coordinate pairs).
  static final Map<String, double> _distanceCache = <String, double>{};

  /// Calculate distance between two coordinates with optional caching.
  Distance? calculate(
    Coordinates? from,
    Coordinates? to, {
    DistanceUnit? unit,
  }) {
    if (from == null || to == null) return null;

    final useUnit = unit ?? defaultUnit;
    final cacheKey = cacheEnabled ? '${from.latitude},${from.longitude}-${to.latitude},${to.longitude}' : '';

    double meters;
    if (cacheEnabled && _distanceCache.containsKey(cacheKey)) {
      meters = _distanceCache[cacheKey]!;
    } else {
      meters = from.distanceTo(to);
      if (cacheEnabled) {
        _distanceCache[cacheKey] = meters;
      }
    }

    return Distance(meters: meters, unit: useUnit);
  }

  /// Batch calculate distances from an origin to multiple targets.
  List<ProximityResult<T>> calculateDistances<T extends Locatable>(
    Coordinates origin,
    List<T> targets, {
    DistanceUnit? unit,
  }) {
    final useUnit = unit ?? defaultUnit;
    return targets
        .map((target) {
          final distance = calculate(origin, target.coordinates, unit: useUnit);
          return distance != null ? ProximityResult<T>(item: target, distance: distance) : null;
        })
        .whereType<ProximityResult<T>>()
        .toList(growable: false);
  }

  /// Sort items by distance from an origin (closest first).
  List<ProximityResult<T>> sortByProximity<T extends Locatable>(
    Coordinates origin,
    List<T> items, {
    DistanceUnit? unit,
  }) {
    final results = calculateDistances(origin, items, unit: unit);
    results.sort((a, b) => a.distance.meters.compareTo(b.distance.meters));
    return results;
  }

  /// Filter items within a radius of an origin.
  List<ProximityResult<T>> filterByRadius<T extends Locatable>(
    Coordinates origin,
    List<T> items,
    double radiusMeters, {
    DistanceUnit? unit,
  }) {
    return calculateDistances(origin, items, unit: unit)
        .where((result) => result.distance.meters <= radiusMeters)
        .toList(growable: false);
  }

  /// Find the closest item to an origin.
  ProximityResult<T>? findClosest<T extends Locatable>(
    Coordinates origin,
    List<T> items, {
    DistanceUnit? unit,
  }) {
    if (items.isEmpty) return null;
    final sorted = sortByProximity(origin, items, unit: unit);
    return sorted.isEmpty ? null : sorted.first;
  }

  /// Group items by distance ranges (useful for "nearby", "moderate", "far" categories).
  Map<String, List<ProximityResult<T>>> groupByDistanceRanges<T extends Locatable>(
    Coordinates origin,
    List<T> items, {
    double nearbyMeters = 1000,     // < 1km
    double moderateMeters = 10000,  // 1-10km
    DistanceUnit? unit,
  }) {
    final results = calculateDistances(origin, items, unit: unit);
    
    final groups = <String, List<ProximityResult<T>>>{
      'nearby': <ProximityResult<T>>[],
      'moderate': <ProximityResult<T>>[],
      'far': <ProximityResult<T>>[],
    };

    for (final result in results) {
      if (result.distance.meters <= nearbyMeters) {
        groups['nearby']!.add(result);
      } else if (result.distance.meters <= moderateMeters) {
        groups['moderate']!.add(result);
      } else {
        groups['far']!.add(result);
      }
    }

    return groups;
  }

  /// Calculate the centroid (center point) of a list of coordinates.
  Coordinates? calculateCentroid(List<Coordinates> coordinates) {
    if (coordinates.isEmpty) return null;
    if (coordinates.length == 1) return coordinates.first;

    // Convert to Cartesian, average, then convert back to avoid longitude wrap issues
    double x = 0, y = 0, z = 0;

    for (final coord in coordinates) {
      final latRad = coord.latitude * math.pi / 180;
      final lngRad = coord.longitude * math.pi / 180;

      x += math.cos(latRad) * math.cos(lngRad);
      y += math.cos(latRad) * math.sin(lngRad);
      z += math.sin(latRad);
    }

    final len = coordinates.length.toDouble();
    x /= len;
    y /= len;
    z /= len;

    final centralLng = math.atan2(y, x);
    final centralSqrt = math.sqrt(x * x + y * y);
    final centralLat = math.atan2(z, centralSqrt);

    return Coordinates(
      latitude: centralLat * 180 / math.pi,
      longitude: centralLng * 180 / math.pi,
    );
  }

  /// Calculate bounding box that contains all coordinates with optional padding.
  Map<String, double>? calculateBounds(
    List<Coordinates> coordinates, {
    double paddingMeters = 1000, // Add padding around the bounds
  }) {
    if (coordinates.isEmpty) return null;

    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (final coord in coordinates) {
      minLat = math.min(minLat, coord.latitude);
      maxLat = math.max(maxLat, coord.latitude);
      minLng = math.min(minLng, coord.longitude);
      maxLng = math.max(maxLng, coord.longitude);
    }

    // Add padding (approximate - 1 degree ≈ 111km)
    final latPadding = paddingMeters / 111000;
    final lngPadding = paddingMeters / (111000 * math.cos(((minLat + maxLat) / 2) * math.pi / 180));

    return <String, double>{
      'minLat': minLat - latPadding,
      'maxLat': maxLat + latPadding,
      'minLng': minLng - lngPadding,
      'maxLng': maxLng + lngPadding,
    };
  }

  /// Clear the distance calculation cache (useful for memory management).
  static void clearCache() => _distanceCache.clear();

  /// Get current cache size (for debugging/monitoring).
  static int get cacheSize => _distanceCache.length;
}

/// Global distance service instance for convenient access.
const DistanceService distanceService = DistanceService();

/// Helper extensions for common models to add distance capabilities.
extension PlaceDistance on Locatable {
  Distance? distanceFrom(Coordinates origin, {DistanceUnit unit = DistanceUnit.metric}) {
    return distanceService.calculate(origin, coordinates, unit: unit);
  }
}

/// Batch distance calculation for lists of locatable items.
extension LocationList<T extends Locatable> on List<T> {
  /// Sort this list by distance from origin (closest first).
  List<ProximityResult<T>> sortedByDistance(
    Coordinates origin, {
    DistanceUnit unit = DistanceUnit.metric,
  }) {
    return distanceService.sortByProximity(origin, this, unit: unit);
  }

  /// Filter items within radius of origin.
  List<ProximityResult<T>> withinRadius(
    Coordinates origin,
    double radiusMeters, {
    DistanceUnit unit = DistanceUnit.metric,
  }) {
    return distanceService.filterByRadius(origin, this, radiusMeters, unit: unit);
  }

  /// Find the closest item to origin.
  ProximityResult<T>? closest(
    Coordinates origin, {
    DistanceUnit unit = DistanceUnit.metric,
  }) {
    return distanceService.findClosest(origin, this, unit: unit);
  }
}
