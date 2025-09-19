// lib/features/quick_actions/providers/favorites_providers.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal domain model for a favorite place/item.
@immutable
class FavoriteItem {
  const FavoriteItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.isFavorite = true,
    this.tags = const <String>[],
    this.addedAt,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? thumbnailUrl;
  final bool isFavorite;
  final List<String> tags;
  final DateTime? addedAt;

  FavoriteItem copyWith({
    String? title,
    String? subtitle,
    String? thumbnailUrl,
    bool? isFavorite,
    List<String>? tags,
    DateTime? addedAt,
  }) {
    return FavoriteItem(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

/// Cursor/page response for favorites listing.
@immutable
class FavoritesPage {
  const FavoritesPage({
    required this.items,
    this.nextCursor,
  });

  final List<FavoriteItem> items;
  final String? nextCursor;

  FavoritesPage merge(FavoritesPage next) {
    return FavoritesPage(
      items: [...items, ...next.items],
      nextCursor: next.nextCursor,
    );
  }
}

/// Repository so UI/providers are decoupled from networking/storage.
abstract class FavoritesRepository {
  Future<FavoritesPage> list({
    String? cursor,
    int limit = 20,
    List<String>? tags,
    String? query,
  });

  Future<bool> toggle({
    required String itemId,
    required bool nextValue,
  });

  Future<bool> bulkToggle({
    required List<String> itemIds,
    required bool nextValue,
  });

  Future<void> addTag({
    required String itemId,
    required String tag,
  });

  Future<void> removeTag({
    required String itemId,
    required String tag,
  });
}

/// Provide a concrete implementation at app bootstrap with overrideWithValue.
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  throw UnimplementedError('Inject FavoritesRepository in main.dart');
}); // A repository Provider centralizes data access and is easily overridden for tests/boot. [22][8]

/// Stateless filter for listing favorites (used by family providers).
@immutable
class FavoritesQuery {
  const FavoritesQuery({
    this.tags = const <String>[],
    this.search,
    this.pageSize = 20,
  });

  final List<String> tags;
  final String? search;
  final int pageSize;

  @override
  bool operator ==(Object other) {
    return other is FavoritesQuery &&
        _listEq(other.tags, tags) &&
        other.search == search &&
        other.pageSize == pageSize;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[...tags, search, pageSize]);

