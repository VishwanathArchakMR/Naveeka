// lib/features/quick_actions/data/planning_api.dart

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

/// Client configuration
class PlanningApiConfig {
  const PlanningApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 25),
    this.sendTimeout = const Duration(seconds: 25),
    this.defaultHeaders = const {'Accept': 'application/json', 'Content-Type': 'application/json'},
  });
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final Map<String, String> defaultHeaders;
}

/// Planning API (itineraries) built on Dio with CancelToken support.
class PlanningApi {
  PlanningApi({Dio? dio, PlanningApiConfig? config, String? authToken})
      : _config = config ?? const PlanningApiConfig(baseUrl: ''),
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
  final PlanningApiConfig _config;

  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // ----------------------------
  // Plans (Itineraries)
  // ----------------------------

  Future<ApiResult<PlanPage>> listPlans({
    int page = 1,
    int limit = 20,
    String? q,
    CancelToken? cancelToken,
  }) async {
    final query = {
      'page': page,
      'limit': limit,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };
    return _get<PlanPage>(
      path: '/v1/plans',
      query: query,
      parse: (d) => PlanPage.fromJson(_asMap(d)),
      cancelToken: cancelToken,
      retries: 2,
    );
  }

  Future<ApiResult<Plan>> getPlan({
    required String planId,
    CancelToken? cancelToken,
  }) async {
    return _get<Plan>(
      path: '/v1/plans/$planId',
      parse: (d) => Plan.fromJson(_asMap(d)),
      cancelToken: cancelToken,
      retries: 1,
    );
  }

  Future<ApiResult<Plan>> createPlan({
    required String title,
    DateTime? startDate,
    DateTime? endDate,
    String? destination, // city/region/country
    List<String> collaboratorIds = const [],
    CancelToken? cancelToken,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      if (destination != null && destination.trim().isNotEmpty) 'destination': destination.trim(),
      if (collaboratorIds.isNotEmpty) 'collaborators': collaboratorIds,
    };
    return _post<Plan>(
      path: '/v1/plans',
      body: body,
      parse: (d) => Plan.fromJson(_asMap(d)),
      cancelToken: cancelToken,
      retries: 1,
    );
  }

  // ----------------------------
  // Internal HTTP helpers
  // ----------------------------

  Future<ApiResult<T>> _get<T>({
    required String path,
    Map<String, dynamic>? query,
    required T Function(dynamic data) parse,
    CancelToken? cancelToken,
    int retries = 0,
  }) async {
    return _requestWithRetry<T>(
      call: () => _dio.get(path, queryParameters: query, cancelToken: cancelToken),
      parse: parse,
      retries: retries,
    );
  }

  Future<ApiResult<T>> _post<T>({
    required String path,
    Map<String, dynamic>? body,
    required T Function(dynamic data) parse,
    CancelToken? cancelToken,
    int retries = 0,
  }) async {
    return _requestWithRetry<T>(
      call: () => _dio.post(path, data: body, cancelToken: cancelToken),
      parse: parse,
      retries: retries,
    );
  }

  Future<ApiResult<T>> _requestWithRetry<T>({
    required Future<Response> Function() call,
    required T Function(dynamic data) parse,
    int retries = 0,
  }) async {
    int attempts = 0;
    while (true) {
      attempts += 1;
      try {
        final resp = await call();
        final data = resp.data;
        // Many APIs wrap payloads; pass raw to parser that can unwrap.
        final parsed = parse(data);
        return ApiSuccess<T>(parsed);
      } on DioException catch (e) {
        // If retryable (e.g., network/transient), retry up to retries.
        final isCancel = CancelToken.isCancel(e);
        final status = e.response?.statusCode;
        final transient = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError ||
            (status != null && status >= 500 && status < 600);
        if (!isCancel && transient && attempts <= (retries + 1)) {
          // retry
          continue;
        }
        final message = e.message ?? 'Network error';
        final details = _safeDetails(e.response?.data);
        return ApiFailure<T>(ApiError(message: message, code: status, details: details));
      } catch (e) {
        return ApiFailure<T>(ApiError(message: 'Unexpected error: $e'));
      }
    }
  }

  Map<String, dynamic>? _safeDetails(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final m = json.decode(data);
        if (m is Map<String, dynamic>) return m;
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is String) {
      try {
        final m = json.decode(v);
        if (m is Map<String, dynamic>) return m;
      } catch (_) {}
    }
    return <String, dynamic>{};
  }
}

// ------------------------------------
// Models
// ------------------------------------

class Plan {
  Plan({
    required this.id,
    required this.title,
    this.startDate,
    this.endDate,
    this.destination,
    this.collaborators = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? destination;
  final List<String> collaborators;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Plan.fromJson(Map<String, dynamic> m) {
    // Unwrap common API shapes: {data: {...}}
    final root = (m['data'] is Map) ? Map<String, dynamic>.from(m['data']) : m;
    String s(dynamic x) => x?.toString() ?? '';
    DateTime? dt(dynamic x) {
      if (x is DateTime) return x;
      if (x is String && x.isNotEmpty) return DateTime.tryParse(x);
      return null;
    }

    List<String> strList(dynamic x) {
      if (x is List) {
        return x.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList(growable: false);
      }
      return const <String>[];
    }

    return Plan(
      id: s(root['id'] ?? root['_id'] ?? root['planId']),
      title: s(root['title']),
      startDate: dt(root['startDate']),
      endDate: dt(root['endDate']),
      destination: root['destination']?.toString(),
      collaborators: strList(root['collaborators'] ?? root['collaboratorIds']),
      createdAt: dt(root['createdAt']),
      updatedAt: dt(root['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (destination != null) 'destination': destination,
        'collaborators': collaborators,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}

class PlanPage {
  PlanPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<Plan> items;
  final int page;
  final int limit;
  final int total;

  factory PlanPage.fromJson(Map<String, dynamic> m) {
    // Accept shapes:
    // { data: { items:[...], page, limit, total } }
    // { results:[...], page, limit, total }
    // { items:[...], meta:{page,limit,total} }
    Map<String, dynamic> root = m;
    if (m['data'] is Map) {
      root = Map<String, dynamic>.from(m['data']);
    }
    List<dynamic> list =
        (root['items'] as List?) ?? (root['results'] as List?) ?? (m['results'] as List?) ?? (m['data'] as List?) ?? const [];

    List<Plan> items = list.map((e) => Plan.fromJson(PlanningApi._asMap(e))).toList(growable: false);

    int pickInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final meta = (root['meta'] is Map) ? Map<String, dynamic>.from(root['meta']) : <String, dynamic>{};
    final page = pickInt(root['page'] ?? meta['page'] ?? 1);
    final limit = pickInt(root['limit'] ?? meta['limit'] ?? 20);
    final total = pickInt(root['total'] ?? meta['total'] ?? items.length);

    return PlanPage(items: items, page: page, limit: limit, total: total);
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(growable: false),
        'page': page,
        'limit': limit,
        'total': total,
      };
}
