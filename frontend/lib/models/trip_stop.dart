// lib/models/trip_stop.dart

import 'geo_point.dart';

class TripStop {
  final String id;
  final String name;
  final GeoPoint location;
  final String? address;
  final DateTime? arrivalTime;
  final DateTime? departureTime;
  final int? duration; // in minutes
  final String? description;
  final String? type; // e.g., 'accommodation', 'attraction', 'restaurant'
  final Map<String, dynamic>? metadata;

  const TripStop({
    required this.id,
    required this.name,
    required this.location,
    this.address,
    this.arrivalTime,
    this.departureTime,
    this.duration,
    this.description,
    this.type,
    this.metadata,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      location: GeoPoint.fromJson(json['location'] ?? {}),
      address: json['address'],
      arrivalTime: json['arrivalTime'] != null ? DateTime.parse(json['arrivalTime']) : null,
      departureTime: json['departureTime'] != null ? DateTime.parse(json['departureTime']) : null,
      duration: json['duration'],
      description: json['description'],
      type: json['type'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location.toJson(),
      'address': address,
      'arrivalTime': arrivalTime?.toIso8601String(),
      'departureTime': departureTime?.toIso8601String(),
      'duration': duration,
      'description': description,
      'type': type,
      'metadata': metadata,
    };
  }

  TripStop copyWith({
    String? id,
    String? name,
    GeoPoint? location,
    String? address,
    DateTime? arrivalTime,
    DateTime? departureTime,
    int? duration,
    String? description,
    String? type,
    Map<String, dynamic>? metadata,
  }) {
    return TripStop(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      address: address ?? this.address,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureTime: departureTime ?? this.departureTime,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TripStop &&
        other.id == id &&
        other.name == name &&
        other.location == location &&
        other.address == address &&
        other.arrivalTime == arrivalTime &&
        other.departureTime == departureTime &&
        other.duration == duration &&
        other.description == description &&
        other.type == type &&
        other.metadata == metadata;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      location,
      address,
      arrivalTime,
      departureTime,
      duration,
      description,
      type,
      metadata,
    );
  }

  @override
  String toString() {
    return 'TripStop(id: $id, name: $name, location: $location, address: $address)';
  }
}

