// lib/navigation/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/atlas/presentation/atlas_screen.dart';
import 'route_names.dart';

/// Global navigator key (root) for programmatic navigation and dialogs. [go_router]
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// The shared GoRouter instance used by the app. [1]
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: RoutePaths.splash,
  debugLogDiagnostics: false,
  routes: <RouteBase>[
    // Splash (placeholder until screen wired)
    GoRoute(
      name: RouteNames.splash,
      path: RoutePaths.splash,
      builder: (context, state) => const _SplashPlaceholder(),
    ),

    // Home (placeholder until screen wired)
    GoRoute(
      name: RouteNames.home,
      path: RoutePaths.home,
      builder: (context, state) => const _HomePlaceholder(),
    ),

    // Atlas (wired to real screen)
    GoRoute(
      name: RouteNames.atlas,
      path: RoutePaths.atlas,
      builder: (context, state) {
        final qp = state.uri.queryParameters;

        // Query parsing aligned with AtlasScreen signature
        final initialQuery = qp['q'];
        final region = qp['region'];
        final nearby = _parseBool(qp['nearby']);
        final trending = _parseBool(qp['trending']);

        return AtlasScreen(
          initialQuery: initialQuery,
          region: region,
          nearby: nearby,
          trending: trending,
        );
      },
    ),

    // Place detail (placeholder for now; respects :id path) [1]
    GoRoute(
      name: RouteNames.placeDetail,
      path: '${RoutePaths.placeDetail}/:${RouteParams.id}',
      builder: (context, state) {
        final id = state.pathParameters[RouteParams.id] ?? '';
        return _PlaceDetailPlaceholder(placeId: id);
      },
    ),

    // Trails (placeholder)
    GoRoute(
      name: RouteNames.trails,
      path: RoutePaths.trails,
      builder: (context, state) => const _SimplePlaceholder(title: 'Trails'),
    ),

    // Journey (placeholder)
    GoRoute(
      name: RouteNames.journey,
      path: RoutePaths.journey,
      builder: (context, state) => const _SimplePlaceholder(title: 'Journey'),
    ),

    // Navee AI (placeholder)
    GoRoute(
      name: RouteNames.naveeAI,
      path: RoutePaths.naveeAI,
      builder: (context, state) => const _SimplePlaceholder(title: 'Navee AI'),
    ),

    // Settings (placeholder)
    GoRoute(
      name: RouteNames.settings,
      path: RoutePaths.settings,
      builder: (context, state) => const _SimplePlaceholder(title: 'Settings'),
    ),

    // Profile (placeholder)
    GoRoute(
      name: RouteNames.profile,
      path: RoutePaths.profile,
      builder: (context, state) => const _SimplePlaceholder(title: 'Profile'),
    ),

    // Checkout (placeholder)
    GoRoute(
      name: RouteNames.checkout,
      path: RoutePaths.checkout,
      builder: (context, state) => const _SimplePlaceholder(title: 'Checkout'),
    ),
  ],
  errorBuilder: (context, state) => _RouterErrorScreen(error: state.error),
);

bool? _parseBool(String? v) {
  if (v == null) return null;
  final s = v.toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

/// ------------ Placeholders (safe, const, removable later) ------------

class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Splash'),
      ),
    );
  }
}

class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Home'),
      ),
    );
  }
}

class _PlaceDetailPlaceholder extends StatelessWidget {
  final String placeId;
  const _PlaceDetailPlaceholder({required this.placeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place Detail')),
      body: Center(
        child: Text('Place ID: $placeId'),
      ),
    );
  }
}

class _SimplePlaceholder extends StatelessWidget {
  final String title;
  const _SimplePlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

class _RouterErrorScreen extends StatelessWidget {
  final Exception? error;
  const _RouterErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    final message = error?.toString() ?? 'Unknown route error';
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation Error')),
      body: Center(
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
