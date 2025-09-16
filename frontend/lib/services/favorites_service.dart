// lib/services/favorites_service.dart

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/favorite_place.dart';
import '../models/coordinates.dart';

/// Repository contract for favorites, so data access is decoupled from UI/business logic.
abstract class FavoritesRepository {
  Future<List<FavoritePlace>> list({
    required String userId,
    String? cursor,
    int limit = 50,
  });

  Future<FavoritePlace> upsert(FavoritePlace favorite);

  Future<void> delete(String id);

  /// Optional: pin/unpin is a common action in favorites UIs.
  Future<FavoritePlace> setPinned(String id, bool isPinned);
}

/// Simple in-memory repository (useful for local/dev and for optimistic rollbacks).
class InMemoryFavoritesRepository implements FavoritesRepository {
  InMemoryFavoritesRepository();

  final Map<String, FavoritePlace> _store = <String, FavoritePlace>{};

  @override
  Future<List<FavoritePlace>> list({
    required String userId,
    String? cursor,
    int limit = 50,
  }) async {
    // Cursor not implemented in memory; return all for the user.
    final all = _store.values.where((f) => f.userId == userId).toList(growable: false);
    // Sort by createdAt desc if available.
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(limit).toList(growable: false);
  }

  @override
  Future<FavoritePlace> upsert(FavoritePlace favorite) async {
    _store[favorite.id] = favorite;
    return favorite;
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
  }

  @override
  Future<FavoritePlace> setPinned(String id, bool isPinned) async {
    final current = _store[id];
    if (current == null) {
      throw StateError('Favorite not found: $id');
    }
    final updated = current.copyWith(isPinned: isPinned, updatedAt: DateTime.now().toUtc());
    _store[id] = updated;
    return updated;
  }
}

/// A small LRU-ish cache for favorites keyed by id.
/// LinkedHashMap maintains insertion order; when capacity is exceeded, evict oldest.
class _FavoritesCache {
  _FavoritesCache(this.capacity);

  final int capacity;
  final LinkedHashMap<String, FavoritePlace> _map = LinkedHashMap();

  int get length => _map.length;
  bool containsKey(String key) => _map.containsKey(key);
  FavoritePlace? operator [](String key) => _map[key];

  void put(FavoritePlace fav) {
    // Update or insert; move to end by re-inserting.
    if (_map.containsKey(fav.id)) {
      _map.remove(fav.id);
    }
    _map[fav.id] = fav;
    _evictIfNeeded();
  }

  void remove(String id) {
    _map.remove(id);
  }

  void putAll(Iterable<FavoritePlace> items) {
    for (final f in items) {
      put(f);
    }
  }

  List<FavoritePlace> values() => _map.values.toList(growable: false);

  void clear() => _map.clear();

  void _evictIfNeeded() {
    while (_map.length > capacity) {
      // Remove the oldest (first) entry.
      _map.remove(_map.keys.first);
    }
  }
}

/// Domain service that orchestrates favorites flows with optimistic UI support and caching.
class FavoritesService {
  FavoritesService({
    required FavoritesRepository repository,
    String? currentUserId,
    int cacheCapacity = 256,
  })  : _repository = repository,
        _currentUserId = currentUserId,
        _cache = _FavoritesCache(cacheCapacity);

  final FavoritesRepository _repository;
  final String? _currentUserId;
  final _FavoritesCache _cache;

  // Broadcast changes so UI/providers can reactively update.
  final StreamController<List<FavoritePlace>> _changes = StreamController<List<FavoritePlace>>.broadcast();

  Stream<List<FavoritePlace>> get stream => _changes.stream;

  List<FavoritePlace> get snapshot => _cache.values();

  /// Hydrate cache from repository (first page).
  Future<List<FavoritePlace>> refresh({String? userId, int limit = 100}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null || uid.isEmpty) {
      _cache.clear();
      _notify();
      return snapshot;
    }
    final items = await _repository.list(userId: uid, limit: limit);
    _cache.clear();
    _cache.putAll(items);
    _notify();
    return snapshot;
  }

  /// Optimistic add: insert into cache and stream immediately, then persist; rollback on failure.
  Future<FavoritePlace> addFavoriteOptimistic(FavoritePlace draft) async {
    final optimistic = draft.copyWith(
      updatedAt: DateTime.now().toUtc(),
    );
    _cache.put(optimistic);
    _notify();

    try {
      final saved = await _repository.upsert(optimistic);
      _cache.put(saved);
      _notify();
      return saved;
    } catch (e) {
      // Rollback optimistic insert.
      _cache.remove(optimistic.id);
      _notify();
      rethrow;
    }
  }

  /// Optimistic update: update cache, persist, rollback on error.
  Future<FavoritePlace> updateFavoriteOptimistic(FavoritePlace updated) async {
    final prev = _cache[updated.id];
    _cache.put(updated.copyWith(updatedAt: DateTime.now().toUtc()));
    _notify();

    try {
      final saved = await _repository.upsert(updated);
      _cache.put(saved);
      _notify();
      return saved;
    } catch (e) {
      // Rollback to previous if available.
      if (prev != null) {
        _cache.put(prev);
      } else {
        _cache.remove(updated.id);
      }
      _notify();
      rethrow;
    }
  }

  /// Optimistic remove: remove from cache first, restore on failure.
  Future<void> removeFavoriteOptimistic(String id) async {
    final prev = _cache[id];
    if (prev == null) return;
    _cache.remove(id);
    _notify();

    try {
      await _repository.delete(id);
    } catch (e) {
      // Rollback
      _cache.put(prev);
      _notify();
      rethrow;
    }
  }

  /// Toggle pin/unpin with optimistic update.
  Future<FavoritePlace?> togglePinnedOptimistic(String id) async {
    final prev = _cache[id];
    if (prev == null) return null;
    final optimistic = prev.copyWith(isPinned: !prev.isPinned, updatedAt: DateTime.now().toUtc());
    _cache.put(optimistic);
    _notify();

    try {
      final saved = await _repository.setPinned(id, optimistic.isPinned);
      _cache.put(saved);
      _notify();
      return saved;
    } catch (e) {
      _cache.put(prev);
      _notify();
      rethrow;
    }
  }

  /// Filter favorites by tag.
  List<FavoritePlace> filterByTag(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isEmpty) return snapshot;
    return snapshot.where((f) => f.tags.any((x) => x.toLowerCase() == t)).toList(growable: false);
  }

  /// Filter favorites by category (string field).
  List<FavoritePlace> filterByCategory(String category) {
    final c = category.trim().toLowerCase();
    if (c.isEmpty) return snapshot;
    return snapshot.where((f) => (f.category ?? '').toLowerCase() == c).toList(growable: false);
  }

  /// Sort favorites by proximity to an origin; items without coordinates go to the end.
  List<FavoritePlace> sortByProximity(Coordinates origin) {
    final withCoords = <FavoritePlace>[];
    final withoutCoords = <FavoritePlace>[];
    for (final f in snapshot) {
      if (f.coordinates == null) {
        withoutCoords.add(f);
      } else {
        withCoords.add(f);
      }
    }
    withCoords.sort((a, b) {
      final da = a.distanceFrom(origin) ?? double.infinity;
      final db = b.distanceFrom(origin) ?? double.infinity;
      return da.compareTo(db);
    });
    return <FavoritePlace>[...withCoords, ...withoutCoords];
  }

  /// Get favorite by id from cache.
  FavoritePlace? getById(String id) => _cache[id];

  /// Push current snapshot to listeners.
  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(snapshot);
    }
  }

  /// Clean up the stream controller.
  Future<void> dispose() async {
    await _changes.close();
  }
}
