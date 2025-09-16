// lib/main.dart

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  // Guard the entire startup to capture uncaught async errors. 
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

      // Finish all startup tasks before showing UI.
      await bootstrap();

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

      // Launch the app with Riverpod at the root.
      runApp(
        const ProviderScope(
          child: App(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      // Replace with production logging (e.g., Crashlytics/Sentry) as needed.
      // ignore: avoid_print
      print('Uncaught zone error: $error\n$stack');
    },
  );
}



