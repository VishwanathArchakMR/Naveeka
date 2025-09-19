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
});

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
});

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
    return FollowState.empty;
  }

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
    state = res.whenData((page) => AsyncData(FollowState(items: page.items, cursor: page.nextCursor, loading: false)).value);
  }

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
  }

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
      if (idx >= 0) {
        final revert = [...(state.valueOrNull ?? current).items];
        revert[idx] = revert[idx].copyWith(isFollowing: !next);
        state = AsyncData((state.valueOrNull ?? current).copy(items: revert));
      }
    }
    return ok;
  }
}

/// Provider for the follow controller.
final followControllerProvider =
    AsyncNotifierProvider<FollowController, FollowState>(FollowController.new);

/// Facade to simplify calling controller/repo from UI callbacks.
class FollowingActions {
  FollowingActions(this._ref);
  final Ref _ref;

  Future<void> init(FollowQuery q) => _ref.read(followControllerProvider.notifier).init(q);
  Future<void> refresh() => _ref.read(followControllerProvider.notifier).refresh();
  Future<void> loadMore() => _ref.read(followControllerProvider.notifier).loadMore();
  Future<bool> setFollowing(String userId, bool next) =>
      _ref.read(followControllerProvider.notifier).setFollowing(userId, next);
}

final followingActionsProvider = Provider<FollowingActions>((ref) {
  return FollowingActions(ref);
});
