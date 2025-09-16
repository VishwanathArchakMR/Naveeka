// lib/models/location.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'coordinates.dart';

/// Represents a postal address; toString() composes a human-readable single line.
@immutable
class Address {
  const Address({
    this.street,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.landmark,
  });

  final String? street;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? landmark;

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: (json['street'] as String?)?.toString(),
      city: (json['city'] as String?)?.toString(),
      state: (json['state'] as String?)?.toString(),
      country: (json['country'] as String?)?.toString(),
      postalCode: ((json['postalCode'] ?? json['zip']) as String?)?.toString(),
      landmark: (json['landmark'] as String?)?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'street': street,
        'city': city,
        'state': state,
        'country': country,
        'postalCode': postalCode,
        'landmark': landmark,
      };

  Address copyWith({
    String? street,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? landmark,
  }) {
    return Address(
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      landmark: landmark ?? this.landmark,
    );
  }

  @override
  String toString() {
    final parts = <String>[];
    if ((street ?? '').isNotEmpty) parts.add(street!);
    if ((landmark ?? '').isNotEmpty) parts.add(landmark!);
    if ((city ?? '').isNotEmpty) parts.add(city!);
    if ((state ?? '').isNotEmpty) parts.add(state!);
    if ((country ?? '').isNotEmpty) parts.add(country!);
    if ((postalCode ?? '').isNotEmpty) parts.add(postalCode!);
    return parts.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Address &&
          other.street == street &&
          other.city == city &&
          other.state == state &&
          other.country == country &&
          other.postalCode == postalCode &&
          other.landmark == landmark);

  @override
  int get hashCode => Object.hash(street, city, state, country, postalCode, landmark);
}

/// Represents full location info for a place or user.
/// - distanceFromUser is in kilometers (km), matching filtering and UI badges used across the app.
@immutable
class PlaceLocation {
  const PlaceLocation({
    required this.address,
    required this.coordinates,
    this.distanceFromUser,
    this.nearbyPlaceIds,
  });

  final Address address;
  final Coordinates coordinates;
  final double? distanceFromUser; // km
  final List<String>? nearbyPlaceIds;

  double get latitude => coordinates.latitude; // convenience
  double get longitude => coordinates.longitude; // convenience

  factory PlaceLocation.fromJson(Map<String, dynamic> json) {
    return PlaceLocation(
      address: Address.fromJson((json['address'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      coordinates: Coordinates.fromJson((json['coordinates'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      // Accept meters or km; prefer km if explicitly tagged, else assume km (project-wide convention).
      distanceFromUser: parseDistanceKm(json),
      nearbyPlaceIds: (json['nearbyPlaceIds'] as List?)
          ?.map((e) => e.toString())
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'address': address.toJson(),
        'coordinates': coordinates.toJson(),
        'distanceFromUser': distanceFromUser,
        'nearbyPlaceIds': nearbyPlaceIds,
      };

  PlaceLocation copyWith({
    Address? address,
    Coordinates? coordinates,
    double? distanceFromUser,
    List<String>? nearbyPlaceIds,
  }) {
    return PlaceLocation(
      address: address ?? this.address,
      coordinates: coordinates ?? this.coordinates,
      distanceFromUser: distanceFromUser ?? this.distanceFromUser,
      nearbyPlaceIds: nearbyPlaceIds ?? this.nearbyPlaceIds,
    );
  }

  /// Distance in km from an origin using the shared Coordinates great-circle calculation.
  double? distanceKmFrom(Coordinates origin) {
    final d = origin.distanceTo(coordinates);
    return d.isFinite ? d / 1000.0 : null;
  }

  /// Serialize as a minimal GeoJSON Feature with Point geometry ([lon, lat]) for mapping.
  Map<String, dynamic> toGeoJsonFeature({Map<String, dynamic>? properties}) {
    final props = <String, dynamic>{
      ...?properties,
      'lat': latitude,
      'lng': longitude,
      'address': address.toString(),
    };
    return <String, dynamic>{
      'type': 'Feature',
      'geometry': <String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[longitude, latitude],
      },
      'properties': props,
    };
  }

  /// Supports: distanceFromUser (km), distanceKm, distanceMeters/meters (converted to km).
  static double? parseDistanceKm(Map<String, dynamic> json) {
    final dynamic dKm = json['distanceFromUser'] ?? json['distanceKm'];
    if (dKm is num) return dKm.toDouble();
    if (dKm is String) {
      final v = double.tryParse(dKm);
      if (v != null) return v;
    }
    final dynamic dM = json['distanceMeters'] ?? json['meters'];
    if (dM is num) return dM.toDouble() / 1000.0;
    if (dM is String) {
      final v = double.tryParse(dM);
      if (v != null) return v / 1000.0;
    }
    return null;
  }

  @override
  String toString() => json.encode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaceLocation &&
          other.address == address &&
          other.coordinates == coordinates &&
          other.distanceFromUser == distanceFromUser &&
          listEquals(other.nearbyPlaceIds, nearbyPlaceIds));

  @override
  int get hashCode => Object.hash(address, coordinates, distanceFromUser, Object.hashAll(nearbyPlaceIds ?? const <String>[]));
}
