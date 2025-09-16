// lib/core/config/app_config.dart

import 'package:flutter/foundation.dart';

/// Supported environments/flavors
enum AppEnv { dev, staging, prod }

/// Central app configuration: base URLs, feature flags, and service keys.
/// Values can be supplied via --dart-define or defaulted per flavor.
class AppConfig {
  final AppEnv env;

  // Networking
  final String apiBaseUrl;
  final String cdnBaseUrl;

  // Feature flags
  final bool analyticsEnabled;
  final bool crashReportingEnabled;
  final bool offlineModeDefault;

  // Map/Geo/External keys (do not commit secrets; use dart-define or remote config)
  final String mapsApiKey;
  final String sentryDsn;

  // Build/meta
  final String appVersion;
  final String buildNumber;

  const AppConfig({
    required this.env,
    required this.apiBaseUrl,
    required this.cdnBaseUrl,
    required this.analyticsEnabled,
    required this.crashReportingEnabled,
    required this.offlineModeDefault,
    required this.mapsApiKey,
    required this.sentryDsn,
    required this.appVersion,
    required this.buildNumber,
  });

  AppConfig copyWith({
    AppEnv? env,
    String? apiBaseUrl,
    String? cdnBaseUrl,
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
    bool? offlineModeDefault,
    String? mapsApiKey,
    String? sentryDsn,
    String? appVersion,
    String? buildNumber,
  }) {
    return AppConfig(
      env: env ?? this.env,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      cdnBaseUrl: cdnBaseUrl ?? this.cdnBaseUrl,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReportingEnabled: crashReportingEnabled ?? this.crashReportingEnabled,
      offlineModeDefault: offlineModeDefault ?? this.offlineModeDefault,
      mapsApiKey: mapsApiKey ?? this.mapsApiKey,
      sentryDsn: sentryDsn ?? this.sentryDsn,
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
    );
  }

  // ---------------- Global access (configured at bootstrap) ----------------

  static AppConfig? _current;
  static AppConfig get current {
    final cfg = _current;
    assert(cfg != null, 'AppConfig.configure() must be called during bootstrap.');
    return cfg!;
  }

  static void configure(AppConfig config) {
    _current = config;
  }

  // ---------------- Constructors from dart-define ----------------

  /// Build from dart-define using const fromEnvironment for AOT platforms.
  /// Keys: APP_ENV, API_BASE_URL, CDN_BASE_URL, ANALYTICS_ENABLED, CRASH_ENABLED, OFFLINE_DEFAULT,
  /// MAPS_API_KEY, SENTRY_DSN, APP_VERSION, BUILD_NUMBER.
  static AppConfig fromEnv() {
    // Read env string at compile time where provided
    const envStr = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    final env = _parseEnv(envStr);

    // Read base URLs from environment (const), then apply runtime fallback if empty
    const apiBaseFromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final apiBaseUrl =
        apiBaseFromEnv.isNotEmpty ? apiBaseFromEnv : _defaultApiBaseUrlFor(env);

    const cdnBaseFromEnv = String.fromEnvironment('CDN_BASE_URL', defaultValue: '');
    final cdnBaseUrl =
        cdnBaseFromEnv.isNotEmpty ? cdnBaseFromEnv : _defaultCdnBaseUrlFor(env);

    // Flags (const reads from environment)
    const analyticsEnabledConst =
        bool.fromEnvironment('ANALYTICS_ENABLED', defaultValue: !kDebugMode);
    const crashEnabledConst =
        bool.fromEnvironment('CRASH_ENABLED', defaultValue: !kDebugMode);
    const offlineDefaultConst =
        bool.fromEnvironment('OFFLINE_DEFAULT', defaultValue: false);

    // Keys (empty default means "feature off" until set)
    const mapsKey = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
    const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

    // Version metadata (optionally injected via CI)
    const appVer = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.1');
    const buildNum = String.fromEnvironment('BUILD_NUMBER', defaultValue: '1');

    return AppConfig(
      env: env,
      apiBaseUrl: apiBaseUrl,
      cdnBaseUrl: cdnBaseUrl,
      analyticsEnabled: analyticsEnabledConst,
      crashReportingEnabled: crashEnabledConst,
      offlineModeDefault: offlineDefaultConst,
      mapsApiKey: mapsKey,
      sentryDsn: sentryDsn,
      appVersion: appVer,
      buildNumber: buildNum,
    );
  }

  /// Convenience factories per flavor with opinionated defaults.
  static AppConfig dev() => const AppConfig(
        env: AppEnv.dev,
        apiBaseUrl: 'https://api.dev.example.com',
        cdnBaseUrl: 'https://cdn.dev.example.com',
        analyticsEnabled: false,
        crashReportingEnabled: false,
        offlineModeDefault: false,
        mapsApiKey: '',
        sentryDsn: '',
        appVersion: '0.0.1',
        buildNumber: '1',
      );

  static AppConfig staging() => const AppConfig(
        env: AppEnv.staging,
        apiBaseUrl: 'https://api.staging.example.com',
        cdnBaseUrl: 'https://cdn.staging.example.com',
        analyticsEnabled: true,
        crashReportingEnabled: true,
        offlineModeDefault: false,
        mapsApiKey: '',
        sentryDsn: '',
        appVersion: '0.0.1',
        buildNumber: '1',
      );

  static AppConfig prod() => const AppConfig(
        env: AppEnv.prod,
        apiBaseUrl: 'https://api.example.com',
        cdnBaseUrl: 'https://cdn.example.com',
        analyticsEnabled: true,
        crashReportingEnabled: true,
        offlineModeDefault: false,
        mapsApiKey: '',
        sentryDsn: '',
        appVersion: '0.0.1',
        buildNumber: '1',
      );

  // ---------------- Helpers ----------------

  static AppEnv _parseEnv(String s) {
    switch (s.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnv.prod;
      case 'stg':
      case 'stage':
      case 'staging':
        return AppEnv.staging;
      case 'dev':
      default:
        return AppEnv.dev;
    }
  }

  static String _defaultApiBaseUrlFor(AppEnv env) {
    switch (env) {
      case AppEnv.dev:
        return 'https://api.dev.example.com';
      case AppEnv.staging:
        return 'https://api.staging.example.com';
      case AppEnv.prod:
        return 'https://api.example.com';
    }
  }

  static String _defaultCdnBaseUrlFor(AppEnv env) {
    switch (env) {
      case AppEnv.dev:
        return 'https://cdn.dev.example.com';
      case AppEnv.staging:
        return 'https://cdn.staging.example.com';
      case AppEnv.prod:
        return 'https://cdn.example.com';
    }
  }

  bool get isDev => env == AppEnv.dev;
  bool get isStaging => env == AppEnv.staging;
  bool get isProd => env == AppEnv.prod;
}
