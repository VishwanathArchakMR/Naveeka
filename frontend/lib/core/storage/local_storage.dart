// lib/core/storage/local_storage.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local key–value store singleton over SharedPreferences with namespaced helpers. [13]
class LocalStorage {
  LocalStorage._internal();
  static final LocalStorage _instance = LocalStorage._internal();
  static LocalStorage get instance => _instance;

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Optional global prefix for keys (leave null to use raw keys).
  /// If your app requires a prefix migration later, do it at bootstrap before init().
  String? globalPrefix;

  /// Initialize local storage once, ideally at app bootstrap. [2]
  Future<void> init({String? prefix}) async {
    if (_isInitialized) return;
    globalPrefix = prefix ?? globalPrefix;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  bool get isInitialized => _isInitialized;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized || _prefs == null) {
      await init();
    }
  }

  // --------- Key utilities ---------

  String _k(String key) => globalPrefix == null || globalPrefix!.isEmpty
      ? key
      : '${globalPrefix!}_$key';

  // --------- Primitive operations ---------

  Future<bool> setString(String key, String value) async {
    await _ensureInitialized();
    return _prefs!.setString(_k(key), value);
  }

  Future<String?> getString(String key) async {
    await _ensureInitialized();
    return _prefs!.getString(_k(key));
  }

  Future<bool> setInt(String key, int value) async {
    await _ensureInitialized();
    return _prefs!.setInt(_k(key), value);
  }

  Future<int?> getInt(String key) async {
    await _ensureInitialized();
    return _prefs!.getInt(_k(key));
  }

  Future<bool> setBool(String key, bool value) async {
    await _ensureInitialized();
    return _prefs!.setBool(_k(key), value);
  }

  Future<bool?> getBool(String key) async {
    await _ensureInitialized();
    return _prefs!.getBool(_k(key));
  }

  Future<bool> setDouble(String key, double value) async {
    await _ensureInitialized();
    return _prefs!.setDouble(_k(key), value);
  }

  Future<double?> getDouble(String key) async {
    await _ensureInitialized();
    return _prefs!.getDouble(_k(key));
  }

  Future<bool> setStringList(String key, List<String> value) async {
    await _ensureInitialized();
    return _prefs!.setStringList(_k(key), value);
  }

  Future<List<String>?> getStringList(String key) async {
    await _ensureInitialized();
    return _prefs!.getStringList(_k(key));
  }

  // --------- JSON helpers for complex objects ---------

  Future<bool> setJson(String key, Map<String, dynamic> jsonMap) async {
    return setString(key, json.encode(jsonMap));
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } catch (_) {
      return null;
    }
  }

  Future<bool> setJsonList(String key, List<Map<String, dynamic>> list) async {
    return setString(key, json.encode(list));
  }

  Future<List<Map<String, dynamic>>?> getJsonList(String key) async {
    final raw = await getString(key);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{'data': e})
            .cast<Map<String, dynamic>>()
            .toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // --------- Utility operations ---------

  Future<bool> remove(String key) async {
    await _ensureInitialized();
    return _prefs!.remove(_k(key));
  }

  Future<bool> clear() async {
    await _ensureInitialized();
    return _prefs!.clear();
  }

  Future<bool> containsKey(String key) async {
    await _ensureInitialized();
    return _prefs!.containsKey(_k(key));
  }

  Future<Set<String>> getKeys() async {
    await _ensureInitialized();
    // Expose de-prefixed names for the caller’s convenience
    final all = _prefs!.getKeys();
    if (globalPrefix == null || globalPrefix!.isEmpty) return all;
    final p = '${globalPrefix!}_';
    return all
        .where((k) => k.startsWith(p))
        .map((k) => k.substring(p.length))
        .toSet();
  }

  /// Get all keys with a specific prefix (app-level logical namespace).
  Future<Set<String>> getKeysWithPrefix(String prefix) async {
    final keys = await getKeys();
    return keys.where((key) => key.startsWith(prefix)).toSet();
  }

  /// Remove all keys with a specific prefix (app-level logical namespace). [7]
  Future<void> removeKeysWithPrefix(String prefix) async {
    final keys = await getKeysWithPrefix(prefix);
    for (final key in keys) {
      await remove(key);
    }
  }

  // --------- App-specific helper methods ---------

  // Theme
  Future<bool> setThemeMode(String themeMode) => setString('app_theme_mode', themeMode);
  Future<String> getThemeMode() async => (await getString('app_theme_mode')) ?? 'system';

  // Language
  Future<bool> setLanguage(String language) => setString('app_language', language);
  Future<String> getLanguage() async => (await getString('app_language')) ?? 'en';

  // First launch + onboarding
  Future<bool> setFirstLaunch(bool v) => setBool('app_first_launch', v);
  Future<bool> isFirstLaunch() async => (await getBool('app_first_launch')) ?? true;

  Future<bool> setOnboardingCompleted(bool v) => setBool('app_onboarding_completed', v);
  Future<bool> isOnboardingCompleted() async => (await getBool('app_onboarding_completed')) ?? false;

  // Preferences
  Future<bool> setNotificationsEnabled(bool enabled) => setBool('notifications_enabled', enabled);
  Future<bool> areNotificationsEnabled() async => (await getBool('notifications_enabled')) ?? true;

  Future<bool> setLocationEnabled(bool enabled) => setBool('location_enabled', enabled);
  Future<bool> isLocationEnabled() async => (await getBool('location_enabled')) ?? false;

  // Offline packs
  Future<bool> setOfflinePacksDownloaded(List<String> packIds) =>
      setStringList('offline_packs_downloaded', packIds);
  Future<List<String>> getOfflinePacksDownloaded() async =>
      (await getStringList('offline_packs_downloaded')) ?? const <String>[];

  // Favorites management (id list)
  Future<bool> addFavoritePlace(String placeId) async {
    final favorites = await getFavoritePlaces();
    if (!favorites.contains(placeId)) {
      favorites.insert(0, placeId);
      return setStringList('favorite_places', favorites);
    }
    return true;
  }

  Future<bool> removeFavoritePlace(String placeId) async {
    final favorites = await getFavoritePlaces();
    if (favorites.remove(placeId)) {
      return setStringList('favorite_places', favorites);
    }
    return true;
  }

  Future<List<String>> getFavoritePlaces() async =>
      (await getStringList('favorite_places')) ?? const <String>[];

  Future<bool> isFavoritePlace(String placeId) async {
    final favorites = await getFavoritePlaces();
    return favorites.contains(placeId);
  }

  // Recent searches (LRU of 10, unique)
  Future<bool> addRecentSearch(String query) async {
    final recent = await getRecentSearches();
    recent.remove(query);
    recent.insert(0, query);
    if (recent.length > 10) {
      recent.removeRange(10, recent.length);
    }
    return setStringList('recent_searches', recent);
  }

  Future<List<String>> getRecentSearches() async =>
      (await getStringList('recent_searches')) ?? const <String>[];

  Future<bool> clearRecentSearches() => remove('recent_searches');

  // Cache timestamps
  Future<bool> setCacheTimestamp(String key, DateTime timestamp) =>
      setString('cache_timestamp_$key', timestamp.toIso8601String());

  Future<DateTime?> getCacheTimestamp(String key) async {
    final s = await getString('cache_timestamp_$key');
    return s == null ? null : DateTime.tryParse(s);
  }

  Future<bool> isCacheExpired(String key, Duration maxAge) async {
    final ts = await getCacheTimestamp(key);
    if (ts == null) return true;
    return DateTime.now().difference(ts) > maxAge;
  }

  // Debug helpers (avoid in perf-critical paths)
  Future<Map<String, dynamic>> getAllData() async {
    await _ensureInitialized();
    final keys = await getKeys();
    final Map<String, dynamic> out = {};
    for (final key in keys) {
      out[key] = _prefs!.get(_k(key));
    }
    return out;
  }

  Future<int> getStorageSize() async {
    final data = await getAllData();
    return data.length;
  }
}
