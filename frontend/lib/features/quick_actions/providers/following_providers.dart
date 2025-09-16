// lib/features/quick_actions/providers/following_providers.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal person/account model used by the follow graph.
@immutable
class FollowAccount {
  const FollowAccount({
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.isFollowing = false,
    this.isFollower = false,
    this.followedAt,
  });

  final String userId;
  final String displayName;
  final String? username;
  final String? avatarUrl;

  final bool isFollowing; // I follow them?
  final bool isFollower; // They follow me?
  final DateTime? followedAt;

  FollowAccount copyWith({
    String? displayName,
    String? username,
    String? avatarUrl,
    bool? isFollowing,
    bool? isFollower,
    DateTime? followedAt,
  }) {
    return FollowAccount(
      userId: userId,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollower: isFollower ?? this.isFollower,
      followedAt: followedAt ?? this.followedAt,
    );
  }
}

/// Cursor-based page response.
@immutable
class FollowPage {
  const FollowPage({required this.items, this.nextCursor});

  final List<FollowAccount> items;
  final String? nextCursor;

  FollowPage merge(FollowPage next) => FollowPage(items: [...items, ...next.items], nextCursor: next.nextCursor);
}

/// Directions for graph listing.
enum FollowListKind { following, followers }

/// Repository abstraction for social graph operations.
abstract class FollowingRepository {
  Future<FollowPage> list({
    required FollowListKind kind,
    String? cursor,
    int limit = 20,
    String? query,
  });

  Future<bool> follow({required String userId});

  Future<bool> unfollow({required String userId});
}

/// Injection point for a concrete repo (override in main/bootstrap).
final followingRepositoryProvider = Provider<FollowingRepository>((ref) {
  throw UnimplementedError('Provide FollowingRepository via override');
}); // A plain Provider centralizes the repository and is override-friendly for tests and environments. [22][23]

/// Stateless query key for listing followers/following (family providers friendly).
@immutable
class FollowQuery {
  const FollowQuery({
    required this.kind,
    this.search,
    this.pageSize = 20,
  });

  final FollowListKind kind;
  final String? search;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is FollowQuery && other.kind == kind && other.search == search && other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(kind, search, pageSize);
}

/// First page fetch via FutureProvider.family (read-only, cached).
final followFirstPageProvider = FutureProvider.family.autoDispose<FollowPage, FollowQuery>((ref, q) async {
  final repo = ref.watch(followingRepositoryProvider);
  final page = await repo.list(
    kind: q.kind,
    cursor: null,
    limit: q.pageSize,
    query: (q.search ?? '').trim().isEmpty ? null : q.search!.trim(),
  );
  return page;
}); // FutureProvider.family is ideal for parameterized async fetches and plays well with caching/autoDispose lifecycles. [22][15]

/// Controller state with list, cursor, loading and optional error.
@immutable
class FollowState {
  const FollowState({required this.items, required this.cursor, required this.loading, this.error});

  final List<FollowAccount> items;
  final String? cursor;
  final bool loading;
  final Object? error;

  FollowState copy({List<FollowAccount>? items, String? cursor, bool? loading, Object? error}) => FollowState(
        items: items ?? this.items,
        cursor: cursor ?? this.cursor,
        loading: loading ?? this.loading,
        error: error,
      );

  static const empty = FollowState(items: <FollowAccount>[], cursor: null, loading: false);
}

/// AsyncNotifier that manages paging and optimistic follow/unfollow mutations.
class FollowController extends AsyncNotifier<FollowState> {
  FollowQuery? _query;

  @override
  FutureOr<FollowState> build() async {
    // Start empty; call init(query) before use, or keep read-only via followFirstPageProvider.
    return FollowState.empty;
  } // AsyncNotifier supports async init and exposes ref for side effects and reads. [21][4]

  Future<void> init(FollowQuery query) async {
    _query = query;
    await refresh();
  }

