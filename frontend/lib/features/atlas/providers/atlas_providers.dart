// lib/features/atlas/providers/atlas_providers.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/seed_data_loader.dart';
import '../../../services/location_service.dart';
import '../../../models/place.dart';
import '../presentation/widgets/location_filters.dart';

// Core data providers
final atlasDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await SeedDataLoader.instance.loadAtlasData();
});

final allPlacesProvider = FutureProvider<List<Place>>((ref) async {
  final atlasData = await ref.watch(atlasDataProvider.future);
  final placesData = atlasData['places'] as List<dynamic>? ?? [];
  return placesData
      .cast<Map<String, dynamic>>()
      .map((data) => Place.fromJson(data))
      .toList();
});

final nearbyPlacesProvider = FutureProvider<List<Place>>((ref) async {
  final atlasData = await ref.watch(atlasDataProvider.future);
  final nearbyData = atlasData['nearbyPlaces'] as List<dynamic>? ?? [];
  return nearbyData
      .cast<Map<String, dynamic>>()
      .map((data) => Place.fromJson(data))
      .toList();
});

final trendingPlacesProvider = FutureProvider<List<Place>>((ref) async {
  final atlasData = await ref.watch(atlasDataProvider.future);
  final trendingData = atlasData['trendingPlaces'] as List<dynamic>? ?? [];
  return trendingData
      .cast<Map<String, dynamic>>()
      .map((data) => Place.fromJson(data))
      .toList();
});

final famousPlacesProvider = FutureProvider<List<Place>>((ref) async {
  final atlasData = await ref.watch(atlasDataProvider.future);
  final famousData = atlasData['famousNearby'] as List<dynamic>? ?? [];
  return famousData
      .cast<Map<String, dynamic>>()
      .map((data) => Place.fromJson(data))
      .where((place) => place.isFeatured || place.rating >= 4.0)
      .toList();
});

// Location provider
final locationProvider = FutureProvider<UserLocation?>((ref) async {
  try {
    return await LocationService.instance.getCurrentLocation();
  } catch (e) {
    debugPrint('Error getting location: $e');
    return null;
  }
});

// Filter state providers
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String>((ref) => 'all');
final selectedEmotionProvider = StateProvider<String>((ref) => 'all');
final sortByProvider = StateProvider<String>((ref) => 'distance');

// Location filter providers
final radiusKmProvider = StateProvider<double>((ref) => 10.0);
final openNowFilterProvider = StateProvider<bool>((ref) => false);
final priceFilterProvider = StateProvider<PriceFilter>((ref) => PriceFilter.any);
final ratingFilterProvider = StateProvider<RatingFilter>((ref) => RatingFilter.any);

// Show favorites only
final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

// Filtered places provider that combines all filters
final filteredPlacesProvider = FutureProvider.family<List<Place>, String>((ref, context) async {
  // Get base places based on context
  List<Place> basePlaces;
  switch (context) {
    case 'nearby':
      basePlaces = await ref.watch(nearbyPlacesProvider.future);
      break;
    case 'trending':
      basePlaces = await ref.watch(trendingPlacesProvider.future);
      break;
    case 'famous':
      basePlaces = await ref.watch(famousPlacesProvider.future);
      break;
    default:
      basePlaces = await ref.watch(allPlacesProvider.future);
  }

  // Get filter states
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final selectedEmotion = ref.watch(selectedEmotionProvider);
  final sortBy = ref.watch(sortByProvider);
  final radiusKm = ref.watch(radiusKmProvider);
  final openNow = ref.watch(openNowFilterProvider);
  final priceFilter = ref.watch(priceFilterProvider);
  final ratingFilter = ref.watch(ratingFilterProvider);
  final showFavoritesOnly = ref.watch(showFavoritesOnlyProvider);
  final userLocation = await ref.watch(locationProvider.future);

  // Apply filters
  var filtered = basePlaces.where((place) {
    // Search query filter
    if (searchQuery.isNotEmpty) {
      final matchesName = place.name.toLowerCase().contains(searchQuery);
      final matchesDescription = place.description?.toLowerCase().contains(searchQuery) ?? false;
      final matchesTags = place.tags.any((tag) => tag.toLowerCase().contains(searchQuery));
      if (!matchesName && !matchesDescription && !matchesTags) {
        return false;
      }
    }

    // Category filter
    if (selectedCategory != 'all' && place.category.name != selectedCategory) {
      return false;
    }

    // Emotion filter
    if (selectedEmotion != 'all') {
      final hasEmotion = place.emotions.any((emotion) => emotion.name == selectedEmotion);
      if (!hasEmotion) return false;
    }

    // Distance filter (if user location available)
    if (userLocation != null) {
      final distance = place.location.distanceFromUser ?? double.infinity;
      if (distance > radiusKm) return false;
    }

    // Open now filter
    if (openNow && !place.isOpenNow) {
      return false;
    }

    // Price filter
    if (priceFilter != PriceFilter.any) {
      final price = place.pricing?.entryFee ?? 0;
      switch (priceFilter) {
        case PriceFilter.free:
          if (!place.isFree) return false;
          break;
        case PriceFilter.under500:
          if (place.isFree || price >= 500) return false;
          break;
        case PriceFilter.between500_1000:
          if (place.isFree || price < 500 || price > 1000) return false;
          break;
        case PriceFilter.above1000:
          if (place.isFree || price <= 1000) return false;
          break;
        case PriceFilter.any:
          break;
      }
    }

    // Rating filter
    if (ratingFilter != RatingFilter.any) {
      switch (ratingFilter) {
        case RatingFilter.gte3_5:
          if (place.rating < 3.5) return false;
          break;
        case RatingFilter.gte4_0:
          if (place.rating < 4.0) return false;
          break;
        case RatingFilter.gte4_5:
          if (place.rating < 4.5) return false;
          break;
        case RatingFilter.any:
          break;
      }
    }

    // Favorites filter
    if (showFavoritesOnly && !place.isFavorite) {
      return false;
    }

    return true;
  }).toList();

  // Apply sorting
  switch (sortBy) {
    case 'distance':
      filtered.sort((a, b) {
        final aDistance = a.location.distanceFromUser ?? double.infinity;
        final bDistance = b.location.distanceFromUser ?? double.infinity;
        return aDistance.compareTo(bDistance);
      });
      break;
    case 'rating':
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
      break;
    case 'name':
      filtered.sort((a, b) => a.name.compareTo(b.name));
      break;
    case 'featured':
      filtered.sort((a, b) {
        if (a.isFeatured && !b.isFeatured) return -1;
        if (!a.isFeatured && b.isFeatured) return 1;
        return b.rating.compareTo(a.rating);
      });
      break;
    case 'price_low_to_high':
      filtered.sort((a, b) {
        final aPrice = a.pricing?.entryFee ?? 0;
        final bPrice = b.pricing?.entryFee ?? 0;
        if (a.isFree && !b.isFree) return -1;
        if (!a.isFree && b.isFree) return 1;
        return aPrice.compareTo(bPrice);
      });
      break;
    case 'price_high_to_low':
      filtered.sort((a, b) {
        final aPrice = a.pricing?.entryFee ?? 0;
        final bPrice = b.pricing?.entryFee ?? 0;
        if (a.isFree && !b.isFree) return 1;
        if (!a.isFree && b.isFree) return -1;
        return bPrice.compareTo(aPrice);
      });
      break;
  }

  return filtered;
});

