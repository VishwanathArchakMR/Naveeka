// lib/features/trails/data/trails_api.dart

import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';

// Use the shared GeoPoint model (latitude/longitude).
import '../../../models/geo_point.dart' show GeoPoint;

/// Minimal summary model for a trail list card.
class TrailSummary {
  const TrailSummary({
    required this.id,
    required this.name,
    this.coverUrl,
    this.avgRating,
    this.lengthKm,
  });

  final String id;
  final String name;
  final String? coverUrl;
  final double? avgRating;
  final double? lengthKm;

  factory TrailSummary.fromJson(Map<String, dynamic> j) {
    return TrailSummary(
      id: (j['id'] ?? j['trailId'] ?? '').toString(),
      name: (j['name'] ?? j['title'] ?? '').toString(),
      coverUrl: j['coverUrl']?.toString(),
      avgRating: (j['avgRating'] as num?)?.toDouble(),
      lengthKm: (j['lengthKm'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'coverUrl': coverUrl,
        'avgRating': avgRating,
        'lengthKm': lengthKm,
      };
}

/// Full detail model for a trail page.
class TrailDetail {
  const TrailDetail({
    required this.id,
    required this.name,
    this.description,
    this.photos = const <String>[],
    this.lengthKm,
    this.elevationGainM,
    this.tags = const <String>[],
  });

  final String id;
  final String name;
  final String? description;
  final List<String> photos;
  final double? lengthKm;
  final int? elevationGainM;
  final List<String> tags;

  factory TrailDetail.fromJson(Map<String, dynamic> j) {
    return TrailDetail(
      id: (j['id'] ?? j['trailId'] ?? '').toString(),
      name: (j['name'] ?? j['title'] ?? '').toString(),
      description: j['description']?.toString(),
      photos: ((j['photos'] as List?) ?? const <Object>[])
          .map((e) => e.toString())
          .toList(growable: false),
      lengthKm: (j['lengthKm'] as num?)?.toDouble(),
      elevationGainM: (j['elevationGainM'] as num?)?.toInt(),
      tags: ((j['tags'] as List?) ?? const <Object>[])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'photos': photos,
        'lengthKm': lengthKm,
        'elevationGainM': elevationGainM,
        'tags': tags,
      };
}

/// Generic cursor page envelope used across list endpoints.
class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

/// Review model for trails.
class TrailReview {
  const TrailReview({
    required this.id,
    required this.trailId,
    required this.userId,
    required this.rating, // 1..5
    required this.text,
    required this.createdAt,
    this.photos = const <String>[],
    this.helpfulCount = 0,
    this.isHelpfulByMe = false,
  });

  final String id;
  final String trailId;
  final String userId;
  final int rating;
  final String text;
  final DateTime createdAt;
  final List<String> photos;
  final int helpfulCount;
  final bool isHelpfulByMe;

  factory TrailReview.fromJson(Map<String, dynamic> j) {
    return TrailReview(
      id: j['id'] as String,
      trailId: j['trailId'] as String,
      userId: j['userId'] as String,
      rating: (j['rating'] as num).toInt(),
      text: j['text'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      photos: (j['photos'] as List?)?.cast<String>() ?? const <String>[],
      helpfulCount: (j['helpfulCount'] as num?)?.toInt() ?? 0,
      isHelpfulByMe: j['isHelpfulByMe'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'trailId': trailId,
        'userId': userId,
        'rating': rating,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'photos': photos,
        'helpfulCount': helpfulCount,
        'isHelpfulByMe': isHelpfulByMe,
      };
}

/// Aggregated trail stats.
class TrailStats {
  const TrailStats({
    required this.reviewCount,
    required this.avgRating,
    required this.favoriteCount,
  });

  final int reviewCount;
  final double avgRating;
  final int favoriteCount;

  factory TrailStats.fromJson(Map<String, dynamic> j) {
    return TrailStats(
      reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
      avgRating: (j['avgRating'] as num?)?.toDouble() ?? 0.0,
      favoriteCount: (j['favoriteCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
        'reviewCount': reviewCount,
        'avgRating': avgRating,
        'favoriteCount': favoriteCount,
      };
}

/// API contract covering trail listing, details, reviews, favorites, media uploads, and reports.
abstract class TrailsApi {
  /// List trails with optional filters and cursor pagination.
  Future<CursorPage<TrailSummary>> list({
    String? query,
    GeoPoint? center,
    double? radiusKm,
    List<String>? tags,
    String? difficulty, // easy|moderate|hard
    double? minRating,
    int limit = 20,
    String? cursor,
  });

  /// Fetch full trail detail (summary + description + geometry/photos).
  Future<TrailDetail> getTrail(String id);

  /// List reviews for a trail with cursor pagination.
  Future<CursorPage<TrailReview>> getReviews({
    required String trailId,
    int limit = 20,
    String? cursor,
    String? sort, // recent|top
  });

  /// Post a review with rating/text and optional photo uploads.
  Future<TrailReview> postReview({
    required String trailId,
    required int rating,
    required String text,
    List<File>? photoFiles,
  });

  /// Mark/unmark a review as helpful.
  Future<bool> toggleReviewHelpful({required String trailId, required String reviewId, required bool nextValue});

  /// Upload a single trail photo (returns its URL).
  Future<String> uploadPhoto({required String trailId, required File file});

  /// Toggle favorite for a trail; returns final favorite state.
  Future<bool> toggleFavorite({required String trailId, required bool nextValue});

  /// List favorite trails of current user via cursor pagination.
  Future<CursorPage<TrailSummary>> listFavorites({int limit = 20, String? cursor});

  /// Report a trail for a reason with optional note.
  Future<bool> reportTrail({required String trailId, required String reason, String? note});

  /// Fetch aggregated stats for a trail.
  Future<TrailStats> getStats(String trailId);
}

/// Optional ETag store for conditional GETs.
class EtagStore {
  final Map<String, String> _etags = <String, String>{};

  String? get(String key) => _etags[key];
  void put(String key, String etag) => _etags[key] = etag;
}

/// Simple in-memory TTL cache for JSON-decoded responses.
class MemCache {
  MemCache({this.ttl = const Duration(minutes: 5)});
  final Duration ttl;

  // Record-typed value: named fields 'at' and 'data'.
  final Map<String, ({DateTime at, Object data})> _store =
      <String, ({DateTime at, Object data})>{}; // Proper record type with named fields. [web:6333][web:6340]

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

/// Dio-based implementation of TrailsApi with optional ETag and TTL caching.
class TrailsApiDio implements TrailsApi {
  TrailsApiDio(
    this._dio, {
    required this.baseUrl,
    this.apiKey,
    EtagStore? etags,
    MemCache? cache,
  })  : _etags = etags ?? EtagStore(),
        _cache = cache ?? MemCache();

  final Dio _dio;
  final String baseUrl;
  final String? apiKey;
  final EtagStore _etags;
  final MemCache _cache;

  Map<String, String> get _headers => {
        if (apiKey != null && apiKey!.trim().isNotEmpty) 'x-api-key': apiKey!.trim(),
        'accept': 'application/json',
      };

  @override
  Future<CursorPage<TrailSummary>> list({
    String? query,
    GeoPoint? center,
    double? radiusKm,
    List<String>? tags,
    String? difficulty,
    double? minRating,
    int limit = 20,
    String? cursor,
  }) async {
    final qp = <String, dynamic>{
      if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
      if (center != null) 'lat': center.latitude,
      if (center != null) 'lng': center.longitude,
      if (radiusKm != null) 'radiusKm': radiusKm,
      if ((tags ?? <String>[]).isNotEmpty) 'tags': tags!.join(','),
      if ((difficulty ?? '').isNotEmpty) 'difficulty': difficulty,
      if (minRating != null) 'minRating': minRating,
      'limit': limit,
      if ((cursor ?? '').isNotEmpty) 'cursor': cursor,
    };

    final key = 'trails:${qp.toString()}';
    final cached = _cache.get<CursorPage<TrailSummary>>(key);
    if (cached != null) return cached;

    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/trails',
      queryParameters: qp,
      options: Options(headers: _headers),
    );
    final data = resp.data ?? <String, dynamic>{};
    final items = ((data['items'] as List?) ?? const <Object>[])
        .map((e) => TrailSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final page = CursorPage<TrailSummary>(items: items, nextCursor: data['nextCursor'] as String?);
    _cache.put(key, page);
    return page;
  }

  @override
  Future<TrailDetail> getTrail(String id) async {
    final key = 'trail:$id';
    final cached = _cache.get<TrailDetail>(key);
    if (cached != null) return cached;

    final et = _etags.get(key);
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/trails/$id',
      options: Options(headers: {
        ..._headers,
        if (et != null) 'If-None-Match': et,
      }),
    );

    if (resp.statusCode == 304 && cached != null) {
      return cached;
    }

    final detail = TrailDetail.fromJson(resp.data ?? <String, dynamic>{});
    final etag = resp.headers.value('etag');
    if (etag != null) _etags.put(key, etag);
    _cache.put(key, detail);
    return detail;
  }

  @override
  Future<CursorPage<TrailReview>> getReviews({
    required String trailId,
    int limit = 20,
    String? cursor,
    String? sort,
  }) async {
    final qp = <String, dynamic>{
      'limit': limit,
      if ((cursor ?? '').isNotEmpty) 'cursor': cursor,
      if ((sort ?? '').isNotEmpty) 'sort': sort,
    };

    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/trails/$trailId/reviews',
      queryParameters: qp,
      options: Options(headers: _headers),
    );
    final data = resp.data ?? <String, dynamic>{};
    final items = ((data['items'] as List?) ?? const <Object>[])
        .map((e) => TrailReview.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return CursorPage<TrailReview>(items: items, nextCursor: data['nextCursor'] as String?);
  }

  @override
  Future<TrailReview> postReview({
    required String trailId,
    required int rating,
    required String text,
    List<File>? photoFiles,
  }) async {
    final form = FormData.fromMap({
      'rating': rating,
      'text': text,
      if ((photoFiles ?? const <File>[]).isNotEmpty)
        'photos': [
          for (final f in photoFiles!) await MultipartFile.fromFile(f.path, filename: _basename(f.path)),
        ],
    });

    final resp = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/trails/$trailId/reviews',
      data: form,
      options: Options(headers: {
        ..._headers,
        'content-type': 'multipart/form-data',
      }),
    );
    return TrailReview.fromJson(resp.data ?? <String, dynamic>{});
  } // Multipart uploads via Dio FormData/MultipartFile. [web:6341][web:6338]

  @override
  Future<bool> toggleReviewHelpful({required String trailId, required String reviewId, required bool nextValue}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/trails/$trailId/reviews/$reviewId/helpful',
      data: {'value': nextValue},
      options: Options(headers: _headers),
    );
    return (resp.data?['ok'] as bool?) ?? true;
  }

  @override
  Future<String> uploadPhoto({required String trailId, required File file}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: _basename(file.path)),
    });
    final resp = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/trails/$trailId/photos',
      data: form,
      options: Options(headers: {
        ..._headers,
        'content-type': 'multipart/form-data',
      }),
    );
    return (resp.data?['url'] as String?) ?? '';
  } // Multipart file upload using Dio MultipartFile.fromFile. [web:6341][web:6338]

  @override
  Future<bool> toggleFavorite({required String trailId, required bool nextValue}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/trails/$trailId/favorite',
      data: {'value': nextValue},
      options: Options(headers: _headers),
    );
    return (resp.data?['favorited'] as bool?) ?? nextValue;
  }

  @override
  Future<CursorPage<TrailSummary>> listFavorites({int limit = 20, String? cursor}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/users/me/favorites/trails',
      queryParameters: <String, dynamic>{
        'limit': limit,
        if ((cursor ?? '').isNotEmpty) 'cursor': cursor,
      },
      options: Options(headers: _headers),
    );
    final data = resp.data ?? <String, dynamic>{};
    final items = ((data['items'] as List?) ?? const <Object>[])
        .map((e) => TrailSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return CursorPage<TrailSummary>(items: items, nextCursor: data['nextCursor'] as String?);
  }

  @override
  Future<bool> reportTrail({required String trailId, required String reason, String? note}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/trails/$trailId/report',
      data: <String, dynamic>{'reason': reason, if ((note ?? '').isNotEmpty) 'note': note},
      options: Options(headers: _headers),
    );
    return (resp.data?['ok'] as bool?) ?? true;
  }

  @override
  Future<TrailStats> getStats(String trailId) async {
    final key = 'stats:$trailId';
    final cached = _cache.get<TrailStats>(key);
    if (cached != null) return cached;

    final resp = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/trails/$trailId/stats',
      options: Options(headers: _headers),
    );
    final stats = TrailStats.fromJson(resp.data ?? <String, dynamic>{});
    _cache.put(key, stats);
    return stats;
  }

  String _basename(String path) {
    final i = path.replaceAll('\\', '/').lastIndexOf('/');
    return i >= 0 ? path.substring(i + 1) : path;
  }
}
