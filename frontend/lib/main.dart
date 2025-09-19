// lib/main.dart
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  // Guard the entire startup to capture uncaught async/platform errors.
  runZonedGuarded<Future<void>>(
    () async {
      // Ensure binding is ready before any async/platform work.
      WidgetsFlutterBinding.ensureInitialized();

      // Capture framework errors (build/layout/paint/callback).
      final prevFlutterOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        // Forward into the zone for unified handling/logging.
        Zone.current.handleUncaughtError(
          details.exception,
          details.stack ?? StackTrace.empty,
        );
        // Preserve any previous behavior (e.g., IDE console output).
        prevFlutterOnError?.call(details);
      };

      // Capture uncaught errors outside framework callbacks (async/platform).
      final prevPlatformOnError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        Zone.current.handleUncaughtError(error, stack);
        // Preserve previous decision or mark as handled.
        return prevPlatformOnError?.call(error, stack) ?? true;
      };

      // Minimal fallback widget for build-time errors (debug friendly).
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

      // 1) Show an immediate full-screen loading UI
      runApp(const _SplashApp());

      // 2) Do app bootstrap in the background, then swap in the real app
      //    (keeps UI responsive while heavy init runs).
      unawaited(
        Future<void>(() async {
          try {
            await bootstrap();
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
      // Replace with production logging (e.g., Crashlytics/Sentry) as needed.
      // ignore: avoid_print
      print('Uncaught zone error: $error\n$stack');
    },
  );
}

// A minimal full-screen splash/loading app shown immediately at startup.
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
