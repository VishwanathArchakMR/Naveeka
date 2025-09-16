// lib/features/quick_actions/data/booking_api.dart

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Lightweight result wrapper compatible with both `fold` and `when` usage patterns.
sealed class ApiResult<T> {
  const ApiResult();
  R fold<R>({required R Function(ApiError e) onError, required R Function(T v) onSuccess});
  Future<R> when<R>({required Future<R> Function(T v) success, required Future<R> Function(ApiError e) failure});
  bool get success => this is ApiSuccess<T>;
  T? get data => this is ApiSuccess<T> ? (this as ApiSuccess<T>).value : null;
  ApiError? get error => this is ApiFailure<T> ? (this as ApiFailure<T>).err : null;
}

class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.value);
  final T value;
  @override
  R fold<R>({required R Function(ApiError e) onError, required R Function(T v) onSuccess}) => onSuccess(value);
  @override
  Future<R> when<R>({required Future<R> Function(T v) success, required Future<R> Function(ApiError e) failure}) => success(value);
}

class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure(this.err);
  final ApiError err;
  @override
  R fold<R>({required R Function(ApiError e) onError, required R Function(T v) onSuccess}) => onError(err);
  @override
  Future<R> when<R>({required Future<R> Function(T v) success, required Future<R> Function(ApiError e) failure}) => failure(err);
}

class ApiError implements Exception {
  const ApiError({required this.message, this.code, this.details});
  final String message;
  final int? code;
  final Map<String, dynamic>? details;
  String get safeMessage => message;
  @override
  String toString() => 'ApiError(code: $code, message: $message)';
}

/// API configuration
class BookingApiConfig {
  const BookingApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 20),
    this.sendTimeout = const Duration(seconds: 20),
    this.defaultHeaders = const {'Accept': 'application/json', 'Content-Type': 'application/json'},
  });
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final Map<String, String> defaultHeaders;
}

