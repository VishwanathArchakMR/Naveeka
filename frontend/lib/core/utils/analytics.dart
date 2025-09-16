// lib/core/utils/analytics.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Minimal analytics event model for consistency.
class AnalyticsEvent {
  final String name;
  final Map<String, Object?> params;

  const AnalyticsEvent(this.name, [this.params = const {}]);

  @override
  String toString() => 'AnalyticsEvent($name, $params)';
}

/// Interface for analytics backends (Firebase, Segment, Amplitude, Sentry, etc.). [2]
abstract class AnalyticsBackend {
  Future<void> init() async {}
  Future<void> setUserId(String? userId) async {}
  Future<void> setUserProperty(String key, String value) async {}
  Future<void> logEvent(String name, {Map<String, Object?> params = const {}}) async {}
  Future<void> logScreen(String screenName, {Map<String, Object?> params = const {}}) async {}
  Future<void> timeEventStart(String name, {Map<String, Object?> params = const {}}) async {}
  Future<void> timeEventEnd(String name, {Map<String, Object?> params = const {}}) async {}
  Future<void> flush() async {}
  Future<void> dispose() async {}
}

/// A simple console backend for development and as a safe default. [3]
class ConsoleAnalyticsBackend implements AnalyticsBackend {
  final bool enabled;
  const ConsoleAnalyticsBackend({this.enabled = true});

  @override
  Future<void> logEvent(String name, {Map<String, Object?> params = const {}}) async {
    if (!enabled) return;
    debugPrint('[analytics:event] $name ${params.isEmpty ? '' : params}');
  }

  @override
  Future<void> logScreen(String screenName, {Map<String, Object?> params = const {}}) async {
    if (!enabled) return;
    debugPrint('[analytics:screen] $screenName ${params.isEmpty ? '' : params}');
  }

  @override
  Future<void> timeEventStart(String name, {Map<String, Object?> params = const {}}) async {
    if (!enabled) return;
    debugPrint('[analytics:time:start] $name ${params.isEmpty ? '' : params}');
  }

  @override
  Future<void> timeEventEnd(String name, {Map<String, Object?> params = const {}}) async {
    if (!enabled) return;
    debugPrint('[analytics:time:end] $name ${params.isEmpty ? '' : params}');
  }
}

/// Fan-out backend that forwards to multiple child backends (e.g., Firebase + Segment). [2]
class MultiAnalyticsBackend implements AnalyticsBackend {
  final List<AnalyticsBackend> children;
  MultiAnalyticsBackend(this.children);

  @override
  Future<void> init() async {
    for (final b in children) {
      await b.init();
    }
  }

  @override
  Future<void> setUserId(String? userId) async {
    for (final b in children) {
      await b.setUserId(userId);
    }
  }

  @override
  Future<void> setUserProperty(String key, String value) async {
    for (final b in children) {
      await b.setUserProperty(key, value);
    }
  }

  @override
  Future<void> logEvent(String name, {Map<String, Object?> params = const {}}) async {
    for (final b in children) {
      await b.logEvent(name, params: params);
    }
  }

  @override
  Future<void> logScreen(String screenName, {Map<String, Object?> params = const {}}) async {
    for (final b in children) {
      await b.logScreen(screenName, params: params);
    }
  }

  @override
  Future<void> timeEventStart(String name, {Map<String, Object?> params = const {}}) async {
    for (final b in children) {
      await b.timeEventStart(name, params: params);
    }
  }

  @override
  Future<void> timeEventEnd(String name, {Map<String, Object?> params = const {}}) async {
    for (final b in children) {
      await b.timeEventEnd(name, params: params);
    }
  }

  @override
  Future<void> flush() async {
    for (final b in children) {
      await b.flush();
    }
  }

  @override
  Future<void> dispose() async {
    for (final b in children) {
      await b.dispose();
    }
  }
}

/// Singleton, backend-agnostic analytics facade used across the app. [3]
class Analytics {
  Analytics._internal();
  static final Analytics _instance = Analytics._internal();
  static Analytics get instance => _instance;

  AnalyticsBackend _backend = const ConsoleAnalyticsBackend(enabled: kDebugMode);
  bool _enabled = true;
  bool _consentGranted = true;

  // For timeEventStart/timeEventEnd
  final Map<String, DateTime> _timers = {};

  /// Configure the backend(s) at app bootstrap (e.g., MultiAnalyticsBackend([...])). [2]
  void configure(AnalyticsBackend backend) {
    _backend = backend;
  }

  Future<void> init() => _backend.init();

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  void setConsentGranted(bool granted) {
    _consentGranted = granted;
  }

  bool get isEnabled => _enabled && _consentGranted;

  Future<void> setUserId(String? userId) async {
    if (!isEnabled) return;
    await _backend.setUserId(userId);
  }

  Future<void> setUserProperty(String key, String value) async {
    if (!isEnabled) return;
    await _backend.setUserProperty(key, value);
  }

  Future<void> log(String name, {Map<String, Object?> params = const {}}) async {
    if (!isEnabled) return;
    await _backend.logEvent(name, params: params);
  }

  /// Screen tracking helper; integrate with your Navigator/GoRouter observer callback. [12]
  Future<void> screen(String screenName, {Map<String, Object?> params = const {}}) async {
    if (!isEnabled) return;
    await _backend.logScreen(screenName, params: params);
  }

  /// Start timing an event; pairs with end(name). [3]
  Future<void> timeStart(String name, {Map<String, Object?> params = const {}}) async {
    if (!isEnabled) return;
    _timers[name] = DateTime.now();
    await _backend.timeEventStart(name, params: params);
  }

  /// End timing; durationMs is attached to params automatically. [3]
  Future<void> timeEnd(String name, {Map<String, Object?> params = const {}}) async {
    if (!isEnabled) return;
    final start = _timers.remove(name);
    final durationMs = start == null ? null : DateTime.now().difference(start).inMilliseconds;
    final merged = {
      ...params,
      if (durationMs != null) 'durationMs': durationMs,
    };
    await _backend.timeEventEnd(name, params: merged);
  }

  Future<void> flush() => _backend.flush();

  Future<void> dispose() => _backend.dispose();
}

/// Screen tracking adapter for the existing navigation observer.
/// Call this from AppNavigationObserver.trackScreenView callback. [12]
Future<void> trackScreenView(String screenName, Map<String, String>? params) {
  return Analytics.instance.screen(
    screenName,
    params: params == null ? const {} : Map<String, Object?>.from(params),
  );
}
