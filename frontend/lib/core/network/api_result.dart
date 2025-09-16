// lib/core/network/api_result.dart

import '../errors/app_exception.dart';
import '../errors/error_mapper.dart';

/// A lightweight Result type for API operations that avoids try/catch at call sites. [2]
class ApiResult<T> {
  final T? data;
  final AppException? error;

  const ApiResult._({this.data, this.error});

  /// True when `data` is present and no error occurred. [2]
  bool get success => data != null && error == null;

  /// True when an error was captured. [2]
  bool get hasError => error != null;

  /// Create a successful result. [2]
  factory ApiResult.ok(T data) => ApiResult._(data: data);

  /// Create an error result. [2]
  factory ApiResult.fail(AppException error) => ApiResult._(error: error);

  /// Transform success value with `fn`; propagate error unchanged. [2]
  ApiResult<R> map<R>(R Function(T value) fn) {
    if (success) return ApiResult.ok(fn(data as T));
    return ApiResult.fail(error as AppException);
  }

  /// Fold into a single value by providing `onSuccess` and `onError`. [2]
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppException error) onError,
  }) {
    return success ? onSuccess(data as T) : onError(error as AppException);
  }

  /// Return `data` or compute fallback from the error. [2]
  T getOrElse(T Function(AppException error) orElse) {
    return success ? data as T : orElse(error as AppException);
  }

  /// Return `data` or throw the underlying AppException (use sparingly). [8]
  T getOrThrow() {
    if (success) return data as T;
    throw error as AppException;
  }

  @override
  String toString() =>
      success ? 'ApiResult.ok($data)' : 'ApiResult.fail(${error?.safeMessage})'; // [2]

  /// Execute an async function and wrap its outcome as ApiResult, mapping errors consistently. [2]
  static Future<ApiResult<R>> guardFuture<R>(Future<R> Function() func) async {
    try {
      final result = await func();
      return ApiResult.ok(result);
    } catch (err, st) {
      return ApiResult.fail(ErrorMapper.map(err, st));
    }
  }

  /// Execute a sync function and wrap as ApiResult, catching mapper-supported errors. [2]
  static ApiResult<R> guard<R>(R Function() func) {
    try {
      final result = func();
      return ApiResult.ok(result);
    } catch (err, st) {
      return ApiResult.fail(ErrorMapper.map(err, st));
    }
  }

  /// Listen to a Stream and emit ApiResult events; errors are mapped to AppException for uniform handling. [12]
  static Stream<ApiResult<R>> guardStream<R>(Stream<R> stream) async* {
    try {
      await for (final value in stream) {
        yield ApiResult.ok(value);
      }
    } catch (err, st) {
      yield ApiResult.fail(ErrorMapper.map(err, st));
    }
  }
}

