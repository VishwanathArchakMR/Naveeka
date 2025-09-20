// lib/features/wishlist/data/wishlist_api.dart

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../models/place.dart';
import '../../../core/config/constants.dart';

/// Optional in-memory ETag store for conditional GET.
class _EtagStore {
  String? list; // ETag for GET /wishlist
}

/// Optional in-memory cache for list endpoint (used when server returns 304 Not Modified).
class _MemCache {
  List<Place>? listItems;
}

/// Paged response for cursor-based list APIs.
class WishlistPage {
  const WishlistPage({required this.items, this.nextCursor});

  final List<Place> items;
  final String? nextCursor;
}

/// Handles wishlist-related API calls.
class WishlistApi {
  WishlistApi({Dio? dio})
      : _dio = dio ?? DioClient.instance.dio,
        _etags = _EtagStore(),
        _cache = _MemCache();

  final Dio _dio;
  final _EtagStore _etags;
  final _MemCache _cache;

  Map<String, String> get _baseHeaders => const {
        'accept': 'application/json',
      };

  /// Get all wishlist items for current user using conditional GET (ETag).
  Future<ApiResult<List<Place>>> list({bool useConditionalGet = true}) async {
    return ApiResult.guardFuture(() async {
      final headers = {
        ..._baseHeaders,
        if (useConditionalGet && (_etags.list ?? '').isNotEmpty) 'If-None-Match': _etags.list!,
      };

      try {
        final res = await _dio.get(
          AppConstants.apiWishlist,
          options: Options(headers: headers),
        );

        // If server supports ETag and returns a new one, update store.
        final et = res.headers.value('etag');
        if (et != null && et.isNotEmpty) {
          _etags.list = et;
        }

        // Parse list payload.
        final data = (res.data['data'] as List?) ?? const <dynamic>[];
        final items = data.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList(growable: false);

        // Cache for potential 304 on next call.
        _cache.listItems = items;
        return items;
      } on DioException catch (e) {
        // If server responded 304 Not Modified and we have cached items, treat as success.
        if (e.response?.statusCode == 304 && (_cache.listItems != null)) {
          return _cache.listItems!;
        }
        rethrow;
      }
    });
  }

  /// Cursor-paginated list; returns items plus nextCursor when available.
  Future<ApiResult<WishlistPage>> listPage({int limit = 20, String? cursor}) async {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get(
        AppConstants.apiWishlist,
        queryParameters: <String, dynamic>{
          'limit': limit,
          if ((cursor ?? '').isNotEmpty) 'cursor': cursor,
        },
        options: Options(headers: _baseHeaders),
      );

      final data = res.data as Map<String, dynamic>? ?? const <String, dynamic>{};
      final raw = (data['data'] as List?) ?? (data['items'] as List?) ?? const <dynamic>[];
      final items = raw.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList(growable: false);
      final next = data['nextCursor'] as String?;

      return WishlistPage(items: items, nextCursor: next);
    });
  }

  /// Add a place to wishlist (idempotent server-side recommended).
  Future<ApiResult<void>> add(String placeId, {String? notes}) async {
    return ApiResult.guardFuture(() async {
      await _dio.post(
        '${AppConstants.apiWishlist}/$placeId',
        data: <String, dynamic>{
          if ((notes ?? '').isNotEmpty) 'notes': notes,
        },
        options: Options(headers: _baseHeaders),
      );
      _cache.listItems = null;
    });
  }

  /// Remove a place from wishlist.
  Future<ApiResult<void>> remove(String placeId) async {
    return ApiResult.guardFuture(() async {
      await _dio.delete(
        '${AppConstants.apiWishlist}/$placeId',
        options: Options(headers: _baseHeaders),
      );
      _cache.listItems = null;
    });
  }

  /// Toggle wishlist membership; next=true adds, false removes.
  Future<ApiResult<void>> toggle(String placeId, {required bool next, String? notes}) async {
    return next ? add(placeId, notes: notes) : remove(placeId);
  }

  /// Batch add multiple places (if backend supports it).
  Future<ApiResult<void>> addMany(List<String> placeIds, {String? notes}) async {
    return ApiResult.guardFuture(() async {
      await _dio.post(
        '${AppConstants.apiWishlist}/batch',
        data: <String, dynamic>{
          'ids': placeIds,
          if ((notes ?? '').isNotEmpty) 'notes': notes,
        },
        options: Options(headers: _baseHeaders),
      );
      _cache.listItems = null;
    });
  }

  /// Batch remove multiple places (if backend supports it).
  Future<ApiResult<void>> removeMany(List<String> placeIds) async {
    return ApiResult.guardFuture(() async {
      await _dio.delete(
        '${AppConstants.apiWishlist}/batch',
        data: <String, dynamic>{'ids': placeIds},
        options: Options(headers: _baseHeaders),
      );
      _cache.listItems = null;
    });
  }

  /// Update personal notes for a place on the wishlist.
  Future<ApiResult<void>> updateNotes(String placeId, String notes) async {
    return ApiResult.guardFuture(() async {
      await _dio.patch(
        '${AppConstants.apiWishlist}/$placeId',
        data: <String, dynamic>{'notes': notes},
        options: Options(headers: _baseHeaders),
      );
      _cache.listItems = null;
    });
  }

  /// Reorder the wishlist explicitly by ordered ID list (if backend supports it).
  Future<ApiResult<void>> reorder(List<String> orderedPlaceIds) async {
    return ApiResult.guardFuture(() async {
      await _dio.put(
        '${AppConstants.apiWishlist}/order',
        data: <String, dynamic>{'order': orderedPlaceIds},
        options: Options(headers: _baseHeaders),
      );
      _cache.listItems = null;
    });
  }

  /// Return total count if available at /wishlist/count.
  Future<ApiResult<int>> count() async {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get(
        '${AppConstants.apiWishlist}/count',
        options: Options(headers: _baseHeaders),
      );
      return (res.data['count'] as num).toInt();
    });
  }

  /// Check if a place is in the wishlist, preferring HEAD and falling back to GET.
  Future<ApiResult<bool>> exists(String placeId) async {
    return ApiResult.guardFuture(() async {
      try {
        final res = await _dio.head(
          '${AppConstants.apiWishlist}/$placeId',
          options: Options(headers: _baseHeaders, validateStatus: (code) => code != null && code < 500),
        );
        if (res.statusCode == 200 || res.statusCode == 204) return true;
        if (res.statusCode == 404) return false;
      } catch (_) {
        final res = await _dio.get(
          '${AppConstants.apiWishlist}/$placeId',
          options: Options(
            headers: _baseHeaders,
            validateStatus: (code) => code != null && code < 500,
          ),
        );
        if (res.statusCode == 200) return true;
        if (res.statusCode == 404) return false;
      }
      return false;
    });
  }
}
