// lib/features/quick_actions/data/following_api.dart

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Unified result wrapper compatible with both `fold` and `when`.
sealed class ApiResult<T> {
  const ApiResult();
  R fold<R>({required R Function(ApiError e) onError, required R Function(T v) onSuccess});
  Future<R> when<R>({required Future<R> Function(T v) success, required Future<R> Function(ApiError e) failure});
  bool get success => this is ApiSuccess<T>;
  T? get data => this is ApiSuccess<T> ? (this as ApiSuccess<T>).value : null;
  ApiError? get error => this is ApiFailure<T> ? (this as ApiFailure<T>).err : null;
}

class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.value);
  final T value;
  @override
  R fold<R>({required R Function(ApiError e) onError, required R Function(T v) onSuccess}) => onSuccess(value);
  @override
  Future<R> when<R>({required Future<R> Function(T v) success, required Future<R> Function(ApiError e) failure}) => success(value);
}

class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.err);
  final ApiError err;
  @override
  R fold<R>({required R Function(ApiError e) onError, required R Function(T v) onSuccess}) => onError(err);
  @override
  Future<R> when<R>({required Future<R> Function(T v) success, required Future<R> Function(ApiError e) failure}) => failure(err);
}

class ApiError implements Exception {
  const ApiError({required this.message, this.code, this.details});
  final String message;
  final int? code;
  final Map<String, dynamic>? details;
  String get safeMessage => message;
  @override
  String toString() => 'ApiError(code: $code, message: $message)';
}

/// Config
class FollowingApiConfig {
  const FollowingApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 20),
    this.defaultHeaders = const {'Accept': 'application/json', 'Content-Type': 'application/json'},
  });
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final Map<String, String> defaultHeaders;
}

/// Following API client
class FollowingApi {
  FollowingApi({Dio? dio, FollowingApiConfig? config, String? authToken})
      : _config = config ?? const FollowingApiConfig(baseUrl: ''),
        _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: _config.connectTimeout,
      receiveTimeout: _config.receiveTimeout,
      sendTimeout: _config.sendTimeout,
      headers: {
        ..._config.defaultHeaders,
        if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      },
    ); // BaseOptions configure baseUrl, timeouts, and headers once for the client. [3][5]
  }

  final Dio _dio;
  final FollowingApiConfig _config;

  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // ----------------------------
  // Endpoints
  // ----------------------------

  /// List followers of a user (people who follow userId).
  Future<ApiResult<FollowPage>> listFollowers({
    required String userId,
    int page = 1,
    int limit = 50,
    CancelToken? cancelToken,
  }) async {
    return _get<FollowPage>(
      path: '/v1/follow/$userId/followers',
      query: {'page': page, 'limit': limit},
      parse: (data) => FollowPage.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 2,
    ); // GET supports cancelation and limited retries for resilience with Dio CancelToken. [1][3]
  }

  /// List accounts the user is following.
  Future<ApiResult<FollowPage>> listFollowing({
    required String userId,
    int page = 1,
    int limit = 50,
    CancelToken? cancelToken,
  }) async {
    return _get<FollowPage>(
      path: '/v1/follow/$userId/following',
      query: {'page': page, 'limit': limit},
      parse: (data) => FollowPage.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 2,
    ); // Pagination uses standard page/limit parameters consistent with common REST patterns. [12][17]
  }

  /// Check if the current user follows targetId.
  Future<ApiResult<bool>> isFollowing({
    required String targetId,
    CancelToken? cancelToken,
  }) async {
    return _get<bool>(
      path: '/v1/follow/check/$targetId',
      parse: (data) {
        if (data is Map && data['following'] is bool) return data['following'] as bool;
        if (data is bool) return data;
        return false;
      },
      cancelToken: cancelToken,
      retries: 1,
    ); // Idempotent GET with a small retry budget to recover from timeouts. [3][5]
  }

  /// Follow target user (idempotent server-side).
  Future<ApiResult<FollowAction>> follow({
    required String targetId,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final headers = {
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
    };
    return _post<FollowAction>(
      path: '/v1/follow/$targetId',
      body: const {},
      extraHeaders: headers,
      parse: (data) => FollowAction.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 0,
    ); // POST avoids aggressive retries to prevent duplicate mutations; idempotency-key can be used. [3]
  }

  /// Unfollow target user (idempotent).
  Future<ApiResult<void>> unfollow({
    required String targetId,
    CancelToken? cancelToken,
  }) async {
    return _delete<void>(
      path: '/v1/follow/$targetId',
      parse: (_) => null,
      cancelToken: cancelToken,
    ); // DELETE is idempotent; no retries to avoid masking errors. [3]
  }

  /// Bulk follow/unfollow a set of users.
  Future<ApiResult<BulkFollowResult>> bulkSetFollowing({
    required List<String> userIds,
    required bool followFlag,
    CancelToken? cancelToken,
  }) async {
    return _post<BulkFollowResult>(
      path: '/v1/follow/bulk',
      body: {'userIds': userIds, 'follow': followFlag},
      parse: (data) => BulkFollowResult.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 0,
    ); // Bulk helps synchronize optimistic UI state with backend in one call. [5]
  }

  // ----------------------------
  // Low-level helpers with retry for GET
  // ----------------------------

  Future<ApiResult<T>> _get<T>({
    required String path,
    required T Function(dynamic data) parse,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    int retries = 0,
  }) async {
    return _withRetry<T>(
      retries: retries,
      request: () async {
        final res = await _dio.get<dynamic>(path, queryParameters: query, cancelToken: cancelToken);
        return _parseResponse<T>(res, parse);
      },
    ); // Passing CancelToken enables canceling in-flight GETs when the UI unmounts or query changes. [1][4]
  }

  Future<ApiResult<T>> _post<T>({
    required String path,
    required Map<String, dynamic>? body,
    required T Function(dynamic data) parse,
    Map<String, String>? extraHeaders,
    CancelToken? cancelToken,
    int retries = 0,
  }) async {
    return _withRetry<T>(
      retries: retries,
      request: () async {
        final res = await _dio.post<dynamic>(
          path,
          data: body == null ? null : jsonEncode(body),
          cancelToken: cancelToken,
          options: Options(headers: extraHeaders),
        );
        return _parseResponse<T>(res, parse);
      },
    );
  }

  Future<ApiResult<T>> _delete<T>({
    required String path,
    required T Function(dynamic data) parse,
    CancelToken? cancelToken,
    int retries = 0,
  }) async {
    return _withRetry<T>(
      retries: retries,
      request: () async {
        final res = await _dio.delete<dynamic>(path, cancelToken: cancelToken);
        return _parseResponse<T>(res, parse);
      },
    );
  }

  Future<ApiResult<T>> _withRetry<T>({
    required Future<ApiResult<T>> Function() request,
    required int retries,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          return ApiFailure<T>(ApiError(message: 'Cancelled', code: -1));
        }
        attempt += 1;
        final transient = _isTransient(e);
        if (!transient || attempt > retries) {
          return ApiFailure<T>(_mapDioError(e));
        }
        final delayMs = _backoffDelayMs(attempt);
        await Future.delayed(Duration(milliseconds: delayMs));
      } catch (e) {
        return ApiFailure<T>(ApiError(message: e.toString()));
      }
    }
  }

  bool _isTransient(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        return code >= 500;
      default:
        return false;
    }
  }

  int _backoffDelayMs(int attempt) {
    final base = 250 * (1 << (attempt - 1));
    final jitter = (base * 0.2).toInt();
    return base + (DateTime.now().microsecondsSinceEpoch % (jitter == 0 ? 1 : jitter));
  }

  ApiResult<T> _parseResponse<T>(Response res, T Function(dynamic) parse) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) {
      return ApiSuccess<T>(parse(res.data));
    }
    return ApiFailure<T>(ApiError(
      message: res.statusMessage ?? 'HTTP $code',
      code: code,
      details: _asMap(res.data),
    ));
  }

  ApiError _mapDioError(DioException e) {
    final code = e.response?.statusCode;
    final msg = e.message ?? 'Network error';
    return ApiError(message: msg, code: code, details: _asMap(e.response?.data));
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final v = jsonDecode(data);
        if (v is Map<String, dynamic>) return v;
      } catch (_) {}
    }
    return null;
  }
}

