// lib/core/storage/seed_data_loader.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_storage.dart';

class SeedDataLoader {
  static final SeedDataLoader _instance = SeedDataLoader._internal();
  static SeedDataLoader get instance => _instance;
  SeedDataLoader._internal();

  bool _isLoaded = false;

  // Cache for loaded data
  Map<String, dynamic>? _homeData;
  Map<String, dynamic>? _trailsData;
  Map<String, dynamic>? _atlasData;
  Map<String, dynamic>? _journeyData;
  Map<String, dynamic>? _naveeAIData;
  Map<String, dynamic>? _settingsData;
  Map<String, dynamic>? _placesData;
  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _historyData;
  Map<String, dynamic>? _favoritesData;
  Map<String, dynamic>? _followingData;
  Map<String, dynamic>? _planningData;
  Map<String, dynamic>? _messagesData;
  Map<String, dynamic>? _hotelsData;
  Map<String, dynamic>? _restaurantsData;
  Map<String, dynamic>? _flightsData;
  Map<String, dynamic>? _trainsData;
  Map<String, dynamic>? _busesData;
  Map<String, dynamic>? _activitiesData;

  // Optional remote fetcher for future live Atlas data (keeps API stable)
  Future<Map<String, dynamic>> Function()? _atlasRemoteFetcher;

  /// Register a remote fetcher to source Atlas data from a backend later,
  /// without changing callers that already use loadAtlasData() or atlasDataProvider.
  void setAtlasRemoteFetcher(Future<Map<String, dynamic>> Function() fetcher) {
    _atlasRemoteFetcher = fetcher;
  }

  /// Load all seed data from assets (initial bootstrap + offline cache)
  Future<void> loadAllSeedData() async {
    if (_isLoaded) return;

    try {
      // Load all seed files concurrently
      final results = await Future.wait([
        _loadSeedFile('assets/seed-data/home_seed.json'),
        _loadSeedFile('assets/seed-data/trail_seed.json'),
        _loadSeedFile('assets/seed-data/atlas_seed.json'),
        _loadSeedFile('assets/seed-data/journey_seed.json'),
        _loadSeedFile('assets/seed-data/navee_ai_seed.json'),
        _loadSeedFile('assets/seed-data/settings_seed.json'),
        _loadSeedFile('assets/seed-data/places_seed.json'),
        _loadSeedFile('assets/seed-data/booking_seed.json'),
        _loadSeedFile('assets/seed-data/history_seed.json'),
        _loadSeedFile('assets/seed-data/favorites_seed.json'),
        _loadSeedFile('assets/seed-data/following_seed.json'),
        _loadSeedFile('assets/seed-data/planning_seed.json'),
        _loadSeedFile('assets/seed-data/messages_seed.json'),
        _loadSeedFile('assets/seed-data/hotels_seed.json'),
        _loadSeedFile('assets/seed-data/restaurants_seed.json'),
        _loadSeedFile('assets/seed-data/flights_seed.json'),
        _loadSeedFile('assets/seed-data/trains_seed.json'),
        _loadSeedFile('assets/seed-data/buses_seed.json'),
        _loadSeedFile('assets/seed-data/activities_seed.json'),
      ]);

      // Assign results to cache
      _homeData = results;
      _trailsData = results;
      _atlasData = results;
      _journeyData = results;
      _naveeAIData = results;
      _settingsData = results;
      _placesData = results;
      _bookingData = results;
      _historyData = results;
      _favoritesData = results;
      _followingData = results;
      _planningData = results;
      _messagesData = results;
      _hotelsData = results;
      _restaurantsData = results;
      _flightsData = results;
      _trainsData = results;
      _busesData = results;
      _activitiesData = results;

      // Cache to local storage for offline access
      await _cacheToLocalStorage();

      _isLoaded = true;
    } catch (e) {
      // Try loading from local storage as fallback
      await _loadFromLocalStorage();
      _isLoaded = true;
    }
  }

  /// NEW: Direct Atlas loader used by features/atlas code and atlas_api.dart
  /// - Uses cached data when available
  /// - Supports optional remote override for production
  /// - Falls back to seeded asset when remote fails or not set
  Future<Map<String, dynamic>> loadAtlasData({bool forceRefresh = false}) async {
    // Return cached when allowed
    if (!forceRefresh && _atlasData != null && _atlasData!.isNotEmpty) {
      return _atlasData!;
    }

    // Ensure bootstrap seed load at least once (loads all datasets)
    if (!_isLoaded) {
      await loadAllSeedData();
      if (!forceRefresh && _atlasData != null && _atlasData!.isNotEmpty) {
        return _atlasData!;
      }
    }

    // Try remote first if provided
    if (_atlasRemoteFetcher != null) {
      try {
        final remote = await _atlasRemoteFetcher!.call();
        _atlasData = remote;
        // Cache only this map to local storage slot for atlas
        await LocalStorage.instance.setString('seed_atlas', json.encode(_atlasData));
        return _atlasData!;
      } catch (e, st) {
        debugPrint('Atlas remote fetch failed, falling back to seed: $e\n$st');
      }
    }

    // Fallback to bundled seed asset
    final local = await _loadSeedFile('assets/seed-data/atlas_seed.json');
    _atlasData = local;
    await LocalStorage.instance.setString('seed_atlas', json.encode(_atlasData));
    return _atlasData!;
  }

