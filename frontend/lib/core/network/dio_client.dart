// lib/core/network/dio_client.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../errors/error_mapper.dart';
import '../storage/token_storage.dart';

/// Centralized Dio HTTP client for the app with JWT, error mapping, and diagnostics. [1]
class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();

  late final Dio dio;

  /// Single-flight unauthorized handling guard. [1]
  Future<void>? _logoutHook;

  /// Initialize Dio with base URL, timeouts, headers, and interceptors. [1]
  Future<void> init() async {
    final baseUrl = AppConfig.current.apiBaseUrl; // from flavors / dart-define [2]

    if (baseUrl.isEmpty && kDebugMode) {
      debugPrint(
        '❗ apiBaseUrl is empty. Verify AppConfig.configure(fromEnv/.env) ran before Dio init.',
      );
    }

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: <String, Object>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Helpful diagnostics headers
          'X-App-Version': AppConfig.current.appVersion,
          'X-Build-Number': AppConfig.current.buildNumber,
          'X-Env': AppConfig.current.env.name,
        },
      ),
    );

    // JWT + error mapping interceptor. [1]
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await TokenStorage.read();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {
            // ignore storage read errors
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          handler.next(response);
        },
        onError: (e, handler) async {
          // Map DioException -> AppException for consistent handling. [1]
          final appErr = ErrorMapper.map(e, e.stackTrace);

          // Handle Unauthorized globally (avoid loops for auth endpoints). [1]
          final status = e.response?.statusCode;
          if (status == 401) {
            final path = e.requestOptions.path.toLowerCase();
            final isAuthPath = path.contains('/auth') ||
                path.contains('/login') ||
                path.contains('/logout') ||
                path.contains('/refresh');
            if (!isAuthPath) {
              _logoutHook ??= _handleUnauthorized();
              try {
                await _logoutHook;
              } finally {
                _logoutHook = null;
              }
            }
          }

          // Reject with the same DioException but attach the normalized error. [1]
          handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              type: e.type,
              error: appErr,
              stackTrace: e.stackTrace,
            ),
          );
        },
      ),
    );

    // Debug logging only (headers+body on request, slim on response). [1]
    if (kDebugMode) {
      dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: false,
          compact: true,
        ),
      );
    }
  }

  /// Optional: quick connectivity sanity check during development (non-fatal). [1]
  Future<void> debugHealthPing() async {
    try {
      final res = await dio.get('/health');
      if (kDebugMode) debugPrint('✅ Health: ${res.data}');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Health ping failed: $e');
        debugPrint(
          'Checklist: backend up, correct API base URL for platform, emulator/device network access.',
        );
      }
    }
  }

  /// Clear tokens and let the app’s auth flow react (no BuildContext coupling here). [1]
  Future<void> _handleUnauthorized() async {
    try {
      await TokenStorage.clear();
      // If there is a global router/auth notifier, trigger it here without bringing
      // UI dependencies into networking (kept intentional to avoid tight coupling). [1]
    } catch (_) {
      // ignore
    }
  }
}
