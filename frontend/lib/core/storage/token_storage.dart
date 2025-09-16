// lib/core/storage/token_storage.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage helper for saving and retrieving auth tokens.
/// - Mobile/Desktop: flutter_secure_storage (Keychain/Keystore/EncryptedSharedPreferences) [1]
/// - Web: SharedPreferences fallback (no secure storage on web) [15]
class TokenStorage {
  // Keys (namespaced to reduce collision risk)
  static const String _kPrefix = 'naveeka_auth';
  static const String _kAccessToken = '$_kPrefix.access_token';
  static const String _kRefreshToken = '$_kPrefix.refresh_token';
  static const String _kExpiry = '$_kPrefix.expires_at'; // ISO8601

  // Singleton
  TokenStorage._internal();
  static final TokenStorage instance = TokenStorage._internal();

  // Secure storage instance with platform-specific options. [1]
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Auth change events (login/logout/refresh)
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  Stream<bool> get changes => _changes.stream;

  // ------------- Static convenience API -------------

  static Future<void> save(String token, {DateTime? expiresAt}) =>
      instance._setAccessToken(token, expiresAt: expiresAt);

  static Future<String?> read() => instance.getAccessToken();

  static Future<void> clear() => instance.clearTokens();

  // ------------- Instance API -------------

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    await _setAccessToken(accessToken, expiresAt: expiresAt);
    if (refreshToken != null) {
      await _setRefreshToken(refreshToken);
    }
  }

  Future<String?> getAccessToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kAccessToken);
    }
    return _secure.read(key: _kAccessToken);
  }

  Future<String?> getRefreshToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kRefreshToken);
    }
    return _secure.read(key: _kRefreshToken);
  }

  Future<DateTime?> getExpiry() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString(_kExpiry);
      return iso == null ? null : DateTime.tryParse(iso);
    }
    final iso = await _secure.read(key: _kExpiry);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<bool> hasAccessToken() async {
    final t = await getAccessToken();
    return t != null && t.isNotEmpty;
  }

  Future<void> clearTokens() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessToken);
      await prefs.remove(_kRefreshToken);
      await prefs.remove(_kExpiry);
    } else {
      await _secure.delete(key: _kAccessToken);
      await _secure.delete(key: _kRefreshToken);
      await _secure.delete(key: _kExpiry);
    }
    _emit(false);
  }

  // ------------- Internals -------------

  Future<void> _setAccessToken(String token, {DateTime? expiresAt}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccessToken, token);
      if (expiresAt != null) {
        await prefs.setString(_kExpiry, expiresAt.toIso8601String());
      }
    } else {
      await _secure.write(key: _kAccessToken, value: token);
      if (expiresAt != null) {
        await _secure.write(key: _kExpiry, value: expiresAt.toIso8601String());
      }
    }
    _emit(true);
  }

  Future<void> _setRefreshToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRefreshToken, token);
    } else {
      await _secure.write(key: _kRefreshToken, value: token);
    }
  }

  void _emit(bool loggedIn) {
    if (_changes.hasListener) {
      _changes.add(loggedIn);
    }
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
