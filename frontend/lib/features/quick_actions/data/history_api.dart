// lib/features/quick_actions/data/history_api.dart

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Unified result wrapper compatible with fold/when patterns.
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
class HistoryApiConfig {
  const HistoryApiConfig({
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

/// History API client
class HistoryApi {
  HistoryApi({Dio? dio, HistoryApiConfig? config, String? authToken})
      : _config = config ?? const HistoryApiConfig(baseUrl: ''),
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
    ); // BaseOptions configure baseUrl, timeouts, and headers for all requests issued by Dio. [3]
  }

  final Dio _dio;
  final HistoryApiConfig _config;

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

  /// List history items with optional type and date filters.
  Future<ApiResult<HistoryPage>> list({
    int page = 1,
    int limit = 50,
    String? type, // viewed | searched | booked | shared | custom
    DateTime? from,
    DateTime? to,
    CancelToken? cancelToken,
  }) async {
    final q = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (type != null && type.isNotEmpty) 'type': type,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    return _get<HistoryPage>(
      path: '/v1/history',
      query: q,
      parse: (data) => HistoryPage.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 2,
    ); // GET supports CancelToken for cancellation and small retry budget for transient issues. [1][3]
  }

  /// Append a history event (idempotent on client-provided eventId if supported by backend).
  Future<ApiResult<HistoryItem>> add({
    required String type,
    String? placeId,
    String? query,
    Map<String, dynamic>? meta,
    DateTime? at,
    String? eventId,
    CancelToken? cancelToken,
  }) async {
    final body = {
      'type': type,
      if (placeId != null) 'placeId': placeId,
      if (query != null) 'query': query,
      if (meta != null) 'meta': meta,
      'at': (at ?? DateTime.now()).toIso8601String(),
      if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
    };
    return _post<HistoryItem>(
      path: '/v1/history',
      body: body,
      parse: (data) => HistoryItem.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 0,
    ); // POST avoids aggressive retries to prevent duplicate writes; timestamps use ISO‑8601 via toIso8601String. [6]
  }

  /// Delete a single history item by id.
  Future<ApiResult<void>> delete({
    required String id,
    CancelToken? cancelToken,
  }) async {
    return _delete<void>(
      path: '/v1/history/$id',
      parse: (_) => null,
      cancelToken: cancelToken,
    ); // DELETE is idempotent and returns void on success to simplify UI handling. [3]
  }

  /// Clear a date range (inclusive) for the current user’s history.
  Future<ApiResult<int>> clearRange({
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    return _post<int>(
      path: '/v1/history/clear',
      body: {'from': from.toIso8601String(), 'to': to.toIso8601String()},
      parse: (data) {
        if (data is Map && data['deleted'] is int) return data['deleted'] as int;
        if (data is int) return data;
        return 0;
      },
      cancelToken: cancelToken,
      retries: 0,
    ); // Range boundaries are encoded using ISO‑8601 strings per Dart DateTime serialization. [6]
  }

  /// Fetch lightweight stats (counts by type and recent activity window).
  Future<ApiResult<HistoryStats>> stats({
    DateTime? from,
    DateTime? to,
    CancelToken? cancelToken,
  }) async {
    final q = <String, dynamic>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    return _get<HistoryStats>(
      path: '/v1/history/stats',
      query: q,
      parse: (data) => HistoryStats.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 1,
    ); // Stats endpoint uses GET with small retry and cancellability for responsive dashboards. [1][3]
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
    ); // CancelToken allows aborting in-flight GETs when the user navigates away or updates filters. [1]
  }

  Future<ApiResult<T>> _post<T>({
    required String path,
    required Map<String, dynamic>? body,
    required T Function(dynamic data) parse,
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
  } // Simple exponential backoff with jitter to space out retries for transient failures. [7][18]

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

class HistoryItem {
  HistoryItem({
    required this.id,
    required this.type,
    required this.at,
    this.placeId,
    this.query,
    this.meta = const {},
  });

  final String id;
  final String type; // viewed | searched | booked | shared | custom
  final DateTime at;
  final String? placeId;
  final String? query;
  final Map<String, dynamic> meta;

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: (json['id'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      at: DateTime.parse(json['at'] as String),
      placeId: json['placeId'] as String?,
      query: json['query'] as String?,
      meta: (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
    ); // DateTime.parse allows round‑tripping toIso8601String created by Dart DateTime. [17][6]
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'at': at.toIso8601String(),
        'placeId': placeId,
        'query': query,
        'meta': meta,
      }; // Timestamps serialized in ISO‑8601 extended format for JSON APIs. [6]
}

class HistoryPage {
  HistoryPage({required this.items, required this.page, required this.limit, required this.total});
  final List<HistoryItem> items;
  final int page;
  final int limit;
  final int total;

  factory HistoryPage.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List?) ?? const [];
    return HistoryPage(
      items: list.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>)).toList(growable: false),
      page: (json['page'] ?? 1) as int,
      limit: (json['limit'] ?? list.length) as int,
      total: (json['total'] ?? list.length) as int,
    );
  }
}

class HistoryStats {
  HistoryStats({
    required this.total,
    required this.byType,
    this.from,
    this.to,
  });

  final int total;
  final Map<String, int> byType;
  final DateTime? from;
  final DateTime? to;

  factory HistoryStats.fromJson(Map<String, dynamic> json) {
    return HistoryStats(
      total: (json['total'] ?? 0) as int,
      byType: ((json['byType'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), (v ?? 0) as int)),
      from: json['from'] != null ? DateTime.parse(json['from'] as String) : null,
      to: json['to'] != null ? DateTime.parse(json['to'] as String) : null,
    );
  }
}
