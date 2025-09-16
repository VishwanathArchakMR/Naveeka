// lib/models/unit_system.dart

/// Unit system for measurements (metric vs imperial)
enum UnitSystem {
  metric,
  imperial,
}

extension UnitSystemExtension on UnitSystem {
  /// Get the distance unit for this system
  String get distanceUnit => this == UnitSystem.metric ? 'km' : 'mi';
  
  /// Get the speed unit for this system
  String get speedUnit => this == UnitSystem.metric ? 'km/h' : 'mph';
  
  /// Get the temperature unit for this system
  String get temperatureUnit => this == UnitSystem.metric ? '°C' : '°F';
  
  /// Convert distance from meters to the appropriate unit
  double convertDistance(double meters) {
    if (this == UnitSystem.metric) {
      return meters / 1000; // Convert to kilometers
    } else {
      return meters * 3.28084 / 5280; // Convert to miles
    }
  }
  
  /// Convert speed from m/s to the appropriate unit
  double convertSpeed(double metersPerSecond) {
    if (this == UnitSystem.metric) {
      return metersPerSecond * 3.6; // Convert to km/h
    } else {
      return metersPerSecond * 2.23694; // Convert to mph
    }
  }
}

