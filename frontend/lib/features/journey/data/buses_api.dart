// lib/features/journey/data/buses_api.dart

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/config/constants.dart';

/// Bus journeys data source: search, details, seat maps, fares/availability, booking, and cancellation. [Dio]
class BusesApi {
  BusesApi() : _dio = DioClient.instance.dio;

  final Dio _dio;

  /// Search buses with common filters.
  /// GET /api/buses/search?from=BLR&to=MAD&date=2025-09-12&operators=VRL,SRS&classes=SLEEPER,SEMI
  Future<ApiResult<Map<String, dynamic>>> search({
    required String fromCode, // city/station code or slug
    required String toCode,
    required String date, // YYYY-MM-DD
    String? returnDate, // optional round trip
    List<String>? operators, // operator codes/names
    List<String>? classes, // e.g., SLEEPER, SEATER, SEMI
    String? q, // free-text query
    double? minPrice,
    double? maxPrice,
    String? sort, // price_asc, departure_asc, rating_desc
    int page = 1,
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'from': fromCode,
        'to': toCode,
        'date': date,
        if (returnDate != null && returnDate.isNotEmpty) 'returnDate': returnDate,
        if (operators != null && operators.isNotEmpty) 'operators': operators.join(','), // csv array
        if (classes != null && classes.isNotEmpty) 'classes': classes.join(','), // csv array
        if (q != null && q.isNotEmpty) 'q': q,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        'page': page,
        'limit': limit,
      };
      final res = await _dio.get(AppConstants.apiBusesSearch, queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// Retrieve bus trip details by id.
  /// GET /api/buses/:id
  Future<ApiResult<Map<String, dynamic>>> getById(String id) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiBuses}/$id');
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// Seat map for a given bus/departure.
  /// GET /api/buses/:id/seatmap?date=YYYY-MM-DD
  Future<ApiResult<Map<String, dynamic>>> seatMap({
    required String id,
    required String date, // YYYY-MM-DD
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get(
        '${AppConstants.apiBuses}/$id/seatmap',
        queryParameters: {'date': date},
      );
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// Availability and fares for selected seats.
  /// GET /api/buses/:id/fares?date=YYYY-MM-DD&seats=U1,U2&boarding=BOARD123&dropping=DROP456
  Future<ApiResult<Map<String, dynamic>>> fares({
    required String id,
    required String date,
    required List<String> seats,
    String? boardingPointId,
    String? droppingPointId,
    int passengers = 1,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'date': date,
        'seats': seats.join(','), // csv array
        'passengers': passengers,
        if (boardingPointId != null && boardingPointId.isNotEmpty) 'boarding': boardingPointId,
        if (droppingPointId != null && droppingPointId.isNotEmpty) 'dropping': droppingPointId,
      };
      final res = await _dio.get('${AppConstants.apiBuses}/$id/fares', queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// Book bus seats.
  /// POST /api/buses/:id/book
  /// payload: { traveler, contact, seats: [...], date, boarding, dropping, payment }
  Future<ApiResult<Map<String, dynamic>>> book({
    required String id,
    required Map<String, dynamic> payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiBuses}/$id/book', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// Cancel a booking by PNR/reference.
  /// POST /api/buses/cancel { pnr, reason? }
  Future<ApiResult<Map<String, dynamic>>> cancel({
    required String pnr,
    String? reason,
  }) {
    return ApiResult.guardFuture(() async {
      final body = <String, dynamic>{'pnr': pnr, if (reason != null && reason.isNotEmpty) 'reason': reason};
      final res = await _dio.post('${AppConstants.apiBuses}/cancel', data: body);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// PNR status lookup.
  /// GET /api/buses/pnr/:pnr
  Future<ApiResult<Map<String, dynamic>>> pnrStatus(String pnr) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiBuses}/pnr/$pnr');
      return Map<String, dynamic>.from(res.data as Map);
    });
  }
}
