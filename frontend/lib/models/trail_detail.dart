// lib/models/trail_detail.dart

import 'geo_point.dart';

class TrailDetail {
  final String id;
  final String name;
  final String description;
  final GeoPoint startLocation;
  final GeoPoint endLocation;
  final double distance; // in meters
  final double elevationGainM; // in meters
  final double difficulty; // 1-5 scale
  final List<String> tags;
  final List<String> imageUrls;
  final double rating;
  final int reviewCount;
  final String? instructions;
  final List<String> safetyNotes;
  final String? bestTimeToVisit;
  final List<String> amenities;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrailDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.startLocation,
    required this.endLocation,
    required this.distance,
    required this.elevationGainM,
    required this.difficulty,
    required this.tags,
    required this.imageUrls,
    required this.rating,
    required this.reviewCount,
    this.instructions,
    required this.safetyNotes,
    this.bestTimeToVisit,
    required this.amenities,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrailDetail.fromJson(Map<String, dynamic> json) {
    return TrailDetail(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      startLocation: GeoPoint.fromJson(json['startLocation'] ?? {}),
      endLocation: GeoPoint.fromJson(json['endLocation'] ?? {}),
      distance: json['distance']?.toDouble() ?? 0.0,
      elevationGainM: json['elevationGainM']?.toDouble() ?? 0.0,
      difficulty: json['difficulty']?.toDouble() ?? 1.0,
      tags: List<String>.from(json['tags'] ?? []),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      rating: json['rating']?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] ?? 0,
      instructions: json['instructions'],
      safetyNotes: List<String>.from(json['safetyNotes'] ?? []),
      bestTimeToVisit: json['bestTimeToVisit'],
      amenities: List<String>.from(json['amenities'] ?? []),
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
      'elevationGainM': elevationGainM,
      'difficulty': difficulty,
      'tags': tags,
      'imageUrls': imageUrls,
      'rating': rating,
      'reviewCount': reviewCount,
      'instructions': instructions,
      'safetyNotes': safetyNotes,
      'bestTimeToVisit': bestTimeToVisit,
      'amenities': amenities,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrailDetail &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.startLocation == startLocation &&
        other.endLocation == endLocation &&
        other.distance == distance &&
        other.elevationGainM == elevationGainM &&
        other.difficulty == difficulty &&
        other.tags == tags &&
        other.imageUrls == imageUrls &&
        other.rating == rating &&
        other.reviewCount == reviewCount &&
        other.instructions == instructions &&
        other.safetyNotes == safetyNotes &&
        other.bestTimeToVisit == bestTimeToVisit &&
        other.amenities == amenities &&
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
      elevationGainM,
      difficulty,
      tags,
      imageUrls,
      rating,
      reviewCount,
      instructions,
      safetyNotes,
      bestTimeToVisit,
      amenities,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'TrailDetail(id: $id, name: $name, distance: $distance, elevationGainM: $elevationGainM)';
  }
}