/// Booking API client
class BookingApi {
  BookingApi({
    Dio? dio,
    BookingApiConfig? config,
    String? authToken,
  })  : _config = config ?? const BookingApiConfig(baseUrl: ''),
        _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: _config.connectTimeout,
      receiveTimeout: _config.receiveTimeout,
      sendTimeout: _config.sendTimeout,
      headers: {
        ..._config.defaultHeaders,
        if (authToken != null && authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      },
    );
  }

  final Dio _dio;
  final BookingApiConfig _config;

  /// Update bearer token (e.g., after login/refresh).
  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // ----------------------------
  // Availability
  // ----------------------------

  /// Fetch availability for a place on a given date.
  Future<ApiResult<BookingAvailability>> fetchAvailability({
    required String placeId,
    required DateTime date,
    CancelToken? cancelToken,
  }) async {
    return _get<BookingAvailability>(
      path: '/v1/booking/$placeId/availability',
      query: {'date': date.toIso8601String()},
      parse: (data) => BookingAvailability.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      // GET is idempotent; allow retries on transient network failures.
      retries: 2,
    );
  }

  // ----------------------------
  // Quotes & Pricing
  // ----------------------------

  /// Get a quote for selected items/time slot before confirming a reservation.
  Future<ApiResult<BookingQuote>> getQuote({
    required String placeId,
    required BookingQuoteRequest request,
    CancelToken? cancelToken,
  }) async {
    return _post<BookingQuote>(
      path: '/v1/booking/$placeId/quote',
      body: request.toJson(),
      parse: (data) => BookingQuote.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 1, // POST is not retried aggressively to avoid duplicate intents.
    );
  }

  // ----------------------------
  // Reservations
  // ----------------------------

  /// Create reservation with selected slot and guest details.
  Future<ApiResult<BookingReservation>> createReservation({
    required String placeId,
    required BookingReservationRequest request,
    CancelToken? cancelToken,
  }) async {
    return _post<BookingReservation>(
      path: '/v1/booking/$placeId/reservations',
      body: request.toJson(),
      parse: (data) => BookingReservation.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 0,
    );
  }

  /// Cancel a reservation.
  Future<ApiResult<void>> cancelReservation({
    required String reservationId,
    String? reason,
    CancelToken? cancelToken,
  }) async {
    return _post<void>(
      path: '/v1/booking/reservations/$reservationId/cancel',
      body: {'reason': reason},
      parse: (_) => null,
      cancelToken: cancelToken,
      retries: 0,
    );
  }

  // ----------------------------
  // Partner redirect (universal link to external booking site/app)
  // ----------------------------

  /// Get an external partner deep link or web URL for booking or ordering.
  Future<ApiResult<PartnerRedirect>> getPartnerRedirect({
    required String placeId,
    String? vendor, // e.g., 'opentable', 'zomato', 'swiggy'
    Map<String, String>? params,
    CancelToken? cancelToken,
  }) async {
    final q = {
      if (vendor != null && vendor.isNotEmpty) 'vendor': vendor,
      if (params != null) ...params,
    };
    return _get<PartnerRedirect>(
      path: '/v1/booking/$placeId/partner',
      query: q,
      parse: (data) => PartnerRedirect.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 1,
    );
  }

  // ----------------------------
  // Low-level HTTP helpers with basic backoff
  // ----------------------------

  Future<ApiResult<T>> _get<T>({
    required String path,
    required T Function(dynamic data) parse,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    int retries = 0,
  }) async {
    return _withRetry<T>(
      retries: retries,
      request: () async {
        final res = await _dio.get<dynamic>(
          path,
          queryParameters: query,
          cancelToken: cancelToken,
        );
        return _parseResponse<T>(res, parse);
      },
    );
  }

  Future<ApiResult<T>> _post<T>({
    required String path,
    required Map<String, dynamic>? body,
    required T Function(dynamic data) parse,
    CancelToken? cancelToken,
    int retries = 0,
  }) async {
    return _withRetry<T>(
      retries: retries,
      request: () async {
        final res = await _dio.post<dynamic>(
          path,
          data: body == null ? null : jsonEncode(body),
          cancelToken: cancelToken,
        );
        return _parseResponse<T>(res, parse);
      },
    );
  }

  Future<ApiResult<T>> _withRetry<T>({
    required Future<ApiResult<T>> Function() request,
    required int retries,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        // If canceled, surface immediately.
        if (CancelToken.isCancel(e)) {
          return ApiFailure<T>(ApiError(message: 'Cancelled', code: -1));
        }
        attempt += 1;
        final transient = _isTransient(e);
        if (!transient || attempt > retries) {
          return ApiFailure<T>(_mapDioError(e));
        }
        // Simple exponential backoff with jitter.
        final delayMs = _backoffDelayMs(attempt);
        await Future.delayed(Duration(milliseconds: delayMs));
        continue;
      } catch (e) {
        return ApiFailure<T>(ApiError(message: e.toString()));
      }
    }
  }

  bool _isTransient(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        return code >= 500; // Retry 5xx
      default:
        return false;
    }
  }

  int _backoffDelayMs(int attempt) {
    // base 300ms, exponential with jitter
    final base = 300 * (1 << (attempt - 1));
    final jitter = (base * 0.2).toInt();
    return base + (DateTime.now().microsecondsSinceEpoch % jitter);
  }

  ApiResult<T> _parseResponse<T>(Response res, T Function(dynamic) parse) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) {
      final data = res.data;
      return ApiSuccess<T>(parse(data));
    }
    return ApiFailure<T>(ApiError(
      message: res.statusMessage ?? 'HTTP $code',
      code: code,
      details: _asMap(res.data),
    ));
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final v = jsonDecode(data);
        if (v is Map<String, dynamic>) return v;
      } catch (_) {}
    }
    return null;
  }
}

// ----------------------------
// DTOs
// ----------------------------

class BookingAvailability {
  BookingAvailability({required this.date, required this.slots});
  final DateTime date;
  final List<BookingSlot> slots;

