// lib/app/bootstrap.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/storage/local_storage.dart';
import '../core/network/offline_manager.dart';
import '../core/utils/analytics.dart';
import '../core/network/dio_client.dart';
import '../core/storage/seed_data_loader.dart';
import '../services/location_service.dart';
import '../features/auth/providers/auth_providers.dart';

/// Runs BEFORE the App widget is built. [6]
Future<void> bootstrap() async {
  // Ensure binding is ready for plugins/platform-channels before any awaits. [6]
  WidgetsFlutterBinding.ensureInitialized(); // [6]

  // Short-lived container for startup tasks. [17]
  final container = ProviderContainer(); // not const; ProviderContainer isn't const [17]

  try {
    // 1) Environment configuration (dart-define). [18]
    AppConfig.configure(AppConfig.fromEnv()); // [18]

    // 2) Local storage. [19]
    await LocalStorage.instance.init(); // [19]

    // 3) Offline manager (connectivity + manual offline toggle). [20]
    await OfflineManager.instance.init(); // [20]
    if (AppConfig.current.offlineModeDefault) {
      await OfflineManager.instance.setOfflineMode(true); // [20]
    }

    // 4) Analytics (console in debug) with const constructors and const list literal. [1]
    Analytics.instance.configure(
      MultiAnalyticsBackend(
        const [
          ConsoleAnalyticsBackend(enabled: kDebugMode),
        ],
      ),
    ); // [1]
    Analytics.instance.setEnabled(AppConfig.current.analyticsEnabled); // [21]
    await Analytics.instance.init(); // [21]

    // 5) Seed data warm-up. [20]
    await SeedDataLoader.instance.loadAllSeedData(); // [20]

    // 6) Location service. [22]
    await LocationService.instance.init(); // [22]

    // 7) HTTP client. [23]
    await DioClient.instance.init(); // [23]

    // 8) Restore auth session. [17]
    await container.read(authStateProvider.notifier).loadMe(); // [17]

    // 9) Optional health ping (log-only). [24]
    try {
      final res = await DioClient.instance.dio.get('/health'); // [24]
      if (kDebugMode) {
        debugPrint('✅ Backend health: ${res.data}'); // [24]
      }
    } catch (e) {
      if (kDebugMode) {
        final platformName = kIsWeb
            ? 'Web'
            : Platform.isAndroid
                ? 'Android'
                : Platform.isIOS
                    ? 'iOS'
                    : Platform.operatingSystem; // [10]
        debugPrint('⚠️ Health check failed: $e'); // [24]
        debugPrint(
          'Checklist:\n'
          '1) Backend running\n'
          '2) API_BASE_URL matches platform ($platformName)\n'
          '3) Android INTERNET permission in AndroidManifest.xml\n'
          '4) Real device uses LAN IP (e.g., http://192.168.x.x:3000)', // [24]
        );
      }
    }

    // 10) Debug echo of env. [18]
    if (kDebugMode) {
      final cfg = AppConfig.current; // [18]
      debugPrint('🔧 AppConfig: env=${cfg.env}, api=${cfg.apiBaseUrl}'); // [18]
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('❌ Bootstrap error: $e'); // [12]
      debugPrint('$st'); // [12]
    }
    rethrow; // [7]
  } finally {
    container.dispose(); // [17]
  }
}
