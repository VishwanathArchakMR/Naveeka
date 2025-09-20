// lib/features/quick_actions/data/favorites_api.dart

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Lightweight result wrapper compatible with both `fold` and `when`
/// (mirrors the style used in other data modules).
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
  Future<R> when<R>({required Future<R> Function(T v) success, required Future<R> Function(ApiError e) failure}) =>
      success(value);
}

class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.err);
  final ApiError err;
  @override
  R fold<R>({required R Function(ApiError e) onError, required R Function(T v) onSuccess}) => onError(err);
  @override
  Future<R> when<R>({required Future<R> Function(T v) success, required Future<R> Function(ApiError e) failure}) =>
      failure(err);
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

/// Config for FavoritesApi
class FavoritesApiConfig {
  const FavoritesApiConfig({
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

/// Favorites API client (Dio)
class FavoritesApi {
  FavoritesApi({Dio? dio, FavoritesApiConfig? config, String? authToken})
      : _config = config ?? const FavoritesApiConfig(baseUrl: ''),
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
    );
  }

  final Dio _dio;
  final FavoritesApiConfig _config;

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

  /// List favorites for current user (paginated).
  Future<ApiResult<FavoritePage>> listFavorites({
    int page = 1,
    int limit = 50,
    CancelToken? cancelToken,
  }) async {
    return _get<FavoritePage>(
      path: '/v1/favorites',
      query: {'page': page, 'limit': limit},
      parse: (data) => FavoritePage.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 2,
    );
  }

  /// Check if a place is favorited by the current user.
  Future<ApiResult<bool>> isFavorite({
    required String placeId,
    CancelToken? cancelToken,
  }) async {
    return _get<bool>(
      path: '/v1/favorites/$placeId',
      parse: (data) {
        if (data is Map && data['favorite'] is bool) return data['favorite'] as bool;
        if (data is bool) return data;
        return false;
      },
      cancelToken: cancelToken,
      retries: 1,
    );
  }

  /// Add to favorites (idempotent server-side).
  Future<ApiResult<FavoriteItem>> addFavorite({
    required String placeId,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final headers = {
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
    };
    return _post<FavoriteItem>(
      path: '/v1/favorites',
      body: {'placeId': placeId},
      extraHeaders: headers,
      parse: (data) => FavoriteItem.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 0,
    );
  }

  /// Remove from favorites (idempotent).
  Future<ApiResult<void>> removeFavorite({
    required String placeId,
    CancelToken? cancelToken,
  }) async {
    return _delete<void>(
      path: '/v1/favorites/$placeId',
      parse: (_) {},
      cancelToken: cancelToken,
    );
  }

  /// Bulk set favorites for multiple places in one call.
  Future<ApiResult<BulkFavoriteResult>> bulkSetFavorite({
    required List<String> placeIds,
    required bool favorite,
    CancelToken? cancelToken,
  }) async {
    return _post<BulkFavoriteResult>(
      path: '/v1/favorites/bulk',
      body: {'placeIds': placeIds, 'favorite': favorite},
      parse: (data) => BulkFavoriteResult.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 0,
    );
  }

  // ----------------------------
  // Low-level HTTP helpers with basic retries for GET
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
    );
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
          return ApiFailure<T>(const ApiError(message: 'Cancelled', code: -1));
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
    final mod = jitter == 0 ? 1 : jitter;
    return base + (DateTime.now().microsecondsSinceEpoch % mod);
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

  // Translate DioException to ApiError consistently with BookingApi.
  ApiError _mapDioError(DioException e) {
    final code = e.response?.statusCode;
    final details = _asMap(e.response?.data);
    String message;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        message = 'Connection timed out';
        break;
      case DioExceptionType.sendTimeout:
        message = 'Send timed out';
        break;
      case DioExceptionType.receiveTimeout:
        message = 'Receive timed out';
        break;
      case DioExceptionType.badCertificate:
        message = 'Bad TLS certificate';
        break;
      case DioExceptionType.connectionError:
        message = 'Network connection error';
        break;
      case DioExceptionType.cancel:
        message = 'Cancelled';
        break;
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final serverMsg = (details?['message'] ?? e.response?.statusMessage ?? 'HTTP $status').toString();
        message = serverMsg;
        break;
      case DioExceptionType.unknown:
        message = e.message ?? 'Unknown network error';
        break;
    }
    return ApiError(message: message, code: code, details: details);
  }
}

// ----------------------------
// DTOs
// ----------------------------

class FavoriteItem {
  FavoriteItem({
    required this.id,
    required this.placeId,
    required this.createdAt,
    this.placeName,
    this.coverImage,
  });

  final String id;
  final String placeId;
  final DateTime createdAt;
  final String? placeName;
  final String? coverImage;

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: (json['id'] ?? '') as String,
      placeId: (json['placeId'] ?? '') as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      placeName: json['placeName'] as String?,
      coverImage: json['coverImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'placeId': placeId,
        'createdAt': createdAt.toIso8601String(),
        'placeName': placeName,
        'coverImage': coverImage,
      };
}

class FavoritePage {
  FavoritePage({required this.items, required this.page, required this.limit, required this.total});
  final List<FavoriteItem> items;
  final int page;
  final int limit;
  final int total;

  factory FavoritePage.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List?) ?? const [];
    return FavoritePage(
      items: list.map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>)).toList(growable: false),
      page: (json['page'] ?? 1) as int,
      limit: (json['limit'] ?? list.length) as int,
      total: (json['total'] ?? list.length) as int,
    );
  }
}

class BulkFavoriteResult {
  BulkFavoriteResult({
    required this.updated,
    required this.failed,
  });

  final List<String> updated; // placeIds updated
  final List<String> failed; // placeIds failed

  factory BulkFavoriteResult.fromJson(Map<String, dynamic> json) {
    return BulkFavoriteResult(
      updated: ((json['updated'] as List?) ?? const []).map((e) => e.toString()).toList(growable: false),
      failed: ((json['failed'] as List?) ?? const []).map((e) => e.toString()).toList(growable: false),
    );
  }
}
