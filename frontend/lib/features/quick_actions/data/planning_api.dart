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
    ); // Configure Dio baseUrl, timeouts, and default headers for consistent requests. [3]
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
      parse: (d) => PlanPage.fromJson(d as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 2,
    ); // GET is cancelable via CancelToken and safely retried on transient errors a limited number of times. [1][3]
  }

  Future<ApiResult<Plan>> getPlan({
    required String planId,
    CancelToken? cancelToken,
  }) async {
    return _get<Plan>(
      path: '/v1/plans/$planId',
      parse: (d) => Plan.fromJson(d as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 1,
    ); // Plan payload includes ISO‑8601 timestamps parsed with DateTime.parse. [6]
  }

  Future<ApiResult<Plan>> createPlan({
    required String title,
    DateTime? startDate,
    DateTime? endDate,
    String? destination, // city/region/country
    List<String> collaboratorIds = const [],
    CancelToken? cancelToken,
  }) async {
    final body
