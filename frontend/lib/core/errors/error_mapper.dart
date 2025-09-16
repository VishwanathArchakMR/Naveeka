// lib/core/errors/error_mapper.dart

import 'dart:async' show TimeoutException;
import 'dart:io'
    show SocketException, HttpException, HandshakeException, TlsException;
import 'package:dio/dio.dart';

import 'app_exception.dart';

/// Converts any raw error into a clean, user-friendly AppException that
/// aligns with backend error shapes and UX messaging across the app. [dio][1]
class ErrorMapper {
  const ErrorMapper._();

  /// Primary mapping function with optional stack trace for better diagnostics. [2]
  static AppException map(Object error, [StackTrace? stackTrace]) {
    // Already normalized
    if (error is AppException) return error; // [2]

    // DioException (HTTP, timeout, cancel, etc.)
    if (error is DioException) {
      return AppException.fromDioException(error); // [1]
    }

    // Network connectivity & HTTP client layer
    if (error is SocketException || error is HttpException) {
      return AppException.network('Network connection error',
          cause: error, stackTrace: stackTrace); // [3]
    }
    if (error is TimeoutException) {
      return AppException.network('Request timed out',
          cause: error, stackTrace: stackTrace); // [3]
    }
    if (error is HandshakeException || error is TlsException) {
      return AppException(
        message: 'Secure connection failed',
        safeMessage: 'Secure connection failed',
        cause: error,
        stackTrace: stackTrace,
      ); // [3]
    }

    // Data/format issues
    if (error is FormatException) {
      return const AppException(
        message: 'Invalid data format',
        safeMessage: 'Data error. Please try again.',
      ); // [2]
    }
    if (error is StateError || error is TypeError) {
      return AppException(
        message: 'Unexpected data/state: $error',
        safeMessage: 'Something went wrong. Please try again.',
        cause: error,
        stackTrace: stackTrace,
      ); // [2]
    }

    // Fallback
    return AppException(
      message: error.toString(),
      safeMessage: 'Something went wrong. Please try again.',
      cause: error,
      stackTrace: stackTrace,
    ); // [2]
  }

  /// Convenience wrapper to map an exception within a catch block. [2]
  static AppException mapCurrent(Object error) =>
      map(error, StackTrace.current); // [2]
}
