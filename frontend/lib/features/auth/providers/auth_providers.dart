// lib/features/auth/providers/auth_providers.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/network/api_result.dart';
import '../../../core/errors/app_exception.dart';
import '../data/auth_api.dart';
import '../../../models/user.dart';

/// Provider for AuthApi
final authApiProvider = Provider<AuthApi>((ref) => AuthApi());

/// Synchronous auth snapshot for router consumption.
@immutable
class SimpleAuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? token;

  const SimpleAuthState({
    required this.isLoading,
    required this.isLoggedIn,
    required this.token,
  });

  const SimpleAuthState.loading()
      : this(isLoading: true, isLoggedIn: false, token: null);

  const SimpleAuthState.unauth()
      : this(isLoading: false, isLoggedIn: false, token: null);

  const SimpleAuthState.auth(String token)
      : this(isLoading: false, isLoggedIn: true, token: token);
}

/// Main auth notifier with AsyncValue<User?> state and ApiResult integration.
final authStateProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AsyncValue.data(null)) {
    _init();
  }

  // Router refresh stream
  final _authStreamController = StreamController<SimpleAuthState>.broadcast();
  Stream<SimpleAuthState> get authChangesStream => _authStreamController.stream;

  Future<void> _init() async {
    _emitSnapshot(const SimpleAuthState.loading());

    final token = await TokenStorage.read();
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data(null);
      _emitSnapshot(const SimpleAuthState.unauth());
      return;
    }

    // Try to fetch user profile with existing token
    state = const AsyncValue.loading();
    final result = await ref.read(authApiProvider).me();
    result.fold(
      onSuccess: (data) {
        final user = User.fromJson(data['data'] ?? data);
        state = AsyncValue.data(user);
        _emitSnapshot(SimpleAuthState.auth(user.token ?? token));
      },
      onError: (err) {
        // Keep authenticated with token if /me fails transiently
        final fallbackUser = User.fromJson(<String, dynamic>{'token': token});
        state = AsyncValue.data(fallbackUser);
        _emitSnapshot(SimpleAuthState.auth(token));
      },
    );
  }

  void _emitSnapshot(SimpleAuthState snapshot) {
    if (!_authStreamController.isClosed) {
      _authStreamController.add(snapshot);
    }
  }

  /// Login with email and password, return ApiResult for UI handling.
  Future<ApiResult<Map<String, dynamic>>> login(String email, String password) async {
    state = const AsyncValue.loading();
    _emitSnapshot(const SimpleAuthState.loading());

    final result = await ref.read(authApiProvider).login(email, password);
    return result.fold(
      onSuccess: (data) {
        final user = User.fromJson(data['data'] ?? data);
        final token = user.token ?? _extractToken(data);
        
        state = AsyncValue.data(user);
        _emitSnapshot(SimpleAuthState.auth(token ?? ''));
        return ApiResult.ok(data);
      },
      onError: (err) {
        state = AsyncValue.error(err, StackTrace.current);
        _emitSnapshot(const SimpleAuthState.unauth());
        return ApiResult.fail(err);
      },
    );
  }

  /// Register new account, return ApiResult for UI handling.
  Future<ApiResult<Map<String, dynamic>>> register(Map<String, dynamic> payload) async {
    state = const AsyncValue.loading();
    _emitSnapshot(const SimpleAuthState.loading());

    final result = await ref.read(authApiProvider).register(payload);
    return result.fold(
      onSuccess: (data) {
        final user = User.fromJson(data['data'] ?? data);
        final token = user.token ?? _extractToken(data);
        
        state = AsyncValue.data(user);
        _emitSnapshot(SimpleAuthState.auth(token ?? ''));
        return ApiResult.ok(data);
      },
      onError: (err) {
        state = AsyncValue.error(err, StackTrace.current);
        _emitSnapshot(const SimpleAuthState.unauth());
        return ApiResult.fail(err);
      },
    );
  }

  /// Load current user (called from bootstrap and after token changes).
  Future<void> loadMe() async {
    final token = await TokenStorage.read();
    if (token == null || token.isEmpty) {
      state = const AsyncValue.data(null);
      _emitSnapshot(const SimpleAuthState.unauth());
      return;
    }

    state = const AsyncValue.loading();
    _emitSnapshot(const SimpleAuthState.loading());

    final result = await ref.read(authApiProvider).me();
    result.fold(
      onSuccess: (data) {
        final user = User.fromJson(data['data'] ?? data);
        state = AsyncValue.data(user);
        _emitSnapshot(SimpleAuthState.auth(user.token ?? token));
      },
      onError: (_) {
        // Graceful fallback: keep token-based auth on transient /me failure
        final fallbackUser = User.fromJson(<String, dynamic>{'token': token});
        state = AsyncValue.data(fallbackUser);
        _emitSnapshot(SimpleAuthState.auth(token));
      },
    );
  }

  /// Logout and clear all stored credentials.
  Future<void> logout() async {
    await TokenStorage.clear();
    state = const AsyncValue.data(null);
    _emitSnapshot(const SimpleAuthState.unauth());
  }

  /// Extract token from various response shapes.
  String? _extractToken(Map<String, dynamic> data) {
    return data['accessToken'] as String? ??
        data['token'] as String? ??
        (data['data'] as Map?)?['accessToken'] as String? ??
        (data['data'] as Map?)?['token'] as String?;
  }

  @override
  void dispose() {
    _authStreamController.close();
    super.dispose();
  }
}

/// Synchronous auth state for router consumption.
final authSimpleProvider = Provider<SimpleAuthState>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) return const SimpleAuthState.unauth();
      final token = user.token;
      return (token != null && token.isNotEmpty)
          ? SimpleAuthState.auth(token)
          : const SimpleAuthState.unauth();
    },
    loading: () => const SimpleAuthState.loading(),
    error: (_, __) => const SimpleAuthState.unauth(),
  );
});

/// Stream provider for GoRouter refresh listening.
final authStreamProvider = Provider<Stream<SimpleAuthState>>((ref) {
  return ref.read(authStateProvider.notifier).authChangesStream;
});
