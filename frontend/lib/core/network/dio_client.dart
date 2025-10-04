// lib/core/network/dio_client.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../errors/error_mapper.dart';
import '../storage/token_storage.dart';

/// Centralized Dio HTTP client for the app with JWT, error mapping, and diagnostics.
class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();

  late final Dio dio;

  /// Single-flight unauthorized handling guard.
  Future<void>? _logoutHook;

  /// Initialize Dio with base URL, timeouts, headers, and interceptors.
  Future<void> init() async {
    final configured = AppConfig.current.apiBaseUrl.trim();
    final baseUrl = configured.isNotEmpty ? configured : _fallbackBaseUrl();

    if (baseUrl.isEmpty && kDebugMode) {
      debugPrint('❗ apiBaseUrl is empty. Ensure AppConfig.configure ran before Dio init.');
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
          'X-App-Version': AppConfig.current.appVersion,
          'X-Build-Number': AppConfig.current.buildNumber,
          'X-Env': AppConfig.current.env.name,
        },
      ),
    );

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
        onResponse: (response, handler) => handler.next(response),
        onError: (e, handler) async {
          final appErr = ErrorMapper.map(e, e.stackTrace);

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

  Future<void> debugHealthPing() async {
    try {
      final res = await dio.get('/health');
      if (kDebugMode) debugPrint('✅ Health: ${res.data}');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Health ping failed: $e');
        debugPrint('Checklist: backend up, correct API base URL, browser CORS allowed (web).');
      }
    }
  }

  Future<void> _handleUnauthorized() async {
    try {
      await TokenStorage.clear();
    } catch (_) {
      // ignore
    }
  }

  String _fallbackBaseUrl() {
    if (kIsWeb) return 'http://localhost:3000';
    return 'http://10.0.2.2:3000';
  }
}