  factory BookingAvailability.fromJson(Map<String, dynamic> json) {
    return BookingAvailability(
      date: DateTime.parse(json['date'] as String),
      slots: ((json['slots'] as List?) ?? const [])
          .map((e) => BookingSlot.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'slots': slots.map((e) => e.toJson()).toList(),
      };
}

class BookingSlot {
  BookingSlot({required this.start, required this.end, required this.capacity, required this.available});
  final DateTime start;
  final DateTime end;
  final int capacity;
  final int available;

  factory BookingSlot.fromJson(Map<String, dynamic> json) {
    return BookingSlot(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      capacity: (json['capacity'] ?? 0) as int,
      available: (json['available'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'capacity': capacity,
        'available': available,
      };
}

class BookingQuoteRequest {
  BookingQuoteRequest({required this.slotStart, required this.partySize, this.items = const []});
  final DateTime slotStart;
  final int partySize;
  final List<BookingItem> items;

  Map<String, dynamic> toJson() => {
        'slotStart': slotStart.toIso8601String(),
        'partySize': partySize,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class BookingItem {
  BookingItem({required this.sku, required this.quantity});
  final String sku;
  final int quantity;
  Map<String, dynamic> toJson() => {'sku': sku, 'quantity': quantity};
}

class BookingQuote {
  BookingQuote({required this.currency, required this.subtotal, required this.tax, required this.total, this.breakdown = const []});
  final String currency;
  final double subtotal;
  final double tax;
  final double total;
  final List<QuoteLine> breakdown;

  factory BookingQuote.fromJson(Map<String, dynamic> json) {
    return BookingQuote(
      currency: (json['currency'] ?? 'USD') as String,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      breakdown: ((json['breakdown'] as List?) ?? const [])
          .map((e) => QuoteLine.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class QuoteLine {
  QuoteLine({required this.label, required this.amount});
  final String label;
  final double amount;

  factory QuoteLine.fromJson(Map<String, dynamic> json) {
    return QuoteLine(label: (json['label'] ?? '') as String, amount: (json['amount'] ?? 0).toDouble());
  }
}

class BookingReservationRequest {
  BookingReservationRequest({
    required this.slotStart,
    required this.partySize,
    required this.contactName,
    required this.contactPhone,
    this.contactEmail,
    this.notes,
  });

  final DateTime slotStart;
  final int partySize;
  final String contactName;
  final String contactPhone;
  final String? contactEmail;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'slotStart': slotStart.toIso8601String(),
        'partySize': partySize,
        'contact': {
          'name': contactName,
          'phone': contactPhone,
          if (contactEmail != null && contactEmail!.isNotEmpty) 'email': contactEmail,
        },
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class BookingReservation {
  BookingReservation({
    required this.id,
    required this.placeId,
    required this.slotStart,
    required this.partySize,
    required this.status,
    this.createdAt,
    this.confirmationCode,
  });

  final String id;
  final String placeId;
  final DateTime slotStart;
  final int partySize;
  final String status; // e.g., 'confirmed', 'pending', 'cancelled'
  final DateTime? createdAt;
  final String? confirmationCode;

  factory BookingReservation.fromJson(Map<String, dynamic> json) {
    return BookingReservation(
      id: (json['id'] ?? '') as String,
      placeId: (json['placeId'] ?? '') as String,
      slotStart: DateTime.parse(json['slotStart'] as String),
      partySize: (json['partySize'] ?? 0) as int,
      status: (json['status'] ?? 'pending') as String,
      createdAt: (json['createdAt'] != null) ? DateTime.parse(json['createdAt'] as String) : null,
      confirmationCode: json['confirmationCode'] as String?,
    );
  }
}

class PartnerRedirect {
  PartnerRedirect({required this.url, this.vendor});
  final String url; // Universal link to open in browser/app
  final String? vendor;

  factory PartnerRedirect.fromJson(Map<String, dynamic> json) {
    return PartnerRedirect(
      url: (json['url'] ?? '') as String,
      vendor: json['vendor'] as String?,
    );
  }
}
