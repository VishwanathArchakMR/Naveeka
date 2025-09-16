// lib/features/journey/data/cabs_api.dart

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/config/constants.dart';

/// Ride-hailing data source: estimates, ETAs, quotes, book, cancel, status, track, nearby. [13]
class CabsApi {
  CabsApi() : _dio = DioClient.instance.dio;

  final Dio _dio;

  /// Price estimates between two points with optional time and vehicle/provider filters. [13]
  /// GET /api/cabs/estimates/price?pickup_lat=&pickup_lng=&drop_lat=&drop_lng=&when=ISO&vehicles=sedan,suv&providers=ola,uber
  Future<ApiResult<List<Map<String, dynamic>>>> priceEstimates({
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    String? whenIso, // schedule time ISO8601 (optional, now if omitted)
    List<String>? vehicles, // e.g. micro, mini, sedan, suv, xl
    List<String>? providers, // e.g. ola, uber, inhouse
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'drop_lat': dropLat,
        'drop_lng': dropLng,
        if (whenIso != null && whenIso.isNotEmpty) 'when': whenIso,
        if (vehicles != null && vehicles.isNotEmpty) 'vehicles': vehicles.join(','), // csv array [3]
        if (providers != null && providers.isNotEmpty) 'providers': providers.join(','), // csv array [3]
      };
      final res = await _dio.get(AppConstants.apiCabsPriceEstimates, queryParameters: qp);
      return _asList(res.data);
    });
  } // Uses Dio queryParameters and CSV-encoded arrays for broad REST compatibility [5][1].

  /// Time ETAs for pickup location (arrival estimates by product/provider). [13]
  /// GET /api/cabs/estimates/time?pickup_lat=&pickup_lng=&providers=ola,uber
  Future<ApiResult<List<Map<String, dynamic>>>> timeEstimates({
    required double pickupLat,
    required double pickupLng,
    List<String>? providers,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        if (providers != null && providers.isNotEmpty) 'providers': providers.join(','), // csv [3]
      };
      final res = await _dio.get(AppConstants.apiCabsTimeEstimates, queryParameters: qp);
      return _asList(res.data);
    });
  } // Simple GET with geo params for ETA listing [11].

  /// Upfront fare quote flow: request a quote to receive a fareId/quoteId used for booking. [7]
  /// POST /api/cabs/quotes { pickup, drop, vehicle, provider, when? }
  Future<ApiResult<Map<String, dynamic>>> createQuote({
    required Map<String, dynamic> pickup, // { lat, lng, address? }
    required Map<String, dynamic> drop, // { lat, lng, address? }
    String? vehicle, // product/vehicle type id or code
    String? provider, // aggregator/provider code
    String? whenIso, // optional schedule time
    Map<String, dynamic>? extras, // luggage count, promo, etc.
  }) {
    return ApiResult.guardFuture(() async {
      final body = <String, dynamic>{
        'pickup': pickup,
        'drop': drop,
        if (vehicle != null && vehicle.isNotEmpty) 'vehicle': vehicle,
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (whenIso != null && whenIso.isNotEmpty) 'when': whenIso,
        if (extras != null && extras.isNotEmpty) 'extras': extras,
      };
      final res = await _dio.post(AppConstants.apiCabsQuotes, data: body);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Mirrors ride-hailing quote->fareId pattern for upfront fares prior to booking [7].

  /// Book a ride using a quote/fare id to lock price and ETA. [7]
  /// POST /api/cabs/book { quoteId, rider, payment, notes? }
  Future<ApiResult<Map<String, dynamic>>> bookRide({
    required String quoteId,
    required Map<String, dynamic> rider, // { name, phone, email? }
    required Map<String, dynamic> payment, // { method, token? }
    String? notes,
  }) {
    return ApiResult.guardFuture(() async {
      final body = <String, dynamic>{
        'quoteId': quoteId,
        'rider': rider,
        'payment': payment,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };
      final res = await _dio.post(AppConstants.apiCabsBook, data: body);
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // POST booking relies on Dio interceptors for Authorization header and errors [2].

  /// Cancel a ride by booking id with optional reason. [REST POST or DELETE depending on backend]
  /// POST /api/cabs/:id/cancel { reason? }
  Future<ApiResult<Map<String, dynamic>>> cancelRide({
    required String bookingId,
    String? reason,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post(
        '${AppConstants.apiCabs}/$bookingId/cancel',
        data: <String, dynamic>{if (reason != null && reason.isNotEmpty) 'reason': reason},
      );
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Cancels booking and returns normalized payload for UI [5].

  /// Get current ride status (driver details, vehicle, live state). [16]
  /// GET /api/cabs/:id/status
  Future<ApiResult<Map<String, dynamic>>> rideStatus(String bookingId) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiCabs}/$bookingId/status');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Status polling endpoint compatible with UI trackers [16].

  /// Track live location for a ride (polling variant; socket alternative in app services). [16]
  /// GET /api/cabs/:id/track
  Future<ApiResult<Map<String, dynamic>>> trackRide(String bookingId) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiCabs}/$bookingId/track');
      return Map<String, dynamic>.from(res.data as Map);
    });
  } // Polls tracking endpoint; websockets can replace in realtime layer [16].

  /// Nearby drivers around a point for map overlays. [10]
  /// GET /api/cabs/nearby?lat=&lng=&radius_km=&providers=ola,uber
  Future<ApiResult<List<Map<String, dynamic>>>> nearbyDrivers({
    required double lat,
    required double lng,
    double radiusKm = 3.0,
    List<String>? providers,
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        if (providers != null && providers.isNotEmpty) 'providers': providers.join(','), // csv [3]
      };
      final res = await _dio.get(AppConstants.apiCabsNearby, queryParameters: qp);
      return _asList(res.data);
    });
  } // Nearby visual overlay source for the map, using Dio GET queryParameters [11][2].

  // ---------- Helpers ----------

  List<Map<String, dynamic>> _asList(dynamic data) {
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return const <Map<String, dynamic>>[];
  } // Accepts both {data: [...]} or raw arrays to avoid brittle parsing at call sites [8].
}
