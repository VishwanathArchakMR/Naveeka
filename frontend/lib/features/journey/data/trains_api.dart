// lib/features/journey/data/trains_api.dart

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/config/constants.dart';

/// Trains data source: search, details, route, availability, fares, bookings, cancellations, PNR & live status, stations search.
class TrainsApi {
  TrainsApi() : _dio = DioClient.instance.dio;

  final Dio _dio;

  // ---------- Search / Listing ----------

  /// Search trains for an origin/destination/date with filters (classes/quotas/operators/sort). [GET]
  /// Example: GET /api/trains/search?from=SBC&to=MAS&date=2025-11-04&classes=3A,SL&quota=GN&flexible=true&page=1&limit=20
  Future<ApiResult<Map<String, dynamic>>> search({
    required String from, // station code
    required String to, // station code
    required String date, // YYYY-MM-DD
    List<String>? classes, // e.g., 1A,2A,3A,SL,CC,EC
    String? quota, // GN | TQ | LD | ...
    List<String>? operators, // IRCTC vendors or private operators if applicable
    bool? flexible, // +-1 day search
    String? sort, // departure_asc | arrival_asc | duration_asc | price_asc
    int page = 1,
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'from': from,
        'to': to,
        'date': date,
        if (classes != null && classes.isNotEmpty) 'classes': classes.join(','), // csv arrays
        if (quota != null && quota.isNotEmpty) 'quota': quota,
        if (operators != null && operators.isNotEmpty) 'operators': operators.join(','), // csv arrays
        if (flexible != null) 'flexible': flexible,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        'page': page,
        'limit': limit,
      };
      final res = await _dio.get(AppConstants.apiTrainsSearch, queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Uses Dio queryParameters and CSV for arrays to keep REST URLs interoperable with most servers [8][5][4].

  /// Get train meta by number/id, optionally date-scoped (for schedule variances).
  /// GET /api/trains/:id?date=YYYY-MM-DD
  Future<ApiResult<Map<String, dynamic>>> getTrain({
    required String idOrNumber,
    String? date,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get(
        '${AppConstants.apiTrains}/$idOrNumber',
        queryParameters: {
          if (date != null && date.isNotEmpty) 'date': date,
        },
      );
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Detail retrieval through shared Dio base configuration and interceptors [2].

  /// Get full route (stations/times) for a train (date-aware if provided).
  /// GET /api/trains/:id/route?date=YYYY-MM-DD
  Future<ApiResult<Map<String, dynamic>>> route({
    required String idOrNumber,
    String? date,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get(
        '${AppConstants.apiTrains}/$idOrNumber/route',
        queryParameters: {if (date != null && date.isNotEmpty) 'date': date},
      );
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Route endpoint separated from train details for clarity and caching [8].

  // ---------- Availability / Fares ----------

  /// Seat availability for a train and class/quota between specific stations.
  /// GET /api/trains/:id/availability?date=YYYY-MM-DD&class=3A&quota=GN&from=SBC&to=MAS
  Future<ApiResult<Map<String, dynamic>>> availability({
    required String idOrNumber,
    required String date,
    required String travelClass, // 1A/2A/3A/SL/CC/EC
    required String quota, // GN/TQ/...
    required String from,
    required String to,
    int adults = 1,
    int children = 0,
    int seniors = 0,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'date': date,
        'class': travelClass,
        'quota': quota,
        'from': from,
        'to': to,
        'adults': adults,
        if (children > 0) 'children': children,
        if (seniors > 0) 'seniors': seniors,
      };
      final res = await _dio.get(
        '${AppConstants.apiTrains}/$idOrNumber/availability',
        queryParameters: qp,
      );
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Availability uses GET with queryParameters to remain idempotent/cacheable where allowed [8][1].

  /// Fare breakdown for a train/class/quota between stations.
  /// GET /api/trains/:id/fares?from=SBC&to=MAS&class=3A&quota=GN
  Future<ApiResult<Map<String, dynamic>>> fares({
    required String idOrNumber,
    required String from,
    required String to,
    required String travelClass,
    required String quota,
    int adults = 1,
    int children = 0,
    int seniors = 0,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'from': from,
        'to': to,
        'class': travelClass,
        'quota': quota,
        'adults': adults,
        if (children > 0) 'children': children,
        if (seniors > 0) 'seniors': seniors,
      };
      final res = await _dio.get('${AppConstants.apiTrains}/$idOrNumber/fares', queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Fare retrieval separates price logic from availability check for clearer UX steps [8].

  // ---------- Booking / Cancellation ----------

  /// Book seats/berths for a priced selection (server handles IRCTC/GDS specifics).
  /// POST /api/trains/:id/book { from,to,date,class,quota,passengers:[{name,age,gender,berthPref?}], contact:{...}, payment:{...} }
  Future<ApiResult<Map<String, dynamic>>> book({
    required String idOrNumber,
    required Map<String, dynamic> payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiTrains}/$idOrNumber/book', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Booking uses POST JSON body and relies on interceptors for Authorization headers [2].

  /// Cancel a booking by PNR/reference (partial cancellation supported via passenger refs).
  /// POST /api/trains/bookings/:pnr/cancel { passengers?:[...], reason? }
  Future<ApiResult<Map<String, dynamic>>> cancel({
    required String pnr,
    Map<String, dynamic>? payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res =
          await _dio.post('${AppConstants.apiTrains}/bookings/$pnr/cancel', data: payload ?? const {});
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // POST is used to carry metadata and partial cancel selections in body [8].

  // ---------- PNR & Live status ----------

  /// PNR status lookup.
  /// GET /api/trains/pnr/:pnr
  Future<ApiResult<Map<String, dynamic>>> pnrStatus(String pnr) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiTrains}/pnr/$pnr');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Mirrors common rail APIs offering PNR endpoints to check reservation status [17][15][9].

  /// Live running status for a train on a given date.
  /// GET /api/trains/:id/live?date=YYYY-MM-DD
  Future<ApiResult<Map<String, dynamic>>> liveStatus({
    required String idOrNumber,
    required String date,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get(
        '${AppConstants.apiTrains}/$idOrNumber/live',
        queryParameters: {'date': date},
      );
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Returns position/delay/ETA data for status screens and notifications [17][6].

  // ---------- Stations / Utilities ----------

  /// Type-ahead station search for origin/destination pickers.
  /// GET /api/trains/stations?q=mas&limit=10
  Future<ApiResult<List<Map<String, dynamic>>>> stations({
    required String q,
    int limit = 10,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get(
        '${AppConstants.apiTrains}/stations',
        queryParameters: {'q': q, 'limit': limit},
      );
      return _asList(res.data);
    });
  } // Uses GET queryParameters, returning list payload for typeahead UIs [8].

  /// Coach/berth layout for a class/coach type (if supported by backend).
  /// GET /api/trains/:id/coach-layout?class=3A
  Future<ApiResult<Map<String, dynamic>>> coachLayout({
    required String idOrNumber,
    required String travelClass,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get(
        '${AppConstants.apiTrains}/$idOrNumber/coach-layout',
        queryParameters: {'class': travelClass},
      );
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Optional helper to power berth preference UI (upper/lower/side) [8].

  // ---------- Helpers ----------

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return const <Map<String, dynamic>>[];
  } // Accepts both {data:[...]} and raw arrays for resilient parsing at call sites [3].
}