  Future<void> refresh() async {
    final repo = ref.read(followingRepositoryProvider);
    final q = _query ?? const FollowQuery(kind: FollowListKind.following);
    state = const AsyncLoading();
    final res = await AsyncValue.guard(() => repo.list(
          kind: q.kind,
          cursor: null,
          limit: q.pageSize,
          query: (q.search ?? '').trim().isEmpty ? null : q.search!.trim(),
        ));
    state = res.whenData((page) => AsyncData(FollowState(items: page.items, cursor: page.nextCursor, loading: false)).value!);
  } // AsyncValue.guard simplifies try/catch and maps to AsyncData/AsyncError consistently for UI. [1][14]

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? FollowState.empty;
    if (current.loading || current.cursor == null) return;
    final repo = ref.read(followingRepositoryProvider);
    final q = _query ?? const FollowQuery(kind: FollowListKind.following);
    state = AsyncData(current.copy(loading: true));
    final res = await AsyncValue.guard(() => repo.list(
          kind: q.kind,
          cursor: current.cursor,
          limit: q.pageSize,
          query: (q.search ?? '').trim().isEmpty ? null : q.search!.trim(),
        ));
    res.when(
      data: (page) {
        final merged = FollowState(
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
  } // This mirrors offset/cursor pagination patterns recommended for Riverpod lists. [6][20]

  /// Optimistic follow toggle; returns final success.
  Future<bool> setFollowing(String userId, bool next) async {
    final current = state.valueOrNull ?? FollowState.empty;
    final idx = current.items.indexWhere((e) => e.userId == userId);
    if (idx >= 0) {
      final optimistic = [...current.items];
      optimistic[idx] = optimistic[idx].copyWith(isFollowing: next);
      state = AsyncData(current.copy(items: optimistic));
    }
    final repo = ref.read(followingRepositoryProvider);
    final res = await AsyncValue.guard(() async {
      return next ? repo.follow(userId: userId) : repo.unfollow(userId: userId);
    });
    final ok = res.value ?? false;
    if (!ok) {
      // revert
      if (idx >= 0) {
        final revert = [...(state.valueOrNull ?? current).items];
        revert[idx] = revert[idx].copyWith(isFollowing: !next);
        state = AsyncData((state.valueOrNull ?? current).copy(items: revert));
      }
    }
    return ok;
  } // Optimistic mutation pattern updates UI immediately and reverts on failure per Riverpod guidance. [7][16]
}

/// Provider for the follow controller.
final followControllerProvider = AsyncNotifierProvider<FollowController, FollowState>(() {
  return FollowController();
}); // AsyncNotifierProvider exposes an AsyncValue<FollowState> that widgets can watch for data/loading/error. [21][4]

/// Derived selectors

/// Check if a given userId is currently followed (based on local cache).
final isFollowingProvider = Provider.family.autoDispose<bool, String>((ref, userId) {
  final s = ref.watch(followControllerProvider).valueOrNull;
  if (s == null) return false;
  final idx = s.items.indexWhere((e) => e.userId == userId);
  return idx >= 0 ? s.items[idx].isFollowing : false;
}); // A small derived Provider makes it easy to toggle button state per user row without extra queries. [22][24]

/// Count for badges; if your backend exposes totals, prefer that in repository.
final followingCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(followingRepositoryProvider);
  final page = await repo.list(kind: FollowListKind.following, cursor: null, limit: 1);
  return page.items.length; // replace with total if available
}); // FutureProvider is suited for small badge-like async values read by headers or tabs. [22][25]

final followersCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(followingRepositoryProvider);
  final page = await repo.list(kind: FollowListKind.followers, cursor: null, limit: 1);
  return page.items.length; // replace with total if available
}); // Separate counts enable independent invalidation and simpler UI bindings for badges. [22][25]

/// Facade to simplify calling controller/repo from UI callbacks.
class FollowingActions {
  FollowingActions(this._read);
  final Ref _read;

  Future<void> init(FollowQuery q) => _read(followControllerProvider.notifier).init(q);
  Future<void> refresh() => _read(followControllerProvider.notifier).refresh();
  Future<void> loadMore() => _read(followControllerProvider.notifier).loadMore();
  Future<bool> setFollowing(String userId, bool next) => _read(followControllerProvider.notifier).setFollowing(userId, next);
}

final followingActionsProvider = Provider<FollowingActions>((ref) {
  return FollowingActions(ref.read);
}); // A facade Provider offers a minimal surface for screens/buttons to trigger actions without wiring state manually. [22][23]

/// Notes:
/// - Use followFirstPageProvider(q) for simple screens that just need a single page and don’t mutate state, and the controller for infinite lists with toggles. [22][6]
/// - Always guard async calls and consider ref.mounted when awaiting long operations to avoid setState on disposed notifiers. [1][11]
/// - If you later adopt Riverpod 3 “mutations”, you can refactor the optimistic update to use the new mutation API while keeping the same repository surface. [10][7]
