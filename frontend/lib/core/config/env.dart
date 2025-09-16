// lib/core/config/env.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_config.dart';

/// Compatibility facade for legacy code that still references `Env.*`.
/// New code should use AppConfig.current directly. This loader:
/// - Reads compile-time values via AppConfig.fromEnv() (--dart-define) [preferred].
/// - Optionally overlays values from .env at runtime if present. [1]
/// - Mirrors a subset of fields for backward compatibility. [9]
class Env {
  // Back-compat fields (read-only mirrors of AppConfig.current)
  static late String apiBaseUrl;
  static late String appName;
  static late String googleMapsApiKey; // optional
  static late String assetsBaseUrl; // optional

  /// Load configuration. Safe to call multiple times (idempotent).
  /// Order:
  /// 1) AppConfig.fromEnv() for compile-time values. [9][6]
  /// 2) dotenv.load() to overlay runtime values if .env exists. [1]
  /// 3) AppConfig.configure(merged) and mirror fields for legacy access.
  static Future<void> load() async {
    // Step 1: base from dart-define/flavor
    var cfg = AppConfig.fromEnv(); // compile-time [9]

    // Step 2: overlay from .env if available
    try {
      // Will throw if file missing; ignore silently in release flows.
      await dotenv.load(fileName: '.env'); // runtime overlay [1]
      // Read known keys (use existing cfg values when absent)
      final envApi = (dotenv.env['API_BASE_URL'] ?? '').trim();
      final envAppName = (dotenv.env['APP_NAME'] ?? '').trim();
      final envMaps = (dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '').trim();
      final envAssets = (dotenv.env['ASSETS_BASE_URL'] ?? '').trim();

      // Build merged config
      cfg = cfg.copyWith(
        apiBaseUrl: envApi.isNotEmpty ? envApi : cfg.apiBaseUrl,
        // appName is not part of AppConfig; keep separate mirror below if required.
      );

      // Configure globally
      AppConfig.configure(cfg);
      // Step 3: mirror for legacy access
      apiBaseUrl = AppConfig.current.apiBaseUrl;
      appName = envAppName.isNotEmpty ? envAppName : 'Naveeka';
      googleMapsApiKey = envMaps;
      assetsBaseUrl = envAssets.isNotEmpty ? envAssets : apiBaseUrl;
    } catch (_) {
      // No .env at runtime: fall back to cfg and platform default for appName/assets
      AppConfig.configure(cfg);
      apiBaseUrl = AppConfig.current.apiBaseUrl;
      appName = 'Naveeka';
      googleMapsApiKey = '';
      assetsBaseUrl = _defaultAssetsBaseUrl();
    }
  }

  // Android emulator requires 10.0.2.2 to reach the host; web/iOS can use localhost.
  static String _defaultAssetsBaseUrl() {
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }
}
