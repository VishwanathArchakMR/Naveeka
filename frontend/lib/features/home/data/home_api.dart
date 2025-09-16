// lib/features/home/data/home_api.dart

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/config/constants.dart';

/// Location-aware data source for the Home screen sections. [2]
class HomeApi {
  HomeApi() : _dio = DioClient.instance.dio;

  final Dio _dio;

  /// Nearby places using lat/lng and optional radiusKm (km). [2]
  Future<ApiResult<List<Map<String, dynamic>>>> nearbyPlaces({
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
        if (categories != null && categories.isNotEmpty) 'categories': categories.join(','),
      };
      final res = await _dio.get(AppConstants.apiPlaces, queryParameters: qp);
      final data = _asList(res.data);
      return data;
    });
  } // [2][4]

  /// Nearby hotels with the same geo filter semantics. [2]
  Future<ApiResult<List<Map<String, dynamic>>>> nearbyHotels({
    required double lat,
    required double lng,
    double radiusKm = AppConstants.defaultNearbyRadiusKm,
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'limit': limit,
      };
      final res = await _dio.get(AppConstants.apiHotels, queryParameters: qp);
      final data = _asList(res.data);
      return data;
    });
  } // [2][8]

  /// Nearby restaurants with geo filter. [2]
  Future<ApiResult<List<Map<String, dynamic>>>> nearbyRestaurants({
    required double lat,
    required double lng,
    double radiusKm = AppConstants.defaultNearbyRadiusKm,
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'limit': limit,
      };
      final res = await _dio.get(AppConstants.apiRestaurants, queryParameters: qp);
      final data = _asList(res.data);
      return data;
    });
  } // [2][1]

  /// Trending places (optionally location-biased if lat/lng provided). [2]
  Future<ApiResult<List<Map<String, dynamic>>>> trendingPlaces({
    double? lat,
    double? lng,
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'sort': 'trending',
        'limit': limit,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
      final res = await _dio.get(AppConstants.apiPlaces, queryParameters: qp);
      final data = _asList(res.data);
      return data;
    });
  } // [2][11]

  /// "What's new" feed of recently added places. [2]
  Future<ApiResult<List<Map<String, dynamic>>>> whatsNew({
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'sort': 'new',
        'limit': limit,
      };
      final res = await _dio.get(AppConstants.apiPlaces, queryParameters: qp);
      final data = _asList(res.data);
      return data;
    });
  } // [2][8]

  /// Explore by region (e.g., state/country/region code or name). [2]
  Future<ApiResult<List<Map<String, dynamic>>>> exploreByRegion({
    required String region,
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'region': region,
        'limit': limit,
      };
      final res = await _dio.get(AppConstants.apiPlaces, queryParameters: qp);
      final data = _asList(res.data);
      return data;
    });
  } // [2][4]

  /// Top hotels near a location (sorted by rating or popularity). [2]
  Future<ApiResult<List<Map<String, dynamic>>>> topHotelsNear({
    required double lat,
    required double lng,
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'sort': 'rating_desc',
        'limit': limit,
      };
      final res = await _dio.get(AppConstants.apiHotels, queryParameters: qp);
      final data = _asList(res.data);
      return data;
    });
  } // [2][8]

  // ---------- Helpers ----------

  List<Map<String, dynamic>> _asList(dynamic data) {
    // Accepts either { data: [...] } or plain [...].
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return const <Map<String, dynamic>>[];
  } // Supports common API shapes and avoids crashes on unexpected payloads. [7]
}
