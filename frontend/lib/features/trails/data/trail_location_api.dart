// lib/features/trails/data/trail_location_api.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';

/// A simple lat/lng pair.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  Map<String, Object> toJson() => {'lat': lat, 'lng': lng};
}

/// A compact trail summary used in lists and nearby lookups.
class TrailSummary {
  const TrailSummary({
    required this.id,
    required this.name,
    required this.center,
    this.distanceKm,
    this.elevationGainM,
    this.difficulty, // easy | moderate | hard
    this.thumbnailUrl,
    this.rating, // 0..5
    this.tags = const <String>[],
  });

  final String id;
  final String name;
  final GeoPoint center;
  final double? distanceKm;
  final double? elevationGainM;
  final String? difficulty;
  final String? thumbnailUrl;
  final double? rating;
  final List<String> tags;

  factory TrailSummary.fromJson(Map<String, dynamic> j) {
    final c = j['center'] as Map<String, dynamic>?;
    return TrailSummary(
      id: j['id'] as String,
      name: j['name'] as String,
      center: GeoPoint(
        (c?['lat'] as num?)?.toDouble() ?? (j['lat'] as num).toDouble(),
        (c?['lng'] as num?)?.toDouble() ?? (j['lng'] as num).toDouble(),
      ),
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      elevationGainM: (j['elevationGainM'] as num?)?.toDouble(),
      difficulty: j['difficulty'] as String?,
      thumbnailUrl: j['thumbnailUrl'] as String?,
      rating: (j['rating'] as num?)?.toDouble(),
      tags: (j['tags'] as List?)?.cast<String>() ?? const <String>[],
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'center': center.toJson(),
        'distanceKm': distanceKm,
        'elevationGainM': elevationGainM,
        'difficulty': difficulty,
        'thumbnailUrl': thumbnailUrl,
        'rating': rating,
        'tags': tags,
      };
}

/// Full trail detail with optional geometry.
class TrailDetail {
  const TrailDetail({
    required this.summary,
    this.description,
    this.lengthKm,
    this.maxElevationM,
    this.minElevationM,
    this.geometry, // polyline points as list
    this.photos = const <String>[],
  });

  final TrailSummary summary;
  final String? description;
  final double? lengthKm;
  final double? maxElevationM;
  final double? minElevationM;
  final List<GeoPoint>? geometry;
  final List<String> photos;

  factory TrailDetail.fromJson(Map<String, dynamic> j) {
    final geometry = (j['geometry'] as List?)
        ?.map((e) => GeoPoint((e['lat'] as num).toDouble(), (e['lng'] as num).toDouble()))
        .toList();
    return TrailDetail(
      summary: TrailSummary.fromJson(j['summary'] as Map<String, dynamic>),
      description: j['description'] as String?,
      lengthKm: (j['lengthKm'] as num?)?.toDouble(),
      maxElevationM: (j['maxElevationM'] as num?)?.toDouble(),
      minElevationM: (j['minElevationM'] as num?)?.toDouble(),
      geometry: geometry,
      photos: (j['photos'] as List?)?.cast<String>() ?? const <String>[],
    );
  }

  Map<String, Object?> toJson() => {
        'summary': summary.toJson(),
        'description': description,
        'lengthKm': lengthKm,
        'maxElevationM': maxElevationM,
        'minElevationM': minElevationM,
        'geometry': geometry?.map((p) => p.toJson()).toList(),
        'photos': photos,
      };
}

/// Cursor-based page envelope.
class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

/// Contract for the trail location API.
abstract class TrailLocationApi {
  /// Search trails with optional text query, center/radius, and pagination.
  Future<CursorPage<TrailSummary>> search({
    String? query,
    GeoPoint? center,
    double? radiusKm,
    List<String>? tags,
    int limit = 20,
    String? cursor,
  });

  /// Nearby trails around a center within radius (server-side preferred).
  Future<List<TrailSummary>> nearby({
    required GeoPoint center,
    double radiusKm = 25,
    int limit = 50,
    List<String>? tags,
  });

  /// Fetch a single trail detail by id.
  Future<TrailDetail> getTrail(String id);

  /// Fetch only the trail geometry (polyline points).
  Future<List<GeoPoint>> getGeometry(String id);
}

/// Minimal in-memory TTL cache for GET responses.
class _MemCache {
  _MemCache();

  final Duration ttl;
  final Map<String, ({DateTime at, Object data})> _store = <String, ({DateTime, Object})>{};

  T? get<T>(String key) {
    final hit = _store[key];
    if (hit == null) return null;
    if (DateTime.now().difference(hit.at) > ttl) {
      _store.remove(key);
      return null;
    }
    return hit.data as T;
  }