// ----------------------------
// DTOs
// ----------------------------

/// Minimal public profile card for follow lists (presentation-friendly).
class UserSummary {
  UserSummary({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.headline,
    this.verified = false,
    this.isFollowing = false,
  });

  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? headline;
  final bool verified;
  final bool isFollowing;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      headline: json['headline'] as String?,
      verified: (json['verified'] ?? false) as bool,
      isFollowing: (json['isFollowing'] ?? false) as bool,
    );
  }
}

class FollowPage {
  FollowPage({required this.items, required this.page, required this.limit, required this.total});
  final List<UserSummary> items;
  final int page;
  final int limit;
  final int total;

  factory FollowPage.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List?) ?? const [];
    return FollowPage(
      items: list.map((e) => UserSummary.fromJson(e as Map<String, dynamic>)).toList(growable: false),
      page: (json['page'] ?? 1) as int,
      limit: (json['limit'] ?? list.length) as int,
      total: (json['total'] ?? list.length) as int,
    ); // Pagination payload includes items, page, limit, and total, aligning with common REST pagination guidance. [12][18]
  }
}

class FollowAction {
  FollowAction({required this.targetId, required this.following});
  final String targetId;
  final bool following;

  factory FollowAction.fromJson(Map<String, dynamic> json) {
    return FollowAction(
      targetId: (json['targetId'] ?? '') as String,
      following: (json['following'] ?? false) as bool,
    );
  }
}

class BulkFollowResult {
  BulkFollowResult({required this.updated, required this.failed});
  final List<String> updated; // userIds updated
  final List<String> failed; // userIds failed

  factory BulkFollowResult.fromJson(Map<String, dynamic> json) {
    return BulkFollowResult(
      updated: ((json['updated'] as List?) ?? const []).map((e) => e.toString()).toList(growable: false),
      failed: ((json['failed'] as List?) ?? const []).map((e) => e.toString()).toList(growable: false),
    );
  }
}
