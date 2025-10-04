// lib/features/auth/data/auth_api.dart

import 'package:dio/dio.dart';

import '../../../core/config/constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/storage/token_storage.dart';

/// Authentication API wrapper (Authorization header is auto-injected by Dio). [2]
class AuthApi {
  AuthApi() : _dio = DioClient.instance.dio;

  final Dio _dio;

  /// POST /api/auth/register -> returns created user + tokens (if backend provides). [2]
  Future<ApiResult<Map<String, dynamic>>> register(
    Map<String, dynamic> payload,
  ) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post(AppConstants.endpointRegister, data: payload);
      final map = Map<String, dynamic>.from(res.data as Map);
      await _maybePersistTokens(map); // store tokens if present [6]
      return map;
    });
  }

  /// POST /api/auth/login -> { data: { user, accessToken?, refreshToken?, expiresAt? } } [2]
  Future<ApiResult<Map<String, dynamic>>> login(
    String email,
    String password,
  ) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post(AppConstants.endpointLogin, data: {
        'email': email,
        'password': password,
      });
      final map = Map<String, dynamic>.from(res.data as Map);
      await _maybePersistTokens(map); // secure storage / prefs web [21][22]
      return map;
    });
  }

  /// GET /api/auth/me -> current user profile (requires Authorization). [2]
  Future<ApiResult<Map<String, dynamic>>> me() {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get(AppConstants.endpointMe);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// PUT /api/auth/profile -> update user fields. [2]
  Future<ApiResult<Map<String, dynamic>>> updateProfile(
    Map<String, dynamic> payload,
  ) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.put(AppConstants.endpointProfile, data: payload);
      final map = Map<String, dynamic>.from(res.data as Map);
      // Some backends rotate tokens on profile change; persist if present.
      await _maybePersistTokens(map); // optional [3]
      return map;
    });
  }

  /// PUT /api/auth/password -> change password; backend may rotate tokens. [2]
  Future<ApiResult<Map<String, dynamic>>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.put(AppConstants.endpointPassword, data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      final map = Map<String, dynamic>.from(res.data as Map);
      await _maybePersistTokens(map); // optional [8]
      return map;
    });
  }

  // ------------- Internals -------------

  /// Extract tokens from typical response shapes and persist securely. [21][22]
  Future<void> _maybePersistTokens(Map<String, dynamic> response) async {
    // Common shapes:
    // 1) { data: { accessToken, refreshToken?, expiresAt? } }
    // 2) { token: '...' }
    // 3) { data: { token: '...' } }
    DateTime? expiresAt;

    String? access =
        _asString(response['accessToken']) ?? _asString(response['token']);
    String? refresh = _asString(response['refreshToken']);

    if (response['data'] is Map) {
      final data = Map<String, dynamic>.from(response['data'] as Map);
      access = _asString(access) ??
          _asString(data['accessToken']) ??
          _asString(data['token']);
      refresh = _asString(refresh) ?? _asString(data['refreshToken']);
      final expRaw = data['expiresAt'];
      if (expRaw is String) {
        expiresAt = DateTime.tryParse(expRaw);
      } else if (expRaw is int) {
        // seconds since epoch
        expiresAt =
            DateTime.fromMillisecondsSinceEpoch(expRaw * 1000, isUtc: true);
      }
    }

    if (access != null && access.isNotEmpty) {
      await TokenStorage.save(access,
          expiresAt: expiresAt); // secure on device, prefs on web [21][22]
      if (refresh != null && refresh.isNotEmpty) {
        await TokenStorage.instance.saveTokens(
          accessToken: access,
          refreshToken: refresh,
          expiresAt: expiresAt,
        ); // refresh persistence [3]
      }
    }
  }

  String? _asString(Object? v) => v?.toString();
}
