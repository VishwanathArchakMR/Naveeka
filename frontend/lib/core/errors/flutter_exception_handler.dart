// lib/core/errors/flutter_exception_handler.dart

import 'package:flutter/foundation.dart';

/// Custom exception handler for Flutter errors
class FlutterExceptionHandler {
  static void handleError(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      print('Flutter Error: $error');
      print('Stack Trace: $stackTrace');
    }
    
    // In production, you might want to send this to a crash reporting service
    // like Firebase Crashlytics, Sentry, etc.
  }
}

/// Platform dispatcher error callback
typedef PlatformDispatcherErrorCallback = void Function(Object error, StackTrace stackTrace);

