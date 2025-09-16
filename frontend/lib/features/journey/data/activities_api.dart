// lib/features/journey/data/activities_api.dart

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/config/constants.dart';

/// Data source for journey activities: listing, details, availability, and booking. [2]
class ActivitiesApi {
  ActivitiesApi() : _dio = DioClient.instance.dio;

  final Dio _dio;

  /// GET /api/activities with rich filters (geo/category/price/duration/tags/search). [2]
  Future<ApiResult<Map<String, dynamic>>> listActivities({
    int page = 1,
    int limit = AppConstants.pageSize,
    String? q,
    String? category,
    String? emotion,
    List<String>? tags,
    double? minPrice,
    double? maxPrice,
    int? minDurationMinutes,
    int? maxDurationMinutes,
    String? region,
    String? placeId,
    // location-aware
    double? lat,
    double? lng,
    double? radiusKm,
    // sorting: popular, rating_desc, price_asc, new
    String? sort,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (q != null && q.isNotEmpty) 'q': q,
        if (category != null && category.isNotEmpty) 'category': category,
        if (emotion != null && emotion.isNotEmpty) 'emotion': emotion,
        if (tags != null && tags.isNotEmpty) 'tags': tags.join(','), // arrays as csv [3]
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (minDurationMinutes != null) 'min_duration': minDurationMinutes,
        if (maxDurationMinutes != null) 'max_duration': maxDurationMinutes,
        if (region != null && region.isNotEmpty) 'region': region,
        if (placeId != null && placeId.isNotEmpty) 'placeId': placeId,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusKm != null) 'radius_km': radiusKm,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
      };
      final res = await _dio.get(AppConstants.apiActivities, queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Builds queryParameters per Dio GET usage and URL rules for primitives/strings [11][1].

  /// GET /api/activities/:id detail. [2]
  Future<ApiResult<Map<String, dynamic>>> getActivityById(String id) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiActivities}/$id');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Standard REST resource fetch using shared Dio client [2].

  /// GET /api/activities (nearby only): requires lat/lng, optional radius/limit. [2]
  Future<ApiResult<List<Map<String, dynamic>>>> nearbyActivities({
    required double lat,
    required double lng,
    double radiusKm = AppConstants.defaultNearbyRadiusKm,
    int limit = AppConstants.pageSize,
    List<String>? categories,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'limit': limit,
        if (categories != null && categories.isNotEmpty) 'categories': categories.join(','), // csv array [3]
      };
      final res = await _dio.get(AppConstants.apiActivities, queryParameters: qp);
      final data = _asList(res.data);
      return data;
    });
  } // Query composition mirrors Dio examples for GET with queryParameters [21][11].

  /// GET /api/activities/:id/availability?date=YYYY-MM-DD&participants=2. [2]
  Future<ApiResult<Map<String, dynamic>>> availability({
    required String activityId,
    required String date, // ISO date (YYYY-MM-DD)
    int participants = 1,
    String? slot, // optional time slot code
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'date': date,
        'participants': participants,
        if (slot != null && slot.isNotEmpty) 'slot': slot,
      };
      final res =
          await _dio.get('${AppConstants.apiActivities}/$activityId/availability', queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Availability uses GET with filters per REST search conventions [7].

  /// POST /api/activities/:id/book with payload { traveler, schedule, payment }. [2]
  Future<ApiResult<Map<String, dynamic>>> bookActivity({
    required String activityId,
    required Map<String, dynamic> payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiActivities}/$activityId/book', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Booking uses POST with JSON body and leverages interceptors for auth headers [2].

  // ---------- Helpers ----------

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return const <Map<String, dynamic>>[];
  } // Accepts common {data: [...]} or plain array responses for flexibility at call sites [8].
}
