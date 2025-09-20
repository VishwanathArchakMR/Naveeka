// lib/services/maps_service.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../models/coordinates.dart';

/// A simple geographic bounds rectangle defined by SW and NE corners (lon-lat order in GeoJSON terms).
@immutable
class MapBounds {
  const MapBounds({
    required this.southWest,
    required this.northEast,
  });

  final Coordinates southWest;
  final Coordinates northEast;

  bool get isEmpty =>
      southWest.latitude == northEast.latitude && southWest.longitude == northEast.longitude;

  /// Expand bounds by a small delta in degrees.
  MapBounds padDegrees(double dLat, double dLng) {
    return MapBounds(
      southWest: Coordinates(
        latitude: southWest.latitude - dLat,
        longitude: southWest.longitude - dLng,
      ),
      northEast: Coordinates(
        latitude: northEast.latitude + dLat,
        longitude: northEast.longitude + dLng,
      ),
    );
  }

  /// Return bbox in RFC 7946 order [west, south, east, north].
  List<double> get bbox => <double>[
        southWest.longitude,
        southWest.latitude,
        northEast.longitude,
        northEast.latitude,
      ];
}

/// Pixel padding for viewport fitting.
@immutable
class MapPadding {
  const MapPadding({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get horizontal => left + right;
  double get vertical => top + bottom;

  MapPadding copyWith({double? left, double? top, double? right, double? bottom}) {
    return MapPadding(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }
}

/// A minimal Web Mercator / Slippy-tiles utility set (tileSize=256).
class WebMercator {
  static const int tileSize = 256; // pixels per tile (standard)
  static const double minLat = -85.05112878; // Web Mercator clamp
  static const double maxLat = 85.05112878;

  /// Convert degrees to radians.
  static double _degToRad(double deg) => deg * math.pi / 180.0;

  /// Convert radians to degrees.
  static double _radToDeg(double rad) => rad * 180.0 / math.pi;

  /// Project lon/lat to normalized Web Mercator [0..1] x [0..1].
  static math.Point<double> projectNormalized(Coordinates c) {
    final lon = c.longitude;
    final lat = c.latitude.clamp(minLat, maxLat).toDouble();
    final x = (lon + 180.0) / 360.0;
    final sinLat = math.sin(_degToRad(lat));
    final y = 0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi);
    return math.Point<double>(x, y);
  } // Follows Slippy/Web Mercator derivation. [web:6610]

  /// Unproject normalized [0..1] x [0..1] back to lon/lat.
  static Coordinates unprojectNormalized(math.Point<double> p) {
    final lon = p.x * 360.0 - 180.0;
    final n = math.pi - 2.0 * math.pi * p.y;
    final lat = _radToDeg(math.atan((math.exp(n) - math.exp(-n)) / 2))
        .clamp(minLat, maxLat)
        .toDouble();
    return Coordinates(latitude: lat, longitude: lon);
  } // Inverse Web Mercator. [web:6610]

  /// Convert lon/lat to pixel coordinates at a zoom level.
  static math.Point<double> lonLatToPixel(Coordinates c, double zoom) {
    final n = math.pow(2.0, zoom) as double;
    final p = projectNormalized(c);
    return math.Point<double>(p.x * n * tileSize, p.y * n * tileSize);
  } // XYZ scheme with 256px tiles. [web:6616]

  /// Convert pixel coordinates at a zoom level back to lon/lat.
  static Coordinates pixelToLonLat(math.Point<double> px, double zoom) {
    final n = math.pow(2.0, zoom) as double;
    final nx = px.x / (tileSize * n);
    final ny = px.y / (tileSize * n);
    return unprojectNormalized(math.Point<double>(nx, ny));
  } // Standard inverse pixel->lon/lat. [web:6616]

  /// Convert lon/lat to Slippy tile x,y at integer zoom (floor).
  static math.Point<int> lonLatToTile(Coordinates c, int zoom) {
    final n = 1 << zoom;
    final p = projectNormalized(c);
    final x = (p.x * n).floor();
    final y = (p.y * n).floor();
    return math.Point<int>(x, y);
  } // Slippy tile naming. [web:6616]

  /// Tile bounds in lon/lat for x,y,z.
  static MapBounds tileBounds(int x, int y, int zoom) {
    final n = 1 << zoom;
    final sw = unprojectNormalized(math.Point<double>(x / n, (y + 1) / n));
    final ne = unprojectNormalized(math.Point<double>((x + 1) / n, y / n));
    return MapBounds(southWest: sw, northEast: ne);
  } // Tile bounding box in WGS84. [web:6616]
}

/// Result of a viewport fit operation: center and zoom.
@immutable
class ViewportFit {
  const ViewportFit({required this.center, required this.zoom});

  final Coordinates center;
  final double zoom;
}

/// Operations for bounds, zoom fitting, FeatureCollection assembly, and clustering.
class MapsService {
  const MapsService();

  /// Compute a map center and zoom to fit bounds within width/height pixels and padding.
  /// Based on Web Mercator math and common fitBounds derivations. [6][15]
  ViewportFit fitBounds({
    required MapBounds bounds,
    required double widthPx,
    required double heightPx,
    MapPadding padding = const MapPadding(),
    int maxZoom = 21,
  }) {
    // Clamp latitudes to Web Mercator supported range.
    final swLat = bounds.southWest.latitude.clamp(WebMercator.minLat, WebMercator.maxLat).toDouble();
    final neLat = bounds.northEast.latitude.clamp(WebMercator.minLat, WebMercator.maxLat).toDouble();
    final swLng = bounds.southWest.longitude;
    final neLng = bounds.northEast.longitude;

    // Map dimensions after padding.
    final usableW = (widthPx - padding.horizontal).clamp(1.0, widthPx).toDouble();
    final usableH = (heightPx - padding.vertical).clamp(1.0, heightPx).toDouble();

    // Helper functions per common solutions (latRad and zoom calc).
    double latRad(double lat) {
      final s = math.sin(lat * math.pi / 180.0);
      final radX2 = math.log((1 + s) / (1 - s)) / 2.0;
      return math.max(math.min(radX2, math.pi), -math.pi) / 2.0;
    } // See SO derivation for bounds->zoom. [web:6616]

    double zoom(double mapPx, double worldPx, double fraction) {
      final v = math.log(mapPx / worldPx / fraction) / math.ln2;
      return v.floorToDouble();
    } // Fraction-based zoom computation. [web:6616]

    final worldPx = WebMercator.tileSize.toDouble();

    final latFraction = (latRad(neLat) - latRad(swLat)) / math.pi;
    var lngDiff = neLng - swLng;
    if (lngDiff < 0) lngDiff += 360.0; // anti-meridian wrap
    final lngFraction = (lngDiff) / 360.0;

    final latZoom = zoom(usableH, worldPx, latFraction.abs().clamp(1e-12, 1.0).toDouble());
    final lngZoom = zoom(usableW, worldPx, lngFraction.abs().clamp(1e-12, 1.0).toDouble());
    final z = math.min(math.min(latZoom, lngZoom), maxZoom.toDouble());

    // Center as geometric midpoint considering wrap.
    final centerLat = (swLat + neLat) / 2.0;
    double centerLng = (swLng + neLng) / 2.0;
    if (swLng > neLng) {
      // Wrapped: choose midpoint across anti-meridian
      centerLng = ((swLng + (neLng + 360.0)) / 2.0);
      if (centerLng > 180.0) centerLng -= 360.0;
    }

    return ViewportFit(center: Coordinates(latitude: centerLat, longitude: centerLng), zoom: z);
  } // Produces a reasonable fit for typical map UIs. [web:6616]

  /// Compute bounds from a list of coordinates (returns minimal rectangle in lon/lat).
  MapBounds? boundsFor(List<Coordinates> coords) {
    if (coords.isEmpty) return null;
    double minLat = coords.first.latitude, maxLat = coords.first.latitude;
    double minLng = coords.first.longitude, maxLng = coords.first.longitude;
    for (final c in coords) {
      minLat = math.min(minLat, c.latitude);
      maxLat = math.max(maxLat, c.latitude);
      minLng = math.min(minLng, c.longitude);
      maxLng = math.max(maxLng, c.longitude);
    }
    return MapBounds(
      southWest: Coordinates(latitude: minLat, longitude: minLng),
      northEast: Coordinates(latitude: maxLat, longitude: maxLng),
    );
  } // Basic bbox for features/markers. [web:6616]

  /// Assemble a GeoJSON FeatureCollection from prebuilt Feature objects.
  Map<String, dynamic> featureCollection(List<Map<String, dynamic>> features,
      {List<double>? bbox}) {
    final fc = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };
    if (bbox != null && bbox.length >= 4) {
      fc['bbox'] = bbox;
    }
    return fc;
  } // RFC 7946 FeatureCollection shape. [web:6616]

  /// Build a Slippy tile URL from a template, e.g. https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png
  /// Selects subdomain by hashing x+y for simple balancing when {s} is provided.
  String tileUrl({
    required String template,
    required int x,
    required int y,
    required int z,
    List<String> subdomains = const <String>['a', 'b', 'c'],
    Map<String, String> query = const <String, String>{},
  }) {
    String url = template
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
    if (url.contains('{s}') && subdomains.isNotEmpty) {
      final s = subdomains[(x + y) % subdomains.length];
      url = url.replaceAll('{s}', s);
    }
    if (query.isNotEmpty) {
      final qp = query.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
      final hasQ = url.contains('?');
      url = hasQ ? '$url&$qp' : '$url?$qp';
    }
    return url;
  } // Slippy tilenames and URL templates. [web:6616]

  /// A lightweight grid-based clusterer suitable for basic marker clustering without heavy deps.
  /// Clusters points into grid cells at a given zoom with a gridSizePx.
  List<Cluster> clusterPoints({
    required List<Coordinates> points,
    required double zoom,
    double gridSizePx = 64.0,
  }) {
    if (points.isEmpty) return const <Cluster>[];

    final cells = <_CellKey, List<Coordinates>>{};
    for (final c in points) {
      final px = WebMercator.lonLatToPixel(c, zoom);
      final gx = (px.x / gridSizePx).floor();
      final gy = (px.y / gridSizePx).floor();
      final key = _CellKey(gx, gy);
      (cells[key] ??= <Coordinates>[]).add(c);
    }

    final out = <Cluster>[];
    cells.forEach((key, group) {
      if (group.length == 1) {
        out.add(Cluster.single(group.first));
      } else {
        // Compute centroid in lon/lat by averaging projected normalized coordinates.
        double sx = 0, sy = 0;
        for (final c in group) {
          final p = WebMercator.projectNormalized(c);
          sx += p.x;
          sy += p.y;
        }
        final cx = sx / group.length;
        final cy = sy / group.length;
        final center = WebMercator.unprojectNormalized(math.Point<double>(cx, cy));
        out.add(Cluster.group(center: center, count: group.length));
      }
    });
    return out;
  } // Grid clustering using Web Mercator pixels at zoom. [web:6616]

  /// Build a GeoJSON Feature for a cluster (Point with properties).
  Map<String, dynamic> clusterFeature(Cluster c) {
    return <String, dynamic>{
      'type': 'Feature',
      'geometry': <String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[c.center.longitude, c.center.latitude],
      },
      'properties': <String, dynamic>{
        'cluster': c.isCluster,
        'point_count': c.count,
      },
    };
  } // Feature encoding as RFC 7946 Point with properties. [web:6616]

  /// Create a FeatureCollection for clusters.
  Map<String, dynamic> clusterFeatureCollection(List<Cluster> clusters) {
    final feats = clusters.map(clusterFeature).toList(growable: false);
    return featureCollection(feats);
  } // Proper FeatureCollection container. [web:6616]
}

/// Internal key for grid buckets.
@immutable
class _CellKey {
  const _CellKey(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) => other is _CellKey && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Cluster output, either a single point or an aggregate cluster with count.
@immutable
class Cluster {
  const Cluster._({required this.center, required this.count});

  factory Cluster.single(Coordinates c) => Cluster._(center: c, count: 1);

  factory Cluster.group({required Coordinates center, required int count}) =>
      Cluster._(center: center, count: count);

  final Coordinates center;
  final int count;

  bool get isCluster => count > 1;
}
