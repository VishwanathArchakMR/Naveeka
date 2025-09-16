// lib/features/journey/data/flights_api.dart

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/config/constants.dart';

/// Flights data source: searches, verifying/pricing, fare rules, seat maps, booking, and PNR flows. [10]
class FlightsApi {
  FlightsApi() : _dio = DioClient.instance.dio;

  final Dio _dio;

  // ---------- Search ----------

  /// One-way or round-trip flight search using query parameters. [10]
  /// GET /api/flights/search?from=BLR&to=DEL&date=2025-11-04&returnDate=2025-11-09&adults=1&children=1&infants=0&cabin=ECONOMY&carriers=AI,6E
  Future<ApiResult<Map<String, dynamic>>> search({
    required String from, // IATA origin (city/airport)
    required String to, // IATA destination (city/airport)
    required String date, // YYYY-MM-DD
    String? returnDate, // optional round-trip date
    int adults = 1,
    int children = 0,
    int infants = 0,
    String cabin = 'ECONOMY', // ECONOMY | PREMIUM_ECONOMY | BUSINESS | FIRST
    List<String>? carriers, // allow-list carriers
    List<String>? excludeCarriers, // block-list carriers
    String? sort, // price_asc | duration_asc | departure_asc
    int page = 1,
    int limit = AppConstants.pageSize,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'from': from,
        'to': to,
        'date': date,
        if (returnDate != null && returnDate.isNotEmpty) 'returnDate': returnDate,
        'adults': adults,
        if (children > 0) 'children': children,
        if (infants > 0) 'infants': infants,
        'cabin': cabin,
        if (carriers != null && carriers.isNotEmpty) 'carriers': carriers.join(','), // csv arrays for broad REST compatibility
        if (excludeCarriers != null && excludeCarriers.isNotEmpty)
          'excludeCarriers': excludeCarriers.join(','), // csv arrays for broad REST compatibility
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        'page': page,
        'limit': limit,
      };
      final res = await _dio.get(AppConstants.apiFlightsSearch, queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Encodes arrays with commas and uses Dio queryParameters as recommended for GET filters [2][5].

  /// Multi-city search; send legs as a POST body per common industry practice (e.g., Amadeus/Travelport). [7]
  /// POST /api/flights/search/multi { "legs":[{"from":"BLR","to":"BOM","date":"2025-11-04"}, ...], "pax":{...}, "cabin":"ECONOMY" }
  Future<ApiResult<Map<String, dynamic>>> searchMultiCity({
    required List<Map<String, String>> legs, // [{from,to,date}, ...]
    required Map<String, int> pax, // {adults, children, infants}
    String cabin = 'ECONOMY',
    List<String>? carriers,
    List<String>? excludeCarriers,
    String? sort,
  }) {
    return ApiResult.guardFuture(() async {
      final body = <String, dynamic>{
        'legs': legs,
        'pax': pax,
        'cabin': cabin,
        if (carriers != null && carriers.isNotEmpty) 'carriers': carriers,
        if (excludeCarriers != null && excludeCarriers.isNotEmpty) 'excludeCarriers': excludeCarriers,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
      };
      final res = await _dio.post('${AppConstants.apiFlightsSearch}/multi', data: body);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Multi-city is typically POST with structured legs and pax details following flight-offer search conventions [7].

  // ---------- Offer verify / price ----------

  /// Verify and price selected flight offers prior to booking (locks fare & returns pricing breakdown). [10]
  /// POST /api/flights/offers/price { "offers":[...], "pax":{...}, "ancillaries":{...} }
  Future<ApiResult<Map<String, dynamic>>> priceOffers({
    required Map<String, dynamic> payload, // offers + pax (+ optional ancillaries)
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post(AppConstants.apiFlightsOffersPrice, data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Price verification is a POST step in most flight booking flows to confirm total and rules prior to order creation [10].

  // ---------- Details / Fare rules / Seat map ----------

  /// Flight details by id/offerId to fetch enriched segments and baggage info. [10]
  /// GET /api/flights/:id
  Future<ApiResult<Map<String, dynamic>>> getById(String id) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiFlights}/$id');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Standard REST detail retrieval via shared Dio client [11].

  /// Fare rules for an offer/segment (refundability, changes, no-show, etc.). [10]
  /// GET /api/flights/:id/fare-rules
  Future<ApiResult<Map<String, dynamic>>> fareRules(String id) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiFlights}/$id/fare-rules');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Returns structured rules to display in UI for transparency before purchase [10].

  /// Seat map for a priced offer (cabin layout + paid/free seats). [10]
  /// GET /api/flights/:id/seatmap
  Future<ApiResult<Map<String, dynamic>>> seatMap(String id) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiFlights}/$id/seatmap');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Seat selection often follows offer pricing and precedes passenger data collection [10].

  // ---------- Booking (Order) / PNR ----------

  /// Create an order (booking) for priced offers with passenger & payment details. [10]
  /// POST /api/flights/orders { "offers":[...], "passengers":[...], "contacts":[...], "payment":{...} }
  Future<ApiResult<Map<String, dynamic>>> createOrder({
    required Map<String, dynamic> payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post(AppConstants.apiFlightsOrders, data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Booking creates PNR/ticketing confirmation and returns order references for status/receipt pages [10].

  /// PNR/Order status lookup by id/reference. [10]
  /// GET /api/flights/orders/:id/status
  Future<ApiResult<Map<String, dynamic>>> orderStatus(String orderId) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiFlightsOrders}/$orderId/status');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Enables polling or on-demand status checks after redirect/payment flows [10].

  /// Cancel an order (subject to fare rules and airline policy). [10]
  /// POST /api/flights/orders/:id/cancel { reason? }
  Future<ApiResult<Map<String, dynamic>>> cancelOrder({
    required String orderId,
    String? reason,
  }) {
    return ApiResult.guardFuture(() async {
      final body = <String, dynamic>{if (reason != null && reason.isNotEmpty) 'reason': reason};
      final res = await _dio.post('${AppConstants.apiFlightsOrders}/$orderId/cancel', data: body);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Standard cancellation endpoint encapsulating provider/GDS specifics in backend [10].
}
