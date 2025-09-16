// lib/core/errors/app_exception.dart

import 'package:dio/dio.dart';

/// A unified application exception carrying a user-safe message, an optional
/// HTTP status code, raw details, and the originating cause when available. [2]
class AppException implements Exception {
  final String message;           // developer/log-friendly message
  final String safeMessage;       // user-facing message for UI
  final int? statusCode;          // HTTP status (if any)
  final dynamic details;          // backend-provided error payload
  final Object? cause;            // original exception
  final StackTrace? stackTrace;   // capture for debugging

  const AppException({
    required this.message,
    String? safeMessage,
    this.statusCode,
    this.details,
    this.cause,
    this.stackTrace,
  }) : safeMessage = safeMessage ?? message;

  @override
  String toString() => 'AppException($statusCode): $message';

  /// Create from a backend JSON error body (e.g., { message, details }). [9]
  factory AppException.fromJson(
    Map<String, dynamic> json, {
    int? status,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    final msg = json['message']?.toString() ?? 'Unknown error occurred';
    return AppException(
      message: msg,
      safeMessage: _safeByStatus(status, fallback: msg),
      statusCode: status,
      details: json['details'],
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  /// Map a DioException to AppException with HTTP status and safe message. [2]
  factory AppException.fromDioException(DioException e) {
    final res = e.response;
    final status = res?.statusCode;

    // Try to parse backend error JSON first
    if (res?.data is Map<String, dynamic>) {
      final map = res!.data as Map<String, dynamic>;
      return AppException.fromJson(
        map,
        status: status,
        cause: e,
        stackTrace: e.stackTrace,
      );
    }

    // Fallback to type/status-based mapping
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException.network('Request timed out',
            cause: e, stackTrace: e.stackTrace);
      case DioExceptionType.badResponse:
        return AppException(
          message: 'HTTP $status',
          safeMessage: _safeByStatus(status, fallback: 'Request failed'),
          statusCode: status,
          details: res?.data,
          cause: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.cancel:
        return AppException(
          message: 'Request cancelled',
          safeMessage: 'Request cancelled',
          cause: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.badCertificate:
        return AppException(
          message: 'Bad certificate',
          safeMessage: 'Secure connection failed',
          cause: e,
          stackTrace: e.stackTrace,
        );
      case DioExceptionType.connectionError:
        return AppException.network('Network connection error',
            cause: e, stackTrace: e.stackTrace);
      case DioExceptionType.unknown:
        return AppException(
          message: e.message ?? 'Unknown network error',
          safeMessage: 'Something went wrong. Please try again.',
          cause: e,
          stackTrace: e.stackTrace,
        );
    }
  }

  /// Common client-side factories
  factory AppException.network([String? msg, Object? cause, StackTrace? stackTrace]) =>
      AppException(
        message: msg ?? 'Network error',
        safeMessage: 'Network error. Check your connection.',
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.unauthorized([String? msg, Object? cause, StackTrace? stackTrace]) =>
      AppException(
        message: msg ?? 'Unauthorized',
        safeMessage: 'Unauthorized. Please log in again.',
        statusCode: 401,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.forbidden([String? msg, Object? cause, StackTrace? stackTrace]) =>
      AppException(
        message: msg ?? 'Forbidden',
        safeMessage: 'Access denied.',
        statusCode: 403,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.notFound([String? msg, Object? cause, StackTrace? stackTrace]) =>
      AppException(
        message: msg ?? 'Not found',
        safeMessage: 'Resource not found.',
        statusCode: 404,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.server([String? msg, Object? cause, StackTrace? stackTrace]) =>
      AppException(
        message: msg ?? 'Server error',
        safeMessage: 'Server error. Please try again later.',
        statusCode: 500,
        cause: cause,
        stackTrace: stackTrace,
      );

  AppException copyWith({
    String? message,
    String? safeMessage,
    int? statusCode,
    dynamic details,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppException(
      message: message ?? this.message,
      safeMessage: safeMessage ?? this.safeMessage,
      statusCode: statusCode ?? this.statusCode,
      details: details ?? this.details,
      cause: cause ?? this.cause,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  static String _safeByStatus(int? status, {required String fallback}) {
    // Provide user-safe defaults for common HTTP statuses. [6][9]
    switch (status) {
      case 400:
        return 'Invalid request. Please verify and try again.';
      case 401:
        return 'Unauthorized. Please log in again.';
      case 403:
        return 'Access denied.';
      case 404:
        return 'Resource not found.';
      case 408:
        return 'Request timed out. Please try again.';
      case 409:
        return 'Conflict detected. Please refresh and try again.';
      case 422:
        return 'Request could not be processed.';
      case 429:
        return 'Too many requests. Please wait a moment.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
      case 503:
      case 504:
        return 'Service unavailable. Please try again shortly.';
      default:
        return fallback;
    }
  }
}
