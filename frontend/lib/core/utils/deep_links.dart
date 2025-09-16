// lib/core/utils/deep_links.dart

import '../../navigation/route_names.dart';

/// Result of parsing an inbound deep link into a logical route target.
class DeepLinkResult {
  final String routeName; // use with goNamed
  final Map<String, String> pathParams;
  final Map<String, String> queryParams;

  const DeepLinkResult({
    required this.routeName,
    this.pathParams = const {},
    this.queryParams = const {},
  });

  @override
  String toString() =>
      'DeepLinkResult(route=$routeName, path=$pathParams, query=$queryParams)';
}

/// Utilities to build and parse deep link URIs consistently across the app.
/// - Build shareable links for Atlas, Place, Journey…
class DeepLinks {
  const DeepLinks._();

  // ---------------- Builders (shareable URIs) ----------------

  /// Atlas with optional search and filters.
  static Uri atlas({
    String? query,
    String? region,
    bool? nearby,
    bool? trending,
    String? emotion,
    String? category,
    String? sort,
    double? radiusKm,
    bool? openNow,
    String? price,
    String? rating,
    double? lat,
    double? lng,
    double? zoom,
    String scheme = 'https',
    String host = 'app.local',
  }) {
    final qp = <String, String>{};
    void put(String k, Object? v) {
      if (v == null) return;
      qp[k] = v.toString();
    }

    put('q', query);
    put('region', region);
    if (nearby != null) put('nearby', nearby ? 'true' : 'false');
    if (trending != null) put('trending', trending ? 'true' : 'false');
    put('emotion', emotion);
    put('category', category);
    put('sort', sort);
    if (radiusKm != null) put('radius', radiusKm);
    if (openNow != null) put('openNow', openNow ? 'true' : 'false');
    put('price', price);
    put('rating', rating);
    if (lat != null) put('lat', lat);
    if (lng != null) put('lng', lng);
    if (zoom != null) put('zoom', zoom);

    return Uri(
      scheme: scheme,
      host: host,
      path: RoutePaths.atlas,
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  /// Place detail deep link: /place/:id
  static Uri placeDetail({
    required String id,
    String scheme = 'https',
    String host = 'app.local',
  }) {
    return Uri(
      scheme: scheme,
      host: host,
      path: '${RoutePaths.placeDetail}/$id',
    );
  }

  /// Journey search category links (e.g., /journey/flights?from=...&to=...&date=...)
  static Uri journeyCategory({
    required String categoryPath, // e.g. RoutePaths.flightSearch
    Map<String, String>? query,
    String scheme = 'https',
    String host = 'app.local',
  }) {
    return Uri(
      scheme: scheme,
      host: host,
      path: categoryPath,
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  // ---------------- Parsers (inbound URIs) ----------------

  /// Parse an inbound URI into a DeepLinkResult based on RoutePaths.
  /// This can be used when receiving links from OS/app links.
  static DeepLinkResult parse(Uri uri) {
    final path = uri.path;
    final qp = uri.queryParameters; // decoded by Uri [dart:core]

    // Place detail: /place/:id
    if (path.startsWith(RoutePaths.placeDetail)) {
      final segs = _segments(path);
      // Expect: ['', 'place', ':id'] or ['place', ':id'] depending on host base
      final id = segs.isNotEmpty ? segs.last : '';
      return DeepLinkResult(
        routeName: RouteNames.placeDetail,
        pathParams: {RouteParams.id: id},
        queryParams: qp,
      );
    }

    // Atlas: /atlas with query parameters
    if (path == RoutePaths.atlas) {
      return DeepLinkResult(
        routeName: RouteNames.atlas,
        pathParams: const {},
        queryParams: qp,
      );
    }

    // Journey categories example (extend as routes are added)
    if (path == RoutePaths.flightSearch ||
        path == RoutePaths.trainSearch ||
        path == RoutePaths.busSearch ||
        path == RoutePaths.cabSearch ||
        path == RoutePaths.hotelSearch ||
        path == RoutePaths.restaurantSearch ||
        path == RoutePaths.activitySearch ||
        path == RoutePaths.placeSearch) {
      // Map the path to the closest routeName used in the app.
      final name = _routeNameForJourneyPath(path);
      return DeepLinkResult(routeName: name, pathParams: const {}, queryParams: qp);
    }

    // Fallback: try to match main tabs
    if (path == RoutePaths.home) {
      return DeepLinkResult(routeName: RouteNames.home, queryParams: qp);
    }
    if (path == RoutePaths.trails) {
      return DeepLinkResult(routeName: RouteNames.trails, queryParams: qp);
    }
    if (path == RoutePaths.journey) {
      return DeepLinkResult(routeName: RouteNames.journey, queryParams: qp);
    }
    if (path == RoutePaths.naveeAI) {
      return DeepLinkResult(routeName: RouteNames.naveeAI, queryParams: qp);
    }

    // Default to atlas to prevent dead ends (adjust if preferred)
    return DeepLinkResult(routeName: RouteNames.atlas, queryParams: qp);
  }

  // ---------------- Helpers ----------------

  static List<String> _segments(String path) {
    final s = path.split('/').where((e) => e.isNotEmpty).toList();
    return s;
  }

  static String _routeNameForJourneyPath(String path) {
    switch (path) {
      case RoutePaths.flightSearch:
        return RouteNames.flightSearch;
      case RoutePaths.trainSearch:
        return RouteNames.trainSearch;
      case RoutePaths.busSearch:
        return RouteNames.busSearch;
      case RoutePaths.cabSearch:
        return RouteNames.cabSearch;
      case RoutePaths.hotelSearch:
        return RouteNames.hotelSearch;
      case RoutePaths.restaurantSearch:
        return RouteNames.restaurantSearch;
      case RoutePaths.activitySearch:
        return RouteNames.activitySearch;
      case RoutePaths.placeSearch:
        return RouteNames.placeSearch;
      default:
        return RouteNames.journey;
    }
  }
}
