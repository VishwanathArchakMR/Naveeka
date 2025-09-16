// lib/features/journey/data/hotels_api.dart

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/config/constants.dart';

/// Hotels data source: search/listing, details, availability/rates, price quote, booking, status, cancel, reviews. [1]
class HotelsApi {
  HotelsApi() : _dio = DioClient.instance.dio;

  final Dio _dio;

  // ---------- Search / Listing ----------

  /// GET /api/hotels with filters for geo/city and stay params.
  /// Supports city/region OR lat/lng (+ radius), plus stars/amenities/price/sort/pagination. [3][4]
  Future<ApiResult<Map<String, dynamic>>> search({
    // Location selectors
    String? city, // e.g., "Bengaluru" or city code/slug
    String? region, // e.g., "Karnataka" or "India"
    double? lat,
    double? lng,
    double? radiusKm,

    // Stay params
    required String checkIn, // YYYY-MM-DD
    required String checkOut, // YYYY-MM-DD
    int rooms = 1,
    int adults = 2,
    int children = 0,
    List<int>? childrenAges,

    // Filters
    List<int>? stars, // [3,4,5]
    List<String>? amenities, // ["wifi","pool","spa"]
    double? minPrice,
    double? maxPrice,
    String? q, // free text
    String? sort, // price_asc | rating_desc | distance_asc | popular

    // Paging
    int page = 1,
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        // Loc
        if (city != null && city.isNotEmpty) 'city': city,
        if (region != null && region.isNotEmpty) 'region': region,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusKm != null) 'radius_km': radiusKm,

        // Stay
        'checkIn': checkIn,
        'checkOut': checkOut,
        'rooms': rooms,
        'adults': adults,
        if (children > 0) 'children': children,
        if (childrenAges != null && childrenAges.isNotEmpty)
          'childrenAges': childrenAges.join(','), // csv arrays [5]

        // Filters
        if (stars != null && stars.isNotEmpty) 'stars': stars.join(','), // csv arrays [5]
        if (amenities != null && amenities.isNotEmpty) 'amenities': amenities.join(','), // csv arrays [5]
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (q != null && q.isNotEmpty) 'q': q,
        if (sort != null && sort.isNotEmpty) 'sort': sort,

        // Paging
        'page': page,
        'limit': limit,
      };

      final res = await _dio.get(AppConstants.apiHotels, queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Encodes filters via queryParameters and uses csv for arrays to be REST-friendly with Dio [3][5].

  /// GET /api/hotels/top?limit=… (optional helper to fetch top-rated/featured)
  Future<ApiResult<List<Map<String, dynamic>>>> topRated({
    int limit = AppConstants.pageSize,
    double? lat,
    double? lng,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'limit': limit,
        'sort': 'rating_desc',
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
      final res = await _dio.get(AppConstants.apiHotels, queryParameters: qp);
      return _asList(res.data);
    });
  } // Mirrors nearby/top usage seen on Home while staying on the same base endpoint [4].

  // ---------- Details / Availability / Rates ----------

  /// GET /api/hotels/:id
  Future<ApiResult<Map<String, dynamic>>> getById(String id) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiHotels}/$id');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Standard details endpoint through shared Dio client [1].

  /// GET /api/hotels/:id/availability?checkIn=YYYY-MM-DD&checkOut=YYYY-MM-DD&rooms=1&adults=2&children=1&childrenAges=5
  Future<ApiResult<Map<String, dynamic>>> availability({
    required String id,
    required String checkIn,
    required String checkOut,
    int rooms = 1,
    int adults = 2,
    int children = 0,
    List<int>? childrenAges,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'checkIn': checkIn,
        'checkOut': checkOut,
        'rooms': rooms,
        'adults': adults,
        if (children > 0) 'children': children,
        if (childrenAges != null && childrenAges.isNotEmpty)
          'childrenAges': childrenAges.join(','), // csv arrays [5]
      };
      final res = await _dio.get('${AppConstants.apiHotels}/$id/availability', queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Availability as GET with queryParameters to keep it cache-friendly and idempotent [3][4].

  /// GET /api/hotels/:id/rate-plans?checkIn=…&checkOut=… (optional helper to show room/rate options)
  Future<ApiResult<Map<String, dynamic>>> ratePlans({
    required String id,
    required String checkIn,
    required String checkOut,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'checkIn': checkIn,
        'checkOut': checkOut,
      };
      final res = await _dio.get('${AppConstants.apiHotels}/$id/rate-plans', queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Returns room types/rate plans so UI can render choices before pricing/booking [4].

  // ---------- Pricing / Booking ----------

  /// POST /api/hotels/:id/price { currency?, rooms:[{ratePlanId, roomTypeId, guests, extras?}], promo? }
  Future<ApiResult<Map<String, dynamic>>> priceQuote({
    required String id,
    required Map<String, dynamic> payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiHotels}/$id/price', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Price a selection (locks current rates/taxes/fees) before booking; POST carries structured selection [4].

  /// POST /api/hotels/orders { hotelId, stay:{checkIn,checkOut}, rooms:[...], guests:[...], contact:{...}, payment:{...} }
  Future<ApiResult<Map<String, dynamic>>> createOrder({
    required Map<String, dynamic> payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiHotels}/orders', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Booking as POST with normalized order body; uses interceptors for Authorization header [1].

  /// GET /api/hotels/orders/:id/status
  Future<ApiResult<Map<String, dynamic>>> orderStatus(String orderId) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiHotels}/orders/$orderId/status');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Status polling for order screens; consistent with Result-based consumption in UI [2].

  /// POST /api/hotels/orders/:id/cancel { reason? }
  Future<ApiResult<Map<String, dynamic>>> cancelOrder({
    required String orderId,
    String? reason,
  }) {
    return ApiResult.guardFuture(() async {
      final body = <String, dynamic>{
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      };
      final res = await _dio.post('${AppConstants.apiHotels}/orders/$orderId/cancel', data: body);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Cancellation endpoint modeled as POST to carry optional reason/object, with unified error handling [2].

  // ---------- Reviews / Media ----------

  /// GET /api/hotels/:id/reviews?page=&limit=
  Future<ApiResult<Map<String, dynamic>>> reviews({
    required String id,
    int page = 1,
    int limit = AppConstants.pageSize,
    String? sort, // recent | rating_desc
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
      };
      final res = await _dio.get('${AppConstants.apiHotels}/$id/reviews', queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Paginates reviews via queryParameters for predictable UI loading and caching [3].

  // ---------- Helpers ----------

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return const <Map<String, dynamic>>[];
  } // Accepts both {data:[...]} and raw arrays to avoid brittle parsing at call sites [4].
}
