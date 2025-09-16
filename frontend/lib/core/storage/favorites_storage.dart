// lib/core/storage/favorites_storage.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'local_storage.dart';

/// Domain types for favorites keys (extend as needed).
/// Keep strings to avoid tight coupling across models/UI.
class FavoriteType {
  const FavoriteType._();
  static const String place = 'place';
  static const String hotel = 'hotel';
  static const String restaurant = 'restaurant';
  static const String activity = 'activity';
  static const String landmark = 'landmark';
  // Add more: flight, train, bus, cab, etc.
}

/// Change event emitted whenever a favorite toggles.
@immutable
class FavoriteEvent {
  final String type;
  final String id;
  final bool isFavorite;
  final DateTime timestamp;

  const FavoriteEvent({
    required this.type,
    required this.id,
    required this.isFavorite,
    required this.timestamp,
  });

  @override
  String toString() => 'FavoriteEvent(type=$type, id=$id, fav=$isFavorite)';
}

/// Favorites storage with per-entity-type lists saved as JSON maps {id: isoTimestamp}.
/// Uses a broadcast stream so multiple listeners (widgets/providers) stay in sync.
class FavoritesStorage {
  FavoritesStorage._();
  static final FavoritesStorage instance = FavoritesStorage._();

  // Broadcast controller allows multiple listeners across the app.
  final StreamController<FavoriteEvent> _events =
      StreamController<FavoriteEvent>.broadcast();

  // Key namespace v2 to avoid collisions with older keys.
  static const String _ns = 'favorites_v2';

  // Legacy key (list<string>) to migrate from.
  static const String _legacyPlacesKey = 'favorite_places';

  bool _migrated = false;

  Stream<FavoriteEvent> get stream => _events.stream;

  // -------- Public convenience APIs (places/hotels/restaurants/activities) --------

  Future<bool> togglePlace(String id) => toggle(FavoriteType.place, id);
  Future<bool> addPlace(String id) => add(FavoriteType.place, id);
  Future<bool> removePlace(String id) => remove(FavoriteType.place, id);
  Future<bool> isPlaceFavorite(String id) => isFavorite(FavoriteType.place, id);
  Future<List<String>> listPlaceIds() => listIds(FavoriteType.place);

  Future<bool> toggleHotel(String id) => toggle(FavoriteType.hotel, id);
  Future<bool> addHotel(String id) => add(FavoriteType.hotel, id);
  Future<bool> removeHotel(String id) => remove(FavoriteType.hotel, id);
  Future<bool> isHotelFavorite(String id) => isFavorite(FavoriteType.hotel, id);
  Future<List<String>> listHotelIds() => listIds(FavoriteType.hotel);

  Future<bool> toggleRestaurant(String id) => toggle(FavoriteType.restaurant, id);
  Future<bool> addRestaurant(String id) => add(FavoriteType.restaurant, id);
  Future<bool> removeRestaurant(String id) => remove(FavoriteType.restaurant, id);
  Future<bool> isRestaurantFavorite(String id) =>
      isFavorite(FavoriteType.restaurant, id);
  Future<List<String>> listRestaurantIds() => listIds(FavoriteType.restaurant);

  Future<bool> toggleActivity(String id) => toggle(FavoriteType.activity, id);
  Future<bool> addActivity(String id) => add(FavoriteType.activity, id);
  Future<bool> removeActivity(String id) => remove(FavoriteType.activity, id);
  Future<bool> isActivityFavorite(String id) =>
      isFavorite(FavoriteType.activity, id);
  Future<List<String>> listActivityIds() => listIds(FavoriteType.activity);

  // -------- Generic APIs (type + id) --------

  Future<bool> toggle(String type, String id) async {
    await _maybeMigrate();
    final fav = await isFavorite(type, id);
    return fav ? remove(type, id) : add(type, id);
  }

  Future<bool> add(String type, String id) async {
    await _maybeMigrate();
    final key = _key(type);
    final map = await _load(key);
    if (!map.containsKey(id)) {
      map[id] = DateTime.now().toIso8601String();
      await _save(key, map);
      _emit(type, id, true);
    }
    return true;
  }

  Future<bool> remove(String type, String id) async {
    await _maybeMigrate();
    final key = _key(type);
    final map = await _load(key);
    if (map.remove(id) != null) {
      await _save(key, map);
      _emit(type, id, false);
    }
    return true;
  }

  Future<bool> isFavorite(String type, String id) async {
    await _maybeMigrate();
    final key = _key(type);
    final map = await _load(key);
    return map.containsKey(id);
  }

  Future<List<String>> listIds(String type) async {
    await _maybeMigrate();
    final map = await _load(_key(type));
    // Return newest-first by timestamp
    final entries = map.entries
        .map((e) => (id: e.key, ts: DateTime.tryParse(e.value.toString())))
        .toList();
    entries.sort((a, b) {
      final at = a.ts ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.ts ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return entries.map((e) => e.id).toList(growable: false);
  }

  Future<int> count(String type) async {
    final map = await _load(_key(type));
    return map.length;
  }

  // -------- Internals --------

  String _key(String type) => '$_ns/$type';

  Future<Map<String, dynamic>> _load(String key) async {
    return await LocalStorage.instance.getJson(key) ?? <String, dynamic>{};
  }

  Future<void> _save(String key, Map<String, dynamic> map) async {
    await LocalStorage.instance.setJson(key, map);
    await LocalStorage.instance.setCacheTimestamp(key, DateTime.now());
  }

  void _emit(String type, String id, bool isFavorite) {
    if (!_events.hasListener) return;
    _events.add(
      FavoriteEvent(
        type: type,
        id: id,
        isFavorite: isFavorite,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _maybeMigrate() async {
    if (_migrated) return;
    _migrated = true;
    // Migrate legacy 'favorite_places' (List<String>) into JSON map with timestamps.
    final legacy = await LocalStorage.instance.getStringList(_legacyPlacesKey);
    if (legacy != null && legacy.isNotEmpty) {
      final nowIso = DateTime.now().toIso8601String();
      final map = <String, dynamic>{for (final id in legacy) id: nowIso};
      final key = _key(FavoriteType.place);
      final existing = await _load(key);
      // Merge: keep existing timestamps, add legacy for new ones
      for (final e in map.entries) {
        existing.putIfAbsent(e.key, () => e.value);
      }
      await _save(key, existing);
      // Optionally remove legacy key to prevent re-migration
      await LocalStorage.instance.remove(_legacyPlacesKey);
      if (kDebugMode) {
        // ignore: avoid_print
        print('FavoritesStorage: migrated ${legacy.length} legacy place favorites.');
      }
    }
  }

  Future<void> dispose() async {
    await _events.close();
  }
}