// Search suggestions provider
final searchSuggestionsProvider = FutureProvider.family<List<Place>, String>((ref, query) async {
  if (query.isEmpty) return [];
  
  final allPlaces = await ref.watch(allPlacesProvider.future);
  final lowerQuery = query.toLowerCase();
  
  return allPlaces
      .where((place) {
        final matchesName = place.name.toLowerCase().contains(lowerQuery);
        final matchesTags = place.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        return matchesName || matchesTags;
      })
      .take(10)
      .toList();
});

// Region-specific places provider
final regionPlacesProvider = FutureProvider.family<List<Place>, String>((ref, regionId) async {
  final atlasData = await ref.watch(atlasDataProvider.future);
  final regionData = atlasData['regionPlaces']?[regionId] as List<dynamic>? ?? [];
  return regionData
      .cast<Map<String, dynamic>>()
      .map((data) => Place.fromJson(data))
      .toList();
});

// Place categories provider (for filter chips)
final placeCategoriesProvider = FutureProvider<List<PlaceCategory>>((ref) async {
  final allPlaces = await ref.watch(allPlacesProvider.future);
  final categories = allPlaces.map((place) => place.category).toSet().toList();
  categories.sort((a, b) => a.label.compareTo(b.label));
  return categories;
});

// Emotion categories provider (for filter chips)
final emotionCategoriesProvider = FutureProvider<List<EmotionCategory>>((ref) async {
  final allPlaces = await ref.watch(allPlacesProvider.future);
  final emotions = allPlaces
      .expand((place) => place.emotions)
      .toSet()
      .toList();
  emotions.sort((a, b) => a.label.compareTo(b.label));
  return emotions;
});

// Filter reset provider
final filterResetProvider = Provider<VoidCallback>((ref) {
  return () {
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedCategoryProvider.notifier).state = 'all';
    ref.read(selectedEmotionProvider.notifier).state = 'all';
    ref.read(sortByProvider.notifier).state = 'distance';
    ref.read(radiusKmProvider.notifier).state = 10.0;
    ref.read(openNowFilterProvider.notifier).state = false;
    ref.read(priceFilterProvider.notifier).state = PriceFilter.any;
    ref.read(ratingFilterProvider.notifier).state = RatingFilter.any;
    ref.read(showFavoritesOnlyProvider.notifier).state = false;
  };
});

// Atlas statistics provider
final atlasStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final allPlaces = await ref.watch(allPlacesProvider.future);
  final nearbyPlaces = await ref.watch(nearbyPlacesProvider.future);
  final trendingPlaces = await ref.watch(trendingPlacesProvider.future);
  final famousPlaces = await ref.watch(famousPlacesProvider.future);

  return {
    'total': allPlaces.length,
    'nearby': nearbyPlaces.length,
    'trending': trendingPlaces.length,
    'famous': famousPlaces.length,
    'categories': allPlaces.map((p) => p.category).toSet().length,
    'emotions': allPlaces.expand((p) => p.emotions).toSet().length,
  };
});
