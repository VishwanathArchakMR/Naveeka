// lib/features/atlas/data/atlas_api.dart

import 'dart:async';

import '../../../core/storage/seed_data_loader.dart';
import '../../../models/place.dart';

/// AtlasApi provides read-only access to Atlas data (places, nearby, trending, regions)
/// using the seeded JSON dataset for now. It’s structured so you can later replace
/// the internals with real network calls without changing the public method signatures.
class AtlasApi {
  const AtlasApi();

  /// Returns the raw atlas data map as loaded from seed-data/atlas_seed.json.
  Future<Map<String, dynamic>> getAtlasData() async {
    // In a real implementation, replace with network call.
    final data = await SeedDataLoader.instance.loadAtlasData();
    return data;
  }

  /// Returns all places.
  Future<List<Place>> getAllPlaces() async {
    final data = await getAtlasData();
    final list = (data['places'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Place.fromJson)
        .toList();
    return list;
  }

  /// Returns nearby places (as defined in the seed).
  Future<List<Place>> getNearbyPlaces() async {
    final data = await getAtlasData();
    final list = (data['nearbyPlaces'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Place.fromJson)
        .toList();
    return list;
  }

  /// Returns trending places (as defined in the seed).
  Future<List<Place>> getTrendingPlaces() async {
    final data = await getAtlasData();
    final list = (data['trendingPlaces'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Place.fromJson)
        .toList();
    return list;
  }

  /// Returns places for a specific region id.
  Future<List<Place>> getRegionPlaces(String regionId) async {
    final data = await getAtlasData();
    final list = (data['regionPlaces']?[regionId] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Place.fromJson)
        .toList();
    return list;
  }

  /// Universal search across name, tags and description, with optional basic filters.
  ///
  /// Note: This is a local filter over seeded data. When moving to HTTP,
  /// mirror the same query params server-side.
  Future<List<Place>> searchPlaces({
    required String query,
    String category = 'all',
    String emotion = 'all',
    double? maxDistanceKm, // requires Place.location.distanceFromUser to be populated
    bool? openNow,
    double? minRating,
  }) async {
    final all = await getAllPlaces();
    final q = query.trim().toLowerCase();

    final filtered = all.where((p) {
      // Query across name, description, tags
      if (q.isNotEmpty) {
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesDesc = (p.description ?? '').toLowerCase().contains(q);
        final matchesTags = p.tags.any((t) => t.toLowerCase().contains(q));
        if (!matchesName && !matchesDesc && !matchesTags) return false;
      }

      // Category filter
      if (category != 'all' && p.category.name != category) return false;

      // Emotion filter
      if (emotion != 'all' &&
          !p.emotions.any((e) => e.name.toLowerCase() == emotion.toLowerCase())) {
        return false;
      }

      // Distance filter (if client has computed/populated distanceFromUser)
      if (maxDistanceKm != null) {
        final d = p.location.distanceFromUser ?? double.infinity;
        if (d > maxDistanceKm) return false;
      }

      // Open-now filter
      if (openNow == true && !p.isOpenNow) return false;

      // Rating filter
      if (minRating != null && p.rating < minRating) return false;

      return true;
    }).toList();

    // Basic relevance: higher rating first, then review count
    filtered.sort((a, b) {
      final r = b.rating.compareTo(a.rating);
      if (r != 0) return r;
      return b.reviewCount.compareTo(a.reviewCount);
    });

    return filtered;
  }

  /// Convenience method to simulate refresh behavior (e.g., pull-to-refresh).
  /// Can be used to add a small delay to mimic network latency.
  Future<void> refresh({Duration delay = const Duration(milliseconds: 250)}) async {
    await Future<void>.delayed(delay);
  }
}
