// lib/features/wishlist/providers/wishlist_providers.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wishlist_api.dart';
import '../../../models/place.dart';

/// DI for the Wishlist API (override if needed in app bootstrap).
final wishlistApiProvider = Provider<WishlistApi>((ref) => WishlistApi());

/// ----------------------------
/// Basic non-paginated wishlist
/// ----------------------------
@immutable
class WishlistState {
  const WishlistState({
    this.items = const <Place>[],
    this.loading = false,
    this.initialized = false,
    this.error,
  });

  final List<Place> items;
  final bool loading;
  final bool initialized;
  final String? error;

  WishlistState copyWith({
    List<Place>? items,
    bool? loading,
    bool? initialized,
    String? error,
  }) {
    return WishlistState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      initialized: initialized ?? this.initialized,
      error: error,
    );
  }
}

class WishlistNotifier extends StateNotifier<WishlistState> {
  WishlistNotifier(this.ref) : super(const WishlistState());

  final Ref ref;

  /// Load the wishlist from backend (uses ETag-aware list under the hood).
  Future<void> load({bool refresh = false}) async {
    if (!refresh) {
      state = state.copyWith(loading: true, error: null);
    }

    final result = await ref.read(wishlistApiProvider).list(useConditionalGet: !refresh);
    if (result.success) {
      final places = result.data ?? const <Place>[];
      state = state.copyWith(
        items: places,
        loading: false,
        initialized: true,
        error: null,
      );
    } else {
      state = state.copyWith(
        loading: false,
        initialized: true,
        error: result.error?.message ?? 'Failed to load wishlist',
      );
    }
  }

  /// Add (not optimistic to avoid constructing unknown Place fields reliably).
  Future<bool> add(String placeId, {String notes = ''}) async {
    final res = await ref.read(wishlistApiProvider).add(placeId, notes: notes);
    if (res.success) {
      await load(refresh: true);
      return true;
    }
    return false;
  }

  /// Remove (optimistic: we know the existing list).
  Future<bool> remove(String placeId) async {
    final original = state.items;
    state = state.copyWith(items: original.where((p) => p.id != placeId).toList());

    final res = await ref.read(wishlistApiProvider).remove(placeId);
    if (res.success) {
      return true;
    } else {
      state = state.copyWith(items: original);
      return false;
    }
  }

  bool isWishlisted(String placeId) => state.items.any((p) => p.id == placeId);
}

/// Provider for Wishlist
final wishlistProvider = StateNotifierProvider<WishlistNotifier, WishlistState>(
  (ref) => WishlistNotifier(ref),
);

/// ----------------------------
/// Paginated wishlist (cursor)
/// ----------------------------
@immutable
class PagedState<T> {
  const PagedState({required this.items, required this.cursor, required this.loading, this.error});
  final List<T> items;
  final String? cursor;
  final bool loading;
  final Object? error;

  PagedState<T> copy({List<T>? items, String? cursor, bool? loading, Object? error}) => PagedState<T>(
        items: items ?? this.items,
        cursor: cursor ?? this.cursor,
        loading: loading ?? this.loading,
        error: error,
      );

  static PagedState<T> empty<T>() => PagedState<T>(items: const <T>[], cursor: null, loading: false);
}

class WishlistPagedController extends AsyncNotifier<PagedState<Place>> {
  @override
  FutureOr<PagedState<Place>> build() async {
    // Load the first page when the controller is first used.
    return refresh();
  }

  WishlistApi get _api => ref.read(wishlistApiProvider);

  Future<PagedState<Place>> refresh() async {
    final pageRes = await _api.listPage(limit: 20, cursor: null);
    if (pageRes.success) {
      final page = pageRes.data!;
      final next = page.nextCursor;
      return PagedState<Place>(items: page.items, cursor: next, loading: false);
    } else {
      // Bubble the error via AsyncError then recover to a non-loading state.
      final err = pageRes.error!;
      // Let Riverpod display the error if observed as AsyncValue.error.
      Future.microtask(() => state = AsyncError(err, StackTrace.current));
      return PagedState.empty();
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? PagedState.empty<Place>();
    if (current.loading || current.cursor == null) return;
    state = AsyncData(current.copy(loading: true));
    final pageRes = await _api.listPage(limit: 20, cursor: current.cursor);
    if (pageRes.success) {
      final page = pageRes.data!;
      state = AsyncData(
        current.copy(
          items: [...current.items, ...page.items],
          cursor: page.nextCursor,
          loading: false,
        ),
      );
    } else {
      // Keep current items, drop loading, attach error
      state = AsyncData(current.copy(loading: false, error: pageRes.error));
    }
  }
}

final wishlistPagedControllerProvider =
    AsyncNotifierProvider<WishlistPagedController, PagedState<Place>>(() => WishlistPagedController());

/// ----------------------------
/// Count / exists helpers
/// ----------------------------
final wishlistCountProvider = FutureProvider<int>((ref) async {
  final res = await ref.read(wishlistApiProvider).count();
  return res.success ? (res.data ?? 0) : 0;
});

final wishlistExistsProvider = FutureProvider.family<bool, String>((ref, placeId) async {
  final res = await ref.read(wishlistApiProvider).exists(placeId);
  return res.success ? (res.data ?? false) : false;
});

/// ----------------------------
/// Actions facade for UI wiring
/// ----------------------------
class WishlistActions {
  WishlistActions(this._read);
  final Ref _read;

  Future<void> refresh() => _read(wishlistProvider.notifier).load(refresh: true);
  Future<bool> add(String placeId, {String notes = ''}) => _read(wishlistProvider.notifier).add(placeId, notes: notes);
  Future<bool> remove(String placeId) => _read(wishlistProvider.notifier).remove(placeId);

  // Paged
  Future<void> pagedRefresh() async {
    final controller = _read(wishlistPagedControllerProvider.notifier);
    final next = await controller.refresh();
    controller.state = AsyncData(next);
  }

  Future<void> pagedLoadMore() => _read(wishlistPagedControllerProvider.notifier).loadMore();
}

final wishlistActionsProvider = Provider<WishlistActions>((ref) => WishlistActions(ref.read));
