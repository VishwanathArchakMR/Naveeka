// lib/features/journey/data/journey_api.dart

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/config/constants.dart';

/// Journey/Itinerary aggregator:
/// - Journeys CRUD (list, create, read, update, delete)
/// - Segment management (add/update/remove/reorder)
/// - Pricing/checkout orchestration
/// - Sharing/import helpers
class JourneyApi {
  JourneyApi() : _dio = DioClient.instance.dio;

  final Dio _dio;

  // ---------- Journeys CRUD ----------

  /// GET /api/journeys?page=&limit=&q=&status=
  Future<ApiResult<Map<String, dynamic>>> listJourneys({
    int page = 1,
    int limit = 20,
    String? q,
    String? status, // draft | planned | booked | completed | cancelled
  }) {
    return ApiResult.guardFuture(() async {
      final qp = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (q != null && q.isNotEmpty) 'q': q,
        if (status != null && status.isNotEmpty) 'status': status,
      };
      final res = await _dio.get(AppConstants.apiJourneys, queryParameters: qp);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// GET /api/journeys/:id
  Future<ApiResult<Map<String, dynamic>>> getJourney(String journeyId) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiJourneys}/$journeyId');
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// POST /api/journeys
  /// payload: { title, startDate, endDate, travelers, notes? }
  Future<ApiResult<Map<String, dynamic>>> createJourney(Map<String, dynamic> payload) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post(AppConstants.apiJourneys, data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// PUT /api/journeys/:id
  Future<ApiResult<Map<String, dynamic>>> updateJourney(String journeyId, Map<String, dynamic> payload) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.put('${AppConstants.apiJourneys}/$journeyId', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// DELETE /api/journeys/:id
  Future<ApiResult<Map<String, dynamic>>> deleteJourney(String journeyId) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.delete('${AppConstants.apiJourneys}/$journeyId');
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  // ---------- Segment management ----------

  /// POST /api/journeys/:id/segments
  /// payload: { type: 'flight'|'hotel'|'activity'|'bus'|'cab'|..., data: {...}, dayIndex?, order? }
  Future<ApiResult<Map<String, dynamic>>> addSegment({
    required String journeyId,
    required Map<String, dynamic> payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiJourneys}/$journeyId/segments', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// PUT /api/journeys/:id/segments/:segmentId
  Future<ApiResult<Map<String, dynamic>>> updateSegment({
    required String journeyId,
    required String segmentId,
    required Map<String, dynamic> payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.put('${AppConstants.apiJourneys}/$journeyId/segments/$segmentId', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// DELETE /api/journeys/:id/segments/:segmentId
  Future<ApiResult<Map<String, dynamic>>> removeSegment({
    required String journeyId,
    required String segmentId,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.delete('${AppConstants.apiJourneys}/$journeyId/segments/$segmentId');
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// PUT /api/journeys/:id/segments/reorder
  /// payload: { order: ['segA','segB','segC', ...] }
  Future<ApiResult<Map<String, dynamic>>> reorderSegments({
    required String journeyId,
    required List<String> orderedSegmentIds,
  }) {
    return ApiResult.guardFuture(() async {
      final body = <String, dynamic>{'order': orderedSegmentIds};
      final res = await _dio.put('${AppConstants.apiJourneys}/$journeyId/segments/reorder', data: body);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  // ---------- Pricing / Checkout orchestration ----------

  /// POST /api/journeys/:id/price
  /// payload: { currency?, overrides? } -> returns totals, per-segment quotes, warnings.
  Future<ApiResult<Map<String, dynamic>>> priceJourney({
    required String journeyId,
    Map<String, dynamic>? payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiJourneys}/$journeyId/price', data: payload ?? const {});
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// POST /api/journeys/:id/checkout
  /// payload: { payment:{method,...}, contact:{...}, preferences?:{...} }
  /// Kicks off bookings for supported segments server-side and returns consolidated confirmations.
  Future<ApiResult<Map<String, dynamic>>> checkoutJourney({
    required String journeyId,
    required Map<String, dynamic> payload,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiJourneys}/$journeyId/checkout', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// GET /api/journeys/:id/status
  /// Returns pricing/booking progress and per-segment states after checkout initiation.
  Future<ApiResult<Map<String, dynamic>>> journeyStatus(String journeyId) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.get('${AppConstants.apiJourneys}/$journeyId/status');
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  // ---------- Sharing / Import ----------

  /// POST /api/journeys/:id/share -> { code, url }
  Future<ApiResult<Map<String, dynamic>>> shareJourney(String journeyId) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiJourneys}/$journeyId/share');
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// POST /api/journeys/import { code } -> clones into current account
  Future<ApiResult<Map<String, dynamic>>> importSharedJourney(String code) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiJourneys}/import', data: {'code': code});
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  // ---------- Notes / Attachments (optional helpers) ----------

  /// POST /api/journeys/:id/notes { text }
  Future<ApiResult<Map<String, dynamic>>> addNote({
    required String journeyId,
    required String text,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.post('${AppConstants.apiJourneys}/$journeyId/notes', data: {'text': text});
      return Map<String, dynamic>.from(res.data as Map);
    });
  }

  /// DELETE /api/journeys/:id/notes/:noteId
  Future<ApiResult<Map<String, dynamic>>> deleteNote({
    required String journeyId,
    required String noteId,
  }) {
    return ApiResult.guardFuture(() async {
      final res = await _dio.delete('${AppConstants.apiJourneys}/$journeyId/notes/$noteId');
      return Map<String, dynamic>.from(res.data as Map);
    });
  }
}
