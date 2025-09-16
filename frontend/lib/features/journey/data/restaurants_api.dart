// lib/features/journey/data/restaurants_api.dart

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/config/constants.dart';

/// Restaurants data source: listing/search, detail, availability, reservation flows, reviews, and nearby. [21]
class RestaurantsApi {
  RestaurantsApi() : _dio = DioClient.instance.dio;

  final Dio _dio;

  // ---------- Search / Listing ----------

  /// GET /api/restaurants with geo/text filters and facets. [8]
  /// Filters:
  /// - location: city/region OR lat/lng (+ radius_km)
  /// - cuisine/tags/dietary: csv arrays
  /// - priceRange: min_price/max_price; rating; openNow; sort; pagination
  Future<ApiResult<Map<String, dynamic>>> search({
    // location
    String? city,
    String? region,
    double? lat,
    double? lng,
    double? radiusKm,

    // query
    String? q,

    // facets
    List<String>? cuisine, // e.g., indian, italian
    List<String>? tags, // e.g., romantic, family, fine-dining
    List<String>? dietary, // e.g., veg, vegan, halal, gluten-free

    // numeric filters
    double? minPrice,
    double? maxPrice,
    double? minRating,

    // time filter
    bool? openNow,

    // sort/paging
    String? sort, // rating_desc | price_asc | distance_asc | popular | new
    int page = 1,
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        if (city != null && city.isNotEmpty) 'city': city,
        if (region != null && region.isNotEmpty) 'region': region,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusKm != null) 'radius_km': radiusKm,
        if (q != null && q.isNotEmpty) 'q': q,
        if (cuisine != null && cuisine.isNotEmpty) 'cuisine': cuisine.join(','), // csv arrays [4]
        if (tags != null && tags.isNotEmpty) 'tags': tags.join(','), // csv arrays [4]
        if (dietary != null && dietary.isNotEmpty) 'dietary': dietary.join(','), // csv arrays [4]
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (minRating != null) 'min_rating': minRating,
        if (openNow != null) 'open_now': openNow,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        'page': page,
        'limit': limit,
      };
      final res = await _dio.get(AppConstants.apiRestaurants, queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Encodes arrays as comma-separated values and passes primitives via queryParameters as recommended for Dio GET [22][1].

  /// GET /api/restaurants/:id [8]
  Future<ApiResult<Map<String, dynamic>>> getById(String id) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiRestaurants}/$id');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Standard details endpoint leveraging shared Dio base configuration [21].

  /// GET /api/restaurants/nearby?lat=&lng=&radius_km=&cuisine=indian,vegan&limit=20 [8]
  Future<ApiResult<List<Map<String, dynamic>>>> nearby({
    required double lat,
    required double lng,
    double radiusKm = AppConstants.defaultNearbyRadiusKm,
    int limit = AppConstants.pageSize,
    List<String>? cuisine,
    List<String>? dietary,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'limit': limit,
        if (cuisine != null && cuisine.isNotEmpty) 'cuisine': cuisine.join(','), // csv arrays [4]
        if (dietary != null && dietary.isNotEmpty) 'dietary': dietary.join(','), // csv arrays [4]
      };
      final res = await _dio.get('${AppConstants.apiRestaurants}/nearby', queryParameters: qp);
      return _asList(res.data);
    });
  } // Geo list aligns with Home APIs and keeps params cache-friendly in the URL [8].

  // ---------- Availability / Reservations ----------

  /// GET /api/restaurants/:id/availability?date=YYYY-MM-DD&time=HH:mm&guests=2 [6]
  Future<ApiResult<Map<String, dynamic>>> availability({
    required String id,
    required String date, // YYYY-MM-DD
    String? time, // HH:mm optional to filter slots
    int guests = 2,
    String? area, // seating preference code (indoor/outdoor/window)
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'date': date,
        'guests': guests,
        if (time != null && time.isNotEmpty) 'time': time,
        if (area != null && area.isNotEmpty) 'area': area,
      };
      final res = await _dio.get('${AppConstants.apiRestaurants}/$id/availability', queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Mirrors common restaurant-availability patterns (time slots, party size, preference) [6][18].

  /// POST /api/restaurants/:id/reservations { date, time, guests, guest:{name,phone,email}, notes?, area? } [6]
  Future<ApiResult<Map<String, dynamic>>> createReservation({
    required String id,
    required Map<String, dynamic> payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiRestaurants}/$id/reservations', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Reservation POST structure compatible with typical partner APIs (guest contact + preferences) [6][12].

  /// POST /api/restaurants/reservations/:reservationId/cancel { reason? } [12]
  Future<ApiResult<Map<String, dynamic>>> cancelReservation({
    required String reservationId,
    String? reason,
  }) {
    return ApiResult.guardFuture(() async {
      final body = <String, dynamic>{if (reason != null && reason.isNotEmpty) 'reason': reason};
      final res = await _dio.post('${AppConstants.apiRestaurants}/reservations/$reservationId/cancel', data: body);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Uses POST to carry metadata (reason) while keeping idempotency at the backend [12].

  /// GET /api/restaurants/reservations/:reservationId/status [12]
  Future<ApiResult<Map<String, dynamic>>> reservationStatus(String reservationId) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiRestaurants}/reservations/$reservationId/status');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Status polling endpoint to drive UI updates during/after booking [12][15].

  // ---------- Reviews ----------

  /// GET /api/restaurants/:id/reviews?page=&limit=&sort=recent|rating_desc [8]
  Future<ApiResult<Map<String, dynamic>>> reviews({
    required String id,
    int page = 1,
    int limit = AppConstants.pageSize,
    String? sort,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
      };
      final res = await _dio.get('${AppConstants.apiRestaurants}/$id/reviews', queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Paginates reviews through queryParameters to keep UI simple and performant with ListViews [8].

  // ---------- Helpers ----------

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return const <Map<String, dynamic>>[];
  } // Accepts both {data:[...]} and raw arrays to avoid brittle parsing [8].
}