  void put(String key, Object data) {
    _store[key] = (at: DateTime.now(), data: data);
  }
}

/// Dio-based implementation of TrailLocationApi.
/// - Uses interceptors for headers/logging and supports baseUrl+apiKey injection. [Dio] [9][14]
class TrailLocationApiDio implements TrailLocationApi {
  TrailLocationApiDio(
    this._dio, {
    required this.baseUrl,
    this.apiKey,
    _MemCache? cache,
  }) : _cache = cache ?? _MemCache();

  final Dio _dio;
  final String baseUrl;
  final String? apiKey;
  final _MemCache _cache;

  Map<String, String> get _headers => {
        if (apiKey != null && apiKey!.trim().isNotEmpty) 'x-api-key': apiKey!.trim(),
        'accept': 'application/json',
      };

  @override
  Future<CursorPage<TrailSummary>> search({
    String? query,
    GeoPoint? center,
    double? radiusKm,
    List<String>? tags,
    int limit = 20,
    String? cursor,
  }) async {
    final params = <String, dynamic>{
      if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
      if (center != null) 'lat': center.lat,
      if (center != null) 'lng': center.lng,
      if (radiusKm != null) 'radiusKm': radiusKm,
      if ((tags ?? <String>[]).isNotEmpty) 'tags': tags!.join(','),
      'limit': limit,
      if ((cursor ?? '').isNotEmpty) 'cursor': cursor,
    };

    final cacheKey = 'search:${params.toString()}';
    final cached = _cache.get<CursorPage<TrailSummary>>(cacheKey);
    if (cached != null) return cached;

    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/trails/search',
      queryParameters: params,
      options: Options(headers: _headers),
    );

    final data = resp.data ?? <String, dynamic>{};
    final items = ((data['items'] as List?) ?? const <Object>[])
        .map((e) => TrailSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final page = CursorPage<TrailSummary>(items: items, nextCursor: data['nextCursor'] as String?);

    _cache.put(cacheKey, page);
    return page;
  }

  @override
  Future<List<TrailSummary>> nearby({
    required GeoPoint center,
    double radiusKm = 25,
    int limit = 50,
    List<String>? tags,
  }) async {
    // Prefer server-side filtering; fall back to client-side distance sort if only a bounding set is returned. [Haversine] [5][2]
    final resp = await _dio.get<List<dynamic>>(
      '$baseUrl/trails/nearby',
      queryParameters: <String, dynamic>{
        'lat': center.lat,
        'lng': center.lng,
        'radiusKm': radiusKm,
        'limit': limit,
        if ((tags ?? <String>[]).isNotEmpty) 'tags': tags!.join(','),
      },
      options: Options(headers: _headers),
    );

    final items = (resp.data ?? const <Object>[])
        .map((e) => TrailSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    // If server didn’t sort by distance, sort locally by Haversine.
    items.sort((a, b) {
      final da = _haversineKm(center, a.center);
      final db = _haversineKm(center, b.center);
      return da.compareTo(db);
    });

    // Truncate to limit after sort to ensure deterministic returns.
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<TrailDetail> getTrail(String id) async {
    final cacheKey = 'trail:$id';
    final cached = _cache.get<TrailDetail>(cacheKey);
    if (cached != null) return cached;

    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/trails/$id',
      options: Options(headers: _headers),
    );
    final detail = TrailDetail.fromJson(resp.data ?? <String, dynamic>{});
    _cache.put(cacheKey, detail);
    return detail;
  }

  @override
  Future<List<GeoPoint>> getGeometry(String id) async {
    final cacheKey = 'geom:$id';
    final cached = _cache.get<List<GeoPoint>>(cacheKey);
    if (cached != null) return cached;

    final resp = await _dio.get<List<dynamic>>(
      '$baseUrl/trails/$id/geometry',
      options: Options(headers: _headers),
    );
    final pts = (resp.data ?? const <Object>[])
        .map((e) => GeoPoint((e as Map<String, dynamic>)['lat'] as double, e['lng'] as double))
        .toList(growable: false);
    _cache.put(cacheKey, pts);
    return pts;
  }

  // --- Utilities ---

  /// Great-circle distance using the Haversine formula (km). [5][2]
  double _haversineKm(GeoPoint a, GeoPoint b) {
    const r = 6371.0; // km
    const p = math.pi / 180.0;
    final dLat = (b.lat - a.lat) * p;
    final dLon = (b.lng - a.lng) * p;
    final lat1 = a.lat * p;
    final lat2 = b.lat * p;

    final h = 0.5 -
        math.cos(dLat) / 2 +
        math.cos(lat1) * math.cos(lat2) * (1 - math.cos(dLon)) / 2;
    return 2 * r * math.asin(math.sqrt(h));
  }
}
