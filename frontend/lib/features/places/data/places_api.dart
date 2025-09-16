// lib/features/places/data/places_api.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/config/constants.dart';
import '../../../models/place.dart';

/// Handles all API requests related to Places.
/// Uses DioClient for secure requests (with JWT if available) and
/// returns clean ApiResult<T> objects for use in providers and UI.
class PlacesApi {
  final Dio _dio;

  PlacesApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  /// Fetch list of places with optional filters.
  ///
  /// Server is expected to accept:
  /// - category: String
  /// - emotion: String
  /// - q: text query (optional)
  /// - lat,lng (optional) to bias results
  /// - radius: meters (optional)
  /// - page, limit: pagination
  ///
  /// Returns ApiResult<List<Place>> mapped from response.data['data'].
  Future<ApiResult<List<Place>>> list({
    String? category,
    String? emotion,
    String? q,
    double? lat,
    double? lng,
    int? radius,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get(
        AppConstants.apiPlaces,
        queryParameters: <String, dynamic>{
          if (category != null && category.isNotEmpty) 'category': category,
          if (emotion != null && emotion.isNotEmpty) 'emotion': emotion,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (radius != null) 'radius': radius,
          'page': page,
          'limit': limit,
        },
        cancelToken: cancelToken,
      ); // queryParameters are merged into the URL; CancelToken allows callers to cancel in-flight requests safely. [12][1]

      final root = res.data;
      final rawList = (root is Map && root['data'] is List)
          ? root['data'] as List
          : const <dynamic>[];
      return rawList
          .map((json) => Place.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  /// Fetch single place by ID.
  Future<ApiResult<Place>> getById(String id,
      {CancelToken? cancelToken}) async {
    return ApiResult.guardFuture(() async {
      final res =
          await _dio.get(ApiPath.placeById(id), cancelToken: cancelToken);
      final root = res.data;
      final data = (root is Map && root['data'] != null)
          ? root['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      return Place.fromJson(data);
    });
  }

  /// Create a new place (Partner/Admin only).
  Future<ApiResult<Place>> create(Map<String, dynamic> payload,
      {CancelToken? cancelToken}) async {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post(AppConstants.apiPlaces,
          data: payload, cancelToken: cancelToken);
      final root = res.data;
      final data = (root is Map && root['data'] != null)
          ? root['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      return Place.fromJson(data);
    });
  }

  /// Update an existing place by ID (partial update allowed).
  Future<ApiResult<Place>> update(String id, Map<String, dynamic> payload,
      {CancelToken? cancelToken}) async {
    return ApiResult.guardFuture(() async {
      final res = await _dio.patch(ApiPath.placeById(id),
          data: payload, cancelToken: cancelToken);
      final root = res.data;
      final data = (root is Map && root['data'] != null)
          ? root['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      return Place.fromJson(data);
    });
  }

  /// Approve a place (Admin only).
  Future<ApiResult<void>> approve(String id, {CancelToken? cancelToken}) async {
    return ApiResult.guardFuture(() async {
      await _dio.patch(ApiPath.approvePlace(id), cancelToken: cancelToken);
    });
  }

  /// Publish or unpublish a place (Admin/Owner).
  /// If backend exposes dedicated endpoints, wire them in ApiPath; otherwise a generic PATCH is used.
  Future<ApiResult<void>> setPublished(String id,
      {required bool published, CancelToken? cancelToken}) async {
    return ApiResult.guardFuture(() async {
      // Generic patch when explicit publish/unpublish endpoints aren't available.
      await _dio.patch(
        ApiPath.placeById(id),
        data: {'published': published},
        cancelToken: cancelToken,
      );
    });
  }

  /// Delete a place (Admin/Owner).
  Future<ApiResult<void>> delete(String id, {CancelToken? cancelToken}) async {
    return ApiResult.guardFuture(() async {
      await _dio.delete(ApiPath.placeById(id), cancelToken: cancelToken);
    });
  }

  // ---------------------------
  // Optional: cursor/offset paging
  // ---------------------------

  /// Fetch all results across pages using a simple loop (use with care).
  /// This is helpful for background sync or exports.
  Future<ApiResult<List<Place>>> listAll({
    String? category,
    String? emotion,
    String? q,
    double? lat,
    double? lng,
    int? radius,
    int startPage = 1,
    int pageSize = 50,
    int maxPages = 20,
    CancelToken? cancelToken,
  }) async {
    return ApiResult.guardFuture(() async {
      final out = <Place>[];
      var page = startPage;
      for (var i = 0; i < maxPages; i++) {
        final res = await _dio.get(
          AppConstants.apiPlaces,
          queryParameters: <String, dynamic>{
            if (category != null && category.isNotEmpty) 'category': category,
            if (emotion != null && emotion.isNotEmpty) 'emotion': emotion,
            if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
            if (radius != null) 'radius': radius,
            'page': page,
            'limit': pageSize,
          },
          cancelToken: cancelToken,
        );

        final root = res.data;
        final list = (root is Map && root['data'] is List)
            ? (root['data'] as List)
            : const <dynamic>[];
        if (list.isEmpty) break;

        out.addAll(list.map((j) => Place.fromJson(j as Map<String, dynamic>)));

        // stop if returned less than requested or meta indicates no next
        final returned = list.length;
        final hasNextMeta = (root is Map &&
            root['meta'] is Map &&
            ((root['meta']['hasNext'] == true) ||
                (root['meta']['nextPage'] != null)));
        if (returned < pageSize && !hasNextMeta) break;

        page += 1;
      }
      return out;
    });
  }
}

// lib/features/places/data/places_api.dart

// (imports moved to top to satisfy directive ordering)

/// Error model with a safe message, status and optional cause.
class ApiError implements Exception {
  ApiError(this.safeMessage, {this.status, this.cause});
  final String safeMessage;
  final int? status;
  final Object? cause;
  @override
  String toString() => 'ApiError($status): $safeMessage';
}

/// Result type for ergonomics.
abstract class Result<T> {
  const Result();
  R fold<R>(
      {required R Function(T data) onSuccess,
      required R Function(ApiError e) onError});
}

class Ok<T> extends Result<T> {
  const Ok(this.data);
  final T data;
  @override
  R fold<R>(
          {required R Function(T data) onSuccess,
          required R Function(ApiError e) onError}) =>
      onSuccess(data);
}

class Err<T> extends Result<T> {
  const Err(this.error);
  final ApiError error;
  @override
  R fold<R>(
          {required R Function(T data) onSuccess,
          required R Function(ApiError e) onError}) =>
      onError(error);
}

/// Supported providers for PlacesApi.
enum PlacesProvider { fsq, otm }

/// PlacesApi supports Foursquare Places (FSQ) and OpenTripMap (OTM) with
/// normalized outputs across search, details, and photos.
class PlacesApi {
  PlacesApi.foursquare({
    required this.fsqApiKey,
    this.client,
    this.timeout = const Duration(seconds: 15),
    this.fsqBase = 'https://api.foursquare.com',
  })  : provider = PlacesProvider.fsq,
        otmApiKey = null,
        otmBase = null,
        lang = null;

  PlacesApi.openTripMap({
    required this.otmApiKey,
    this.lang = 'en',
    this.client,
    this.timeout = const Duration(seconds: 15),
    this.otmBase = 'https://api.opentripmap.com/0.1',
  })  : provider = PlacesProvider.otm,
        fsqApiKey = null,
        fsqBase = null;

  final PlacesProvider provider;
  final http.Client? client;
  final Duration timeout;

  // FSQ config
  final String? fsqApiKey;
  final String? fsqBase;

  // OTM config
  final String? otmApiKey;
  final String? otmBase;
  final String? lang;

  http.Client get _c => client ?? http.Client();

  // -----------------------------
  // Search (nearby / text)
  // -----------------------------

  /// Nearby/text search with optional category filtering and pagination.
  ///
  /// Normalized list items contain:
  /// { id, name, category, address, city, region, country, lat, lng, rating?, openNow?, phone?, website?, photoUrl?, source, raw, cursor? }
  Future<Result<List<Map<String, dynamic>>>> search({
    required double lat,
    required double lng,
    String? query,
    List<String>? categories, // FSQ: category IDs; OTM: kinds (comma-separated)
    int radiusMeters = 4000,
    int limit = 20,
    String? cursor, // FSQ: cursor token; OTM: use offset if needed
  }) async {
    try {
      switch (provider) {
        case PlacesProvider.fsq:
          return await _fsqSearch(
            lat: lat,
            lng: lng,
            query: query,
            categories: categories,
            radiusMeters: radiusMeters,
            limit: limit,
            cursor: cursor,
          );
        case PlacesProvider.otm:
          return await _otmRadius(
            lat: lat,
            lng: lng,
            query: query,
            kinds: categories,
            radiusMeters: radiusMeters,
            limit: limit,
            offset: cursor != null ? int.tryParse(cursor) ?? 0 : 0,
          );
      }
    } catch (e) {
      return Err(ApiError('Unexpected error', cause: e));
    }
  }

  // -----------------------------
  // Details
  // -----------------------------

  /// Fetches detailed info for a place by its provider-specific id (FSQ fsq_id, OTM xid).
  ///
  /// Normalized object contains:
  /// { id, name, category, address, city, region, country, lat, lng, rating?, openNow?, phone?, website?, photoUrl?, description?, source, raw }
  Future<Result<Map<String, dynamic>>> details({required String id}) async {
    try {
      switch (provider) {
        case PlacesProvider.fsq:
          return await _fsqDetails(id: id);
        case PlacesProvider.otm:
          return await _otmDetails(xid: id);
      }
    } catch (e) {
      return Err(ApiError('Unexpected error', cause: e));
    }
  }

  // -----------------------------
  // Photos (optional convenience)
  // -----------------------------

  /// Returns a list of photo URLs for a place (best-effort).
  Future<Result<List<String>>> photos(
      {required String id, int limit = 5}) async {
    try {
      switch (provider) {
        case PlacesProvider.fsq:
          return await _fsqPhotos(fsqId: id, limit: limit);
        case PlacesProvider.otm:
          // OTM returns a single preview in details; fetch details and extract.
          final det = await _otmDetails(xid: id);
          return det.fold(
            onSuccess: (m) {
              final p = (m['photoUrl'] as String?);
              return Ok(p == null ? <String>[] : <String>[p]);
            },
            onError: (e) => Err(e),
          );
      }
    } catch (e) {
      return Err(ApiError('Unexpected error', cause: e));
    }
  }

  // ============================================================
  // FOURSQUARE (FSQ) IMPLEMENTATION
  // Docs: /v3/places/search, /v3/places/{id}, /v3/places/{id}/photos
  // ============================================================

  Map<String, String> _fsqHeaders() => {
        'Accept': 'application/json',
        'Authorization': fsqApiKey ?? '',
      };

  Uri _fsqU(String path, [Map<String, String>? q]) =>
      Uri.parse('${(fsqBase ?? '').replaceAll(RegExp(r"/$"), "")}$path')
          .replace(queryParameters: q);

  Future<Result<List<Map<String, dynamic>>>> _fsqSearch({
    required double lat,
    required double lng,
    String? query,
    List<String>? categories,
    int radiusMeters = 4000,
    int limit = 20,
    String? cursor,
  }) async {
    final params = <String, String>{
      'll': '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
      'radius': '$radiusMeters',
      'limit': '$limit',
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (categories != null && categories.isNotEmpty)
        'categories': categories.join(','),
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final res = await _c
        .get(_fsqU('/v3/places/search', params), headers: _fsqHeaders())
        .timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Err(_mapError(res).toApiError());
    }
    final json = jsonDecode(res.body);
    final results = (json is Map && json['results'] is List)
        ? List<Map<String, dynamic>>.from(json['results'])
        : <Map<String, dynamic>>[];
    final nextCursor = (json is Map &&
            json['context'] is Map &&
            (json['context']['next_cursor'] ?? '') is String)
        ? (json['context']['next_cursor'] as String)
        : null;
    final normalized = results
        .map((m) => _normFsqItem(m, nextCursor: nextCursor))
        .toList(growable: false);
    return Ok(normalized);
  } // Foursquare’s Place Search uses /v3/places/search with parameters like ll, radius, query, categories, limit and returns results plus optional next_cursor for pagination. [1][5]

  Future<Result<Map<String, dynamic>>> _fsqDetails({required String id}) async {
    final res = await _c
        .get(_fsqU('/v3/places/$id'), headers: _fsqHeaders())
        .timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Err(_mapError(res).toApiError());
    }
    final m = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    final normalized = _normFsqItem(m);
    // Try to fetch one photo for convenience (non-blocking if it fails)
    try {
      final ph = await _fsqPhotos(fsqId: id, limit: 1);
      ph.fold(
        onSuccess: (list) {
          if (list.isNotEmpty) normalized['photoUrl'] = list.first;
        },
        onError: (_) {},
      );
    } catch (_) {}
    return Ok(normalized);
  } // Place Details on FSQ is /v3/places/{fsq_id} and returns comprehensive information like address, contact, and hours. [5][2]

  Future<Result<List<String>>> _fsqPhotos(
      {required String fsqId, int limit = 5}) async {
    final params = <String, String>{'limit': '${limit.clamp(1, 50)}'};
    final res = await _c
        .get(_fsqU('/v3/places/$fsqId/photos', params), headers: _fsqHeaders())
        .timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Err(_mapError(res).toApiError());
    }
    final arr = jsonDecode(res.body);
    final photos = (arr is List
            ? arr.cast<Map<String, dynamic>>()
            : const <Map<String, dynamic>>[])
        .map((p) {
          final prefix = (p['prefix'] ?? '').toString();
          final suffix = (p['suffix'] ?? '').toString();
          if (prefix.isEmpty || suffix.isEmpty) return null;
          // 800x800 example size; FSQ supports a size token between prefix and suffix.
          return '${prefix}800x800$suffix';
        })
        .whereType<String>()
        .toList(growable: false);
    return Ok(photos);
  } // FSQ photos are returned from /v3/places/{id}/photos as prefix/suffix pairs; clients compose URLs by inserting a size token between them. [5][8]

  Map<String, dynamic> _normFsqItem(Map<String, dynamic> m,
      {String? nextCursor}) {
    T? getIn<T>(Map obj, List parts) {
      dynamic cur = obj;
      for (final p in parts) {
        if (cur is Map && cur[p] != null) {
          cur = cur[p];
        } else {
          return null;
        }
      }
      return cur as T?;
    }

    String? category() {
      final cats = (m['categories'] is List)
          ? List<Map<String, dynamic>>.from(m['categories'])
          : const <Map<String, dynamic>>[];
      if (cats.isEmpty) return null;
      return (cats.first['name'] ??
              cats.first['short_name'] ??
              cats.first['id'] ??
              '')
          .toString();
    }

    final lat = getIn<num>(m, ['geocodes', 'main', 'latitude'])?.toDouble() ??
        getIn<num>(m, ['geocodes', 'roof', 'latitude'])?.toDouble();
    final lng = getIn<num>(m, ['geocodes', 'main', 'longitude'])?.toDouble() ??
        getIn<num>(m, ['geocodes', 'roof', 'longitude'])?.toDouble();

    final loc = (m['location'] is Map)
        ? (m['location'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final address = (loc['formatted_address'] ?? '').toString();
    final city = (loc['locality'] ?? '').toString();
    final region = (loc['region'] ?? '').toString();
    final country = (loc['country'] ?? '').toString();

    return {
      'id': (m['fsq_id'] ?? '').toString(),
      'name': (m['name'] ?? '').toString(),
      'category': category(),
      'address': address.isEmpty ? null : address,
      'city': city.isEmpty ? null : city,
      'region': region.isEmpty ? null : region,
      'country': country.isEmpty ? null : country,
      'lat': lat,
      'lng': lng,
      'rating': m[
          'rating'], // may be absent; FSQ sometimes exposes rating for select corp tiers
      'openNow': getIn<bool>(m, ['hours', 'is_open']),
      'phone': (m['tel'] ?? m['phone'] ?? '').toString().isEmpty
          ? null
          : (m['tel'] ?? m['phone']).toString(),
      'website': (m['website'] ?? '').toString().isEmpty
          ? null
          : m['website'].toString(),
      'photoUrl': null, // populated via photos()
      'source': 'fsq',
      'cursor': nextCursor,
      'raw': m,
    };
  }

  // ============================================================
  // OPENTRIPMAP (OTM) IMPLEMENTATION
  // Docs: places/radius, places/autosuggest, places/xid/{xid}
  // ============================================================

  Map<String, String> _otmHeaders() => {
        'Accept': 'application/json',
      };

  Uri _otmU(String path, [Map<String, String>? q]) {
    final base = (otmBase ?? '').replaceAll(RegExp(r"/$"), "");
    final langSeg = '/${(lang ?? 'en').trim()}';
    return Uri.parse('$base$langSeg$path').replace(queryParameters: q);
  }

  Future<Result<List<Map<String, dynamic>>>> _otmRadius({
    required double lat,
    required double lng,
    String? query,
    List<String>? kinds,
    int radiusMeters = 4000,
    int limit = 20,
    int offset = 0,
  }) async {
    // Prefer the radius endpoint; for text bias, combine with name filter when present.
    final params = <String, String>{
      'apikey': otmApiKey ?? '',
      'radius': '$radiusMeters',
      'lon': lng.toString(),
      'lat': lat.toString(),
      'limit': '$limit',
      'offset': '$offset',
      'format': 'json',
      'rate': '2', // prefer notable places
      if (kinds != null && kinds.isNotEmpty) 'kinds': kinds.join(','),
      if (query != null && query.trim().isNotEmpty) 'name': query.trim(),
    };
    final res = await _c
        .get(_otmU('/places/radius', params), headers: _otmHeaders())
        .timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Err(_mapError(res).toApiError());
    }
    final data = jsonDecode(res.body);
    final list = (data is List)
        ? data.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];
    final normalized = list.map(_normOtmRadiusItem).toList(growable: false);
    return Ok(normalized);
  } // OpenTripMap supports a “Place list” via /places/radius with filters like kinds, rate, radius, limit, offset, and returns JSON objects with coordinates and basic fields. [6]

  Future<Result<Map<String, dynamic>>> _otmDetails(
      {required String xid}) async {
    final params = <String, String>{'apikey': otmApiKey ?? ''};
    final res = await _c
        .get(_otmU('/places/xid/$xid', params), headers: _otmHeaders())
        .timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Err(_mapError(res).toApiError());
    }
    final m = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    final normalized = _normOtmDetail(m);
    return Ok(normalized);
  } // OpenTripMap Place Details are fetched via /places/xid/{xid} and include address, description, preview image, url, and more. [6]

  Map<String, dynamic> _normOtmRadiusItem(Map<String, dynamic> m) {
    // shape fields:
    // { xid, name, dist, point:{lon,lat}, kinds, rate }
    final point = (m['point'] is Map)
        ? (m['point'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final kinds = (m['kinds'] ?? '').toString();
    String? firstKind() {
      if (kinds.isEmpty) return null;
      final k = kinds.split(',').first.trim();
      return k.isEmpty ? null : k;
    }

    return {
      'id': (m['xid'] ?? '').toString(),
      'name': (m['name'] ?? '').toString(),
      'category': firstKind(),
      'address': null,
      'city': null,
      'region': null,
      'country': null,
      'lat': (point['lat'] is num) ? (point['lat'] as num).toDouble() : null,
      'lng': (point['lon'] is num) ? (point['lon'] as num).toDouble() : null,
      'rating': m['rate'] is num ? (m['rate'] as num).toDouble() : null,
      'openNow': null,
      'phone': null,
      'website': null,
      'photoUrl': null, // populated via details preview if needed
      'source': 'otm',
      'raw': m,
    };
  }

  Map<String, dynamic> _normOtmDetail(Map<String, dynamic> m) {
    // Example fields: xid, name, address:{city,state,country}, point:{lon,lat}, wikipedia, image|preview:{source}, rate, kinds, info:descr, otm, url
    T? getIn<T>(Map obj, List parts) {
      dynamic cur = obj;
      for (final p in parts) {
        if (cur is Map && cur[p] != null) {
          cur = cur[p];
        } else {
          return null;
        }
      }
      return cur as T?;
    }

    final lat = getIn<num>(m, ['point', 'lat'])?.toDouble();
    final lng = getIn<num>(m, ['point', 'lon'])?.toDouble();

    final addr = (m['address'] is Map)
        ? (m['address'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final address =
        (addr['road'] ?? addr['house_number'] ?? '').toString().trim();
    final city =
        (addr['city'] ?? addr['town'] ?? addr['village'] ?? '').toString();
    final region = (addr['state'] ?? addr['region'] ?? '').toString();
    final country = (addr['country'] ?? '').toString();

    final photo =
        getIn<String>(m, ['image']) ?? getIn<String>(m, ['preview', 'source']);

    String? category() {
      final kinds = (m['kinds'] ?? '').toString();
      if (kinds.isEmpty) return null;
      return kinds.split(',').first.trim();
    }

    final desc = getIn<String>(m, ['wikipedia_extracts', 'text']) ??
        getIn<String>(m, ['info', 'descr']);

    return {
      'id': (m['xid'] ?? '').toString(),
      'name': (m['name'] ?? '').toString(),
      'category': category(),
      'address': address.isEmpty ? null : address,
      'city': city.isEmpty ? null : city,
      'region': region.isEmpty ? null : region,
      'country': country.isEmpty ? null : country,
      'lat': lat,
      'lng': lng,
      'rating': (m['rate'] is num) ? (m['rate'] as num).toDouble() : null,
      'openNow': null,
      'phone': null,
      'website': (m['url'] ?? m['otm'] ?? '').toString().isEmpty
          ? null
          : (m['url'] ?? m['otm']).toString(),
      'photoUrl': (photo ?? '').isEmpty ? null : photo,
      'description': (desc ?? '').isEmpty ? null : desc,
      'source': 'otm',
      'raw': m,
    };
  }

  // -----------------------------
  // Error mapping
  // -----------------------------

  _HttpError _mapError(http.Response res) {
    String msg = 'HTTP ${res.statusCode}';
    try {
      final json = jsonDecode(res.body);
      if (json is Map && json['error'] != null) {
        final e = json['error'];
        if (e is Map && e['message'] is String) msg = e['message'] as String;
        if (e is String) msg = e;
      }
    } catch (_) {
      // keep default
    }
    return _HttpError(status: res.statusCode, message: msg, body: res.body);
  }
}

class _HttpError {
  _HttpError({required this.status, required this.message, this.body});
  final int status;
  final String message;
  final String? body;
  Err<T> toApiError<T>() => Err<T>(ApiError(message, status: status));
}
