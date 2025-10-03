// lib/main.dart
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'services/api_client.dart';
import 'core/storage/seed_data_loader.dart';

// ----------------------
// Providers (central)
// ----------------------
final apiBaseUrlProvider = Provider<String>((ref) {
  // Allow override via --dart-define=API_BASE_URL=http://host:port
  const envUrl = String.fromEnvironment('API_BASE_URL');
  if (envUrl.isNotEmpty) return envUrl;

  if (kIsWeb) return 'http://localhost:3000';
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android emulator -> host
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final base = ref.watch(apiBaseUrlProvider);
  return ApiClient(base);
});

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final prevFlutterOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        Zone.current.handleUncaughtError(
          details.exception,
          details.stack ?? StackTrace.empty,
        );
        prevFlutterOnError?.call(details);
      };

      final prevPlatformOnError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        Zone.current.handleUncaughtError(error, stack);
        return prevPlatformOnError?.call(error, stack) ?? true;
      };

      ErrorWidget.builder = (FlutterErrorDetails details) {
        return Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ThemeData.fallback().colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Something went wrong.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        );
      };

      // 1) Splash immediately
      runApp(const _SplashApp());

      // 2) Bootstrap, preload seed data, then run with DI providers available
      unawaited(
        Future<void>(() async {
          try {
            await bootstrap(); // keep existing bootstrap work
            // Ensure all seed JSON is loaded before App renders any feature screen
            await SeedDataLoader.instance.loadAllSeedData();
            runApp(
              const ProviderScope(
                child: App(),
              ),
            );
          } catch (e, st) {
            Zone.current.handleUncaughtError(e, st);
          }
        }),
      );
    },
    (Object error, StackTrace stack) {
      // ignore: avoid_print
      print('Uncaught zone error: $error\n$stack');
    },
  );
}

class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Naveeka',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF246EE9),
        brightness: Brightness.light,
      ),
      home: const _SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: theme.colorScheme.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Naveeka…',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Small helper to silence unawaited futures without importing a package.
void unawaited(Future<void> f) {}