  /// Load individual seed file from assets safely
  Future<Map<String, dynamic>> _loadSeedFile(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      // Normalize non-map roots (arrays) to a map under 'data'
      return <String, dynamic>{'data': decoded};
    } catch (e) {
      // Return empty map if file doesn't exist or parse fails
      return <String, dynamic>{};
    }
  }

  /// Cache all data to local storage
  Future<void> _cacheToLocalStorage() async {
    final storage = LocalStorage.instance;

    if (_homeData != null) await storage.setString('seed_home', json.encode(_homeData));
    if (_trailsData != null) await storage.setString('seed_trails', json.encode(_trailsData));
    if (_atlasData != null) await storage.setString('seed_atlas', json.encode(_atlasData));
    if (_journeyData != null) await storage.setString('seed_journey', json.encode(_journeyData));
    if (_naveeAIData != null) await storage.setString('seed_navee_ai', json.encode(_naveeAIData));
    if (_settingsData != null) await storage.setString('seed_settings', json.encode(_settingsData));
    if (_placesData != null) await storage.setString('seed_places', json.encode(_placesData));
    if (_bookingData != null) await storage.setString('seed_booking', json.encode(_bookingData));
    if (_historyData != null) await storage.setString('seed_history', json.encode(_historyData));
    if (_favoritesData != null) await storage.setString('seed_favorites', json.encode(_favoritesData));
    if (_followingData != null) await storage.setString('seed_following', json.encode(_followingData));
    if (_planningData != null) await storage.setString('seed_planning', json.encode(_planningData));
    if (_messagesData != null) await storage.setString('seed_messages', json.encode(_messagesData));
    if (_hotelsData != null) await storage.setString('seed_hotels', json.encode(_hotelsData));
    if (_restaurantsData != null) await storage.setString('seed_restaurants', json.encode(_restaurantsData));
    if (_flightsData != null) await storage.setString('seed_flights', json.encode(_flightsData));
    if (_trainsData != null) await storage.setString('seed_trains', json.encode(_trainsData));
    if (_busesData != null) await storage.setString('seed_buses', json.encode(_busesData));
    if (_activitiesData != null) await storage.setString('seed_activities', json.encode(_activitiesData));
  }

  /// Load data from local storage (offline fallback)
  Future<void> _loadFromLocalStorage() async {
    final storage = LocalStorage.instance;

    try {
      final homeJson = await storage.getString('seed_home');
      _homeData = homeJson != null ? json.decode(homeJson) : <String, dynamic>{};

      final trailsJson = await storage.getString('seed_trails');
      _trailsData = trailsJson != null ? json.decode(trailsJson) : <String, dynamic>{};

      final atlasJson = await storage.getString('seed_atlas');
      _atlasData = atlasJson != null ? json.decode(atlasJson) : <String, dynamic>{};

      final journeyJson = await storage.getString('seed_journey');
      _journeyData = journeyJson != null ? json.decode(journeyJson) : <String, dynamic>{};

      final naveeAIJson = await storage.getString('seed_navee_ai');
      _naveeAIData = naveeAIJson != null ? json.decode(naveeAIJson) : <String, dynamic>{};

      final settingsJson = await storage.getString('seed_settings');
      _settingsData = settingsJson != null ? json.decode(settingsJson) : <String, dynamic>{};

      final placesJson = await storage.getString('seed_places');
      _placesData = placesJson != null ? json.decode(placesJson) : <String, dynamic>{};

      final bookingJson = await storage.getString('seed_booking');
      _bookingData = bookingJson != null ? json.decode(bookingJson) : <String, dynamic>{};

      final historyJson = await storage.getString('seed_history');
      _historyData = historyJson != null ? json.decode(historyJson) : <String, dynamic>{};

      final favoritesJson = await storage.getString('seed_favorites');
      _favoritesData = favoritesJson != null ? json.decode(favoritesJson) : <String, dynamic>{};

      final followingJson = await storage.getString('seed_following');
      _followingData = followingJson != null ? json.decode(followingJson) : <String, dynamic>{};

      final planningJson = await storage.getString('seed_planning');
      _planningData = planningJson != null ? json.decode(planningJson) : <String, dynamic>{};

      final messagesJson = await storage.getString('seed_messages');
      _messagesData = messagesJson != null ? json.decode(messagesJson) : <String, dynamic>{};

      final hotelsJson = await storage.getString('seed_hotels');
      _hotelsData = hotelsJson != null ? json.decode(hotelsJson) : <String, dynamic>{};

      final restaurantsJson = await storage.getString('seed_restaurants');
      _restaurantsData = restaurantsJson != null ? json.decode(restaurantsJson) : <String, dynamic>{};

      final flightsJson = await storage.getString('seed_flights');
      _flightsData = flightsJson != null ? json.decode(flightsJson) : <String, dynamic>{};

      final trainsJson = await storage.getString('seed_trains');
      _trainsData = trainsJson != null ? json.decode(trainsJson) : <String, dynamic>{};

      final busesJson = await storage.getString('seed_buses');
      _busesData = busesJson != null ? json.decode(busesJson) : <String, dynamic>{};

      final activitiesJson = await storage.getString('seed_activities');
      _activitiesData = activitiesJson != null ? json.decode(activitiesJson) : <String, dynamic>{};
    } catch (e) {
      // Initialize with empty data if local storage fails
      _initializeEmptyData();
    }
  }

  /// Initialize with empty data structures
  void _initializeEmptyData() {
    _homeData = <String, dynamic>{};
    _trailsData = <String, dynamic>{};
    _atlasData = <String, dynamic>{};
    _journeyData = <String, dynamic>{};
    _naveeAIData = <String, dynamic>{};
    _settingsData = <String, dynamic>{};
    _placesData = <String, dynamic>{};
    _bookingData = <String, dynamic>{};
    _historyData = <String, dynamic>{};
    _favoritesData = <String, dynamic>{};
    _followingData = <String, dynamic>{};
    _planningData = <String, dynamic>{};
    _messagesData = <String, dynamic>{};
    _hotelsData = <String, dynamic>{};
    _restaurantsData = <String, dynamic>{};
    _flightsData = <String, dynamic>{};
    _trainsData = <String, dynamic>{};
    _busesData = <String, dynamic>{};
    _activitiesData = <String, dynamic>{};
  }

  // Getters for each data type
  Map<String, dynamic> get homeData => _homeData ?? <String, dynamic>{};
  Map<String, dynamic> get trailsData => _trailsData ?? <String, dynamic>{};
  Map<String, dynamic> get atlasData => _atlasData ?? <String, dynamic>{};
  Map<String, dynamic> get journeyData => _journeyData ?? <String, dynamic>{};
  Map<String, dynamic> get naveeAIData => _naveeAIData ?? <String, dynamic>{};
  Map<String, dynamic> get settingsData => _settingsData ?? <String, dynamic>{};
  Map<String, dynamic> get placesData => _placesData ?? <String, dynamic>{};
  Map<String, dynamic> get bookingData => _bookingData ?? <String, dynamic>{};
  Map<String, dynamic> get historyData => _historyData ?? <String, dynamic>{};
  Map<String, dynamic> get favoritesData => _favoritesData ?? <String, dynamic>{};
  Map<String, dynamic> get followingData => _followingData ?? <String, dynamic>{};
  Map<String, dynamic> get planningData => _planningData ?? <String, dynamic>{};
  Map<String, dynamic> get messagesData => _messagesData ?? <String, dynamic>{};
  Map<String, dynamic> get hotelsData => _hotelsData ?? <String, dynamic>{};
  Map<String, dynamic> get restaurantsData => _restaurantsData ?? <String, dynamic>{};
  Map<String, dynamic> get flightsData => _flightsData ?? <String, dynamic>{};
  Map<String, dynamic> get trainsData => _trainsData ?? <String, dynamic>{};
  Map<String, dynamic> get busesData => _busesData ?? <String, dynamic>{};
  Map<String, dynamic> get activitiesData => _activitiesData ?? <String, dynamic>{};

  bool get isLoaded => _isLoaded;

  /// Reload data from assets (useful for refreshing)
  Future<void> reload() async {
    _isLoaded = false;
    await loadAllSeedData();
  }
}

// Riverpod providers for accessing seed data
final seedDataLoaderProvider = Provider<SeedDataLoader>((ref) {
  return SeedDataLoader.instance;
});

final homeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final loader = ref.watch(seedDataLoaderProvider);
  if (!loader.isLoaded) {
    await loader.loadAllSeedData();
  }
  return loader.homeData;
});

final trailsDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final loader = ref.watch(seedDataLoaderProvider);
  if (!loader.isLoaded) {
    await loader.loadAllSeedData();
  }
  return loader.trailsData;
});

final atlasDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final loader = ref.watch(seedDataLoaderProvider);
  // Prefer the new direct loader to enable remote override when configured
  return await loader.loadAtlasData();
});

final journeyDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final loader = ref.watch(seedDataLoaderProvider);
  if (!loader.isLoaded) {
    await loader.loadAllSeedData();
  }
  return loader.journeyData;
});

final naveeAIDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final loader = ref.watch(seedDataLoaderProvider);
  if (!loader.isLoaded) {
    await loader.loadAllSeedData();
  }
  return loader.naveeAIData;
});

final placesDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final loader = ref.watch(seedDataLoaderProvider);
  if (!loader.isLoaded) {
    await loader.loadAllSeedData();
  }
  return loader.placesData;
});
