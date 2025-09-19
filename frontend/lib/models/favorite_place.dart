// lib/models/favorite_place.dart

import 'package:flutter/foundation.dart';

import 'coordinates.dart';

/// How this favorite was created or sourced. [manual|wishlist|system|history|recommended]
enum FavoriteSource { manual, wishlist, system, history, recommended }

/// Visibility control for a favorite place. [private|friends|public]
enum FavoritePrivacy { private, friends, public }

/// A user's saved place/bookmark with minimal denormalized fields for fast UI.
@immutable
class FavoritePlace {
  const FavoritePlace({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.name,
    this.category,
    this.address,
    this.coordinates,
    this.coverImageUrl,
    this.rating,
    this.tags = const <String>[],
    this.notes,
    this.isPinned = false,
    this.source = FavoriteSource.manual,
    this.privacy = FavoritePrivacy.private,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  /// Unique id of this favorite record (not the place id).
  final String id;

  /// Underlying place identifier this favorite refers to.
  final String placeId;

  /// Owner of the favorite.
  final String userId;

  /// Denormalized label for quick list rendering.
  final String name;

  /// Optional category label (e.g., Trail, Park, Café).
  final String? category;

  /// Optional human-readable address string.
  final String? address;

  /// Optional coordinates for proximity and map previews.
  final Coordinates? coordinates;

  /// Optional image URL for thumbnail/cover.
  final String? coverImageUrl;

  /// Optional community/user rating for quick sorting.
  final double? rating;

  /// Free-form tags for filtering and grouping.
  final List<String> tags;

  /// Personal note saved by the user.
  final String? notes;

  /// Pin to top of lists.
  final bool isPinned;

  /// Creation/sync source.
  final FavoriteSource source;

  /// Sharing scope.
  final FavoritePrivacy privacy;

  /// Timestamps.
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Free-form server-defined properties.
  final Map<String, dynamic>? metadata;

  /// Convenience display string "Name — Category" or just name.
  String get displayTitle {
    final c = (category ?? '').trim();
    return c.isEmpty ? name : '$name — $c';
  }

  /// Compute distance in meters from an origin if coordinates are available.
  double? distanceFrom(Coordinates origin) {
    if (coordinates == null) return null;
    return origin.distanceTo(coordinates!);
  }

  FavoritePlace copyWith({
    String? id,
    String? placeId,
    String? userId,
    String? name,
    String? category,
    String? address,
    Coordinates? coordinates,
    String? coverImageUrl,
    double? rating,
    List<String>? tags,
    String? notes,
    bool? isPinned,
    FavoriteSource? source,
    FavoritePrivacy? privacy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return FavoritePlace(
      id: id ?? this.id,
      placeId: placeId ?? this.placeId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      coordinates: coordinates ?? this.coordinates,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      isPinned: isPinned ?? this.isPinned,
      source: source ?? this.source,
      privacy: privacy ?? this.privacy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // -------- JSON --------

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    FavoriteSource parseSource(Object? v) {
      final s = (v ?? 'manual').toString();
      try {
        return FavoriteSource.values.byName(s);
      } catch (_) {
        return FavoriteSource.manual;
      }
    }

    FavoritePrivacy parsePrivacy(Object? v) {
      final s = (v ?? 'private').toString();
      try {
        return FavoritePrivacy.values.byName(s);
      } catch (_) {
        return FavoritePrivacy.private;
      }
    }

    Coordinates? parseCoords(Object? v) {
      if (v is Map<String, dynamic>) return Coordinates.fromJson(v);
      return null;
    }

    return FavoritePlace(
      id: (json['id'] ?? '').toString(),
      placeId: (json['placeId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] as String?)?.toString(),
      address: (json['address'] as String?)?.toString(),
      coordinates: parseCoords(json['coordinates'] ?? json['coord']),
      coverImageUrl: (json['coverImageUrl'] as String?)?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      tags: ((json['tags'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      notes: (json['notes'] as String?)?.toString(),
      isPinned: (json['isPinned'] as bool?) ?? false,
      source: parseSource(json['source']),
      privacy: parsePrivacy(json['privacy']),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  } // Manual JSON with enum parsing using values.byName + safe fallbacks. [1][2]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'placeId': placeId,
        'userId': userId,
        'name': name,
        if (category != null) 'category': category,
        if (address != null) 'address': address,
        if (coordinates != null) 'coordinates': coordinates!.toJson(),
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (rating != null) 'rating': rating,
        if (tags.isNotEmpty) 'tags': tags,
        if (notes != null) 'notes': notes,
        'isPinned': isPinned,
        'source': source.name,
        'privacy': privacy.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      }; // Enum serialization via .name as recommended in modern Dart. [2][1]

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is FavoritePlace &&
            other.id == id &&
            other.placeId == placeId &&
            other.userId == userId &&
            other.name == name &&
            other.category == category &&
            other.address == address &&
            other.coordinates == coordinates &&
            other.coverImageUrl == coverImageUrl &&
            other.rating == rating &&
            listEquals(other.tags, tags) &&
            other.notes == notes &&
            other.isPinned == isPinned &&
            other.source == source &&
            other.privacy == privacy &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            mapEquals(other.metadata, metadata));
  } // Value equality for reliable Riverpod updates. [1]

  @override
  int get hashCode => Object.hash(
        id,
        placeId,
        userId,
        name,
        category,
        address,
        coordinates,
        coverImageUrl,
        rating,
        Object.hashAll(tags),
        notes,
        isPinned,
        source,
        privacy,
        createdAt,
        updatedAt,
        _mapHash(metadata),
      );

  int _mapHash(Map<String, dynamic>? m) => m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