  static bool _listEq(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Read-only initial page fetch; pagination is managed by a controller below.
final favoritesFirstPageProvider = FutureProvider.family.autoDispose<FavoritesPage, FavoritesQuery>((ref, q) async {
  final repo = ref.watch(favoritesRepositoryProvider);
  final page = await repo.list(
    cursor: null,
    limit: q.pageSize,
    tags: q.tags.isEmpty ? null : q.tags,
    query: (q.search ?? '').trim().isEmpty ? null : q.search!.trim(),
  );
  return page;
}); // FutureProvider.family is ideal for parameterized, cached async fetches. [22][23]

/// Paging + cache + optimistic toggle: controller holds current list and cursor.
@immutable
class FavoritesState {
  const FavoritesState({
    required this.items,
    required this.cursor,
    required this.loading,
    this.error,
  });

  final List<FavoriteItem> items;
  final String? cursor;
  final bool loading;
  final Object? error;

  FavoritesState copy({
    List<FavoriteItem>? items,
    String? cursor,
    bool? loading,
    Object? error,
  }) {
    return FavoritesState(
      items: items ?? this.items,
      cursor: cursor ?? this.cursor,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  static const empty = FavoritesState(items: <FavoriteItem>[], cursor: null, loading: false);
}

/// An AsyncNotifier that initializes from first page and supports loadMore and toggle with optimistic updates.
class FavoritesController extends AsyncNotifier<FavoritesState> {
  FavoritesQuery get _q => _query ?? const FavoritesQuery();
  FavoritesQuery? _query;

  @override
  FutureOr<FavoritesState> build() async {
    // If a query was provided via init(query), use it; otherwise stay empty until init() called.
    return FavoritesState.empty;
  } // AsyncNotifier build provides AsyncValue and access to ref for reads/side-effects. [21][24]

  /// Optional one-time initializer to set filters and prefetch.
  Future<void> init(FavoritesQuery query) async {
    _query = query;
    await refresh();
  }

  Future<void> refresh() async {
    final repo = ref.read(favoritesRepositoryProvider);
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() => repo.list(
          cursor: null,
          limit: _q.pageSize,
          tags: _q.tags.isEmpty ? null : _q.tags,
          query: ( _q.search ?? '').trim().isEmpty ? null : _q.search!.trim(),
        ));
    state = res.whenData((page) => AsyncData(FavoritesState(items: page.items, cursor: page.nextCursor, loading: false)).value);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? FavoritesState.empty;
    if (current.loading || current.cursor == null) return;
    final repo = ref.read(favoritesRepositoryProvider);
    state = AsyncData(current.copy(loading: true));
    final res = await AsyncValue.guard(() => repo.list(
          cursor: current.cursor,
          limit: _q.pageSize,
          tags: _q.tags.isEmpty ? null : _q.tags,
          query: ( _q.search ?? '').trim().isEmpty ? null : _q.search!.trim(),
        ));
    res.when(
      data: (page) {
        final merged = FavoritesState(
          items: [...current.items, ...page.items],
          cursor: page.nextCursor,
          loading: false,
        );
        state = AsyncData(merged);
      },
      loading: () => state = AsyncData(current.copy(loading: true)),
      error: (e, st) {
        state = AsyncError(e, st);
        state = AsyncData(current.copy(loading: false, error: e));
      },
    );
  }

  /// Toggle favorite status with optimistic UI; revert on failure.
  Future<bool> toggle(String itemId, bool nextValue) async {
    final current = state.valueOrNull ?? FavoritesState.empty;
    // Apply optimistic change
    final idx = current.items.indexWhere((e) => e.id == itemId);
    if (idx >= 0) {
      final optimistic = [...current.items];
      optimistic[idx] = optimistic[idx].copyWith(isFavorite: nextValue);
      state = AsyncData(current.copy(items: optimistic));
    }
    final repo = ref.read(favoritesRepositoryProvider);
    final result = await AsyncValue.guard(() => repo.toggle(itemId: itemId, nextValue: nextValue));
    if (result.hasError || (result.value ?? false) == false) {
      // Revert
      if (idx >= 0) {
        final reverted = [...(state.valueOrNull ?? current).items];
        reverted[idx] = reverted[idx].copyWith(isFavorite: !nextValue);
        state = AsyncData((state.valueOrNull ?? current).copy(items: reverted));
      }
      return false;
    }
    return true;
  }

  /// Tag operations (no-op if item not found locally).
  Future<void> addTag(String itemId, String tag) async {
    final current = state.valueOrNull ?? FavoritesState.empty;
    final idx = current.items.indexWhere((e) => e.id == itemId);
    if (idx < 0) return;
    final optimistic = [...current.items];
    final tags = {...optimistic[idx].tags, tag}.toList();
    optimistic[idx] = optimistic[idx].copyWith(tags: tags);
    state = AsyncData(current.copy(items: optimistic));

    final repo = ref.read(favoritesRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.addTag(itemId: itemId, tag: tag));
    if (res.hasError) {
      // revert
      final revert = [...optimistic];
      final newTags = List<String>.from(revert[idx].tags)..remove(tag);
      revert[idx] = revert[idx].copyWith(tags: newTags);
      state = AsyncData((state.valueOrNull ?? current).copy(items: revert));
    }
  }

  Future<void> removeTag(String itemId, String tag) async {
    final current = state.valueOrNull ?? FavoritesState.empty;
    final idx = current.items.indexWhere((e) => e.id == itemId);
    if (idx < 0) return;
    final optimistic = [...current.items];
    final newTags = List<String>.from(optimistic[idx].tags)..remove(tag);
    optimistic[idx] = optimistic[idx].copyWith(tags: newTags);
    state = AsyncData(current.copy(items: optimistic));

    final repo = ref.read(favoritesRepositoryProvider);
    final res = await AsyncValue.guard(() => repo.removeTag(itemId: itemId, tag: tag));
    if (res.hasError) {
      // revert (re-add)
      final revert = [...optimistic];
      final tags = {...revert[idx].tags, tag}.toList();
      revert[idx] = revert[idx].copyWith(tags: tags);
      state = AsyncData((state.valueOrNull ?? current).copy(items: revert));
    }
  }
}

/// Provider for the favorites controller.
final favoritesControllerProvider = AsyncNotifierProvider<FavoritesController, FavoritesState>(() {
  return FavoritesController();
}); // AsyncNotifierProvider exposes a controller with AsyncValue for robust async state. [21][24]

/// Derived selectors

/// A family provider that returns whether an item is currently favorited in local cache.
final isFavoritedProvider = Provider.family.autoDispose<bool, String>((ref, itemId) {
  final s = ref.watch(favoritesControllerProvider).valueOrNull;
  if (s == null) return false;
  final idx = s.items.indexWhere((e) => e.id == itemId);
  return idx >= 0 ? s.items[idx].isFavorite : false;
}); // Simple derived Provider computes a boolean flag from the controller state. [22][8]

/// A future that resolves a minimal “favorites count” useful for badges.
final favoritesCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(favoritesRepositoryProvider);
  final page = await repo.list(cursor: null, limit: 1);
  // If backend exposes a total count, prefer that; otherwise count locally after refresh.
  return page.items.isEmpty ? 0 : 1; // placeholder without relying on total field
}); // FutureProvider is suited for simple single-shot async values used in badges or summary UI. [22][23]

/// Facade for widgets: easy access to controller methods without boilerplate.
class FavoritesActions {
  FavoritesActions(this._read);
  final Ref _read;

  Future<void> init(FavoritesQuery q) => _read(favoritesControllerProvider.notifier).init(q);
  Future<void> refresh() => _read(favoritesControllerProvider.notifier).refresh();
  Future<void> loadMore() => _read(favoritesControllerProvider.notifier).loadMore();
  Future<bool> toggle(String id, bool next) => _read(favoritesControllerProvider.notifier).toggle(id, next);
  Future<void> addTag(String id, String tag) => _read(favoritesControllerProvider.notifier).addTag(id, tag);
  Future<void> removeTag(String id, String tag) => _read(favoritesControllerProvider.notifier).removeTag(id, tag);
}

final favoritesActionsProvider = Provider<FavoritesActions>((ref) {
  return FavoritesActions(ref.read);
}); // A facade Provider simplifies invoking controller methods from UI callbacks. [22][8]

/// Notes on patterns used:
/// - AsyncNotifier is preferred over StateNotifier for async-init and imperative methods with AsyncValue transitions. [21][18]
/// - FutureProvider.family is used for parameterized fetches, complementing the controller for initial pages or alternate views. [22][23]
/// - Optimistic updates use AsyncValue.guard and local state mutation with revert-on-failure to keep UI responsive. [13][2]
/// - For advanced pagination, consider extracting page/cursor logic into a reusable mixin or a package if needs grow. [6][9]
