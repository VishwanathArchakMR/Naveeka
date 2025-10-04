// lib/core/errors/error_mapper.dart

import 'dart:async' show TimeoutException;
import 'dart:io'
    show SocketException, HttpException, HandshakeException, TlsException;
import 'package:dio/dio.dart';

import 'app_exception.dart';

/// Converts any raw error into a clean, user-friendly AppException that
/// aligns with backend error shapes and UX messaging across the app.
class ErrorMapper {
  const ErrorMapper._();

  /// Primary mapping function with optional stack trace for better diagnostics.
  static AppException map(Object error, [StackTrace? stackTrace]) {
    // Already normalized
    if (error is AppException) return error;

    // DioException (HTTP, timeout, cancel, etc.)
    if (error is DioException) {
      return AppException.fromDioException(error);
    }

    // Network connectivity & HTTP client layer
    if (error is SocketException || error is HttpException) {
      // FIX: use positional args (message, cause, stackTrace)
      return AppException.network(
          'Network connection error', error, stackTrace);
    }
    if (error is TimeoutException) {
      // FIX: use positional args (message, cause, stackTrace)
      return AppException.network('Request timed out', error, stackTrace);
    }
    if (error is HandshakeException || error is TlsException) {
      return AppException(
        message: 'Secure connection failed',
        safeMessage: 'Secure connection failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    // Data/format issues
    if (error is FormatException) {
      return const AppException(
        message: 'Invalid data format',
        safeMessage: 'Data error. Please try again.',
      );
    }
    if (error is StateError || error is TypeError) {
      return AppException(
        message: 'Unexpected data/state: $error',
        safeMessage: 'Something went wrong. Please try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    // Fallback
    return AppException(
      message: error.toString(),
      safeMessage: 'Something went wrong. Please try again.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Convenience wrapper to map an exception within a catch block.
  static AppException mapCurrent(Object error) =>
      map(error, StackTrace.current);
}
