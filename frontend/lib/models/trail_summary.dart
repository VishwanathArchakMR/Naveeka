// lib/models/trail_summary.dart

import 'geo_point.dart';

class TrailSummary {
  final String id;
  final String name;
  final String description;
  final GeoPoint startLocation;
  final GeoPoint endLocation;
  final double distance; // in meters
  final double elevationGain; // in meters
  final double difficulty; // 1-5 scale
  final List<String> tags;
  final String? imageUrl;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrailSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.startLocation,
    required this.endLocation,
    required this.distance,
    required this.elevationGain,
    required this.difficulty,
    required this.tags,
    this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrailSummary.fromJson(Map<String, dynamic> json) {
    return TrailSummary(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      startLocation: GeoPoint.fromJson(json['startLocation'] ?? {}),
      endLocation: GeoPoint.fromJson(json['endLocation'] ?? {}),
      distance: json['distance']?.toDouble() ?? 0.0,
      elevationGain: json['elevationGain']?.toDouble() ?? 0.0,
      difficulty: json['difficulty']?.toDouble() ?? 1.0,
      tags: List<String>.from(json['tags'] ?? []),
      imageUrl: json['imageUrl'],
      rating: json['rating']?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'startLocation': startLocation.toJson(),
      'endLocation': endLocation.toJson(),
      'distance': distance,
      'elevationGain': elevationGain,
      'difficulty': difficulty,
      'tags': tags,
      'imageUrl': imageUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Get the label for this trail (name or description)
  String get label => name.isNotEmpty ? name : description;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrailSummary &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.startLocation == startLocation &&
        other.endLocation == endLocation &&
        other.distance == distance &&
        other.elevationGain == elevationGain &&
        other.difficulty == difficulty &&
        other.tags == tags &&
        other.imageUrl == imageUrl &&
        other.rating == rating &&
        other.reviewCount == reviewCount &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      startLocation,
      endLocation,
      distance,
      elevationGain,
      difficulty,
      tags,
      imageUrl,
      rating,
      reviewCount,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'TrailSummary(id: $id, name: $name, distance: $distance, rating: $rating)';
  }
}

