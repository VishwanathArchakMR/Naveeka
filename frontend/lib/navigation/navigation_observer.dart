// lib/navigation/navigation_observer.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// App-wide navigation observer that works with GoRouter's `observers:` list
/// to track route transitions and optionally report analytics. [15]
class AppNavigationObserver extends NavigatorObserver {
  AppNavigationObserver({
    this.logToConsole = kDebugMode,
    this.onRoutePushed,
    this.onRoutePopped,
    this.onRouteReplaced,
    this.onRouteRemoved,
    this.trackScreenView,
  });

  /// When true, prints simple logs for navigation events in debug/profile. [1]
  final bool logToConsole;

  /// Optional hooks for custom handling of navigation events. [1]
  final void Function(Route<dynamic> route, Route<dynamic>? previousRoute)? onRoutePushed;
  final void Function(Route<dynamic> route, Route<dynamic>? previousRoute)? onRoutePopped;
  final void Function(Route<dynamic>? newRoute, Route<dynamic>? oldRoute)? onRouteReplaced;
  final void Function(Route<dynamic> route, Route<dynamic>? previousRoute)? onRouteRemoved;

  /// Optional analytics hook: screen name + params map (if available). [5][13]
  final void Function(String screenName, Map<String, String>? params)? trackScreenView;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _log('didPush', route, previousRoute);
    onRoutePushed?.call(route, previousRoute);
    _track(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _log('didPop', route, previousRoute);
    onRoutePopped?.call(route, previousRoute);
    // Track previous when popping back
    _track(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _log('didReplace', newRoute, oldRoute);
    onRouteReplaced?.call(newRoute, oldRoute);
    _track(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _log('didRemove', route, previousRoute);
    onRouteRemoved?.call(route, previousRoute);
  }

  void _log(String label, Route<dynamic>? route, Route<dynamic>? previous) {
    if (!logToConsole) return;
    debugPrint(
      '[$label] route=${_routeStr(route)} prev=${_routeStr(previous)}',
    );
  }

  void _track(Route<dynamic>? route) {
    if (trackScreenView == null || route == null) return;
    final name = route.settings.name ?? _extractPath(route) ?? 'unknown';
    final params = _extractParams(route);
    trackScreenView!.call(name, params);
  }

  // Attempts to extract a human-readable descriptor for logging. [1]
  String _routeStr(Route<dynamic>? route) {
    if (route == null) return 'null';
    final name = route.settings.name;
    final args = route.settings.arguments;
    return 'name=$name args=$args';
  }

  // For go_router, settings.name is typically set to the GoRoute name; path may be in debugDescription. [14]
  String? _extractPath(Route<dynamic> route) {
    try {
      final s = route.settings;
      if (s.name != null) return s.name;
      return route.toString();
    } catch (_) {
      return null;
    }
  }

  // If arguments carry a params map, surface it to analytics; otherwise null. [1]
  Map<String, String>? _extractParams(Route<dynamic> route) {
    final args = route.settings.arguments;
    if (args is Map) {
      // best-effort String map
      return args.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return null;
    }
}

/// Convenience builder to plug into GoRouter.observers:
///
/// final router = GoRouter(
///   observers: [buildAppNavObserver()],
///   routes: [...],
/// );
NavigatorObserver buildAppNavObserver({
  bool logToConsole = kDebugMode,
  void Function(String screen, Map<String, String>? params)? trackScreenView,
}) {
  return AppNavigationObserver(
    logToConsole: logToConsole,
    trackScreenView: trackScreenView,
  );
}
