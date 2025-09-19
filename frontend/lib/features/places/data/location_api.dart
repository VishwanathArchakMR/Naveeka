// lib/features/places/data/location_api.dart

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lightweight API error carrying a safe message and optional cause/status.
class ApiError implements Exception {
  ApiError(this.safeMessage, {this.status, this.cause});
  final String safeMessage;
  final int? status;
  final Object? cause;

  @override
  String toString() => 'ApiError($status): $safeMessage';
}

/// Functional result type with fold for onSuccess/onError ergonomics.
abstract class Result<T> {
  const Result();
  R fold<R>({required R Function(T data) onSuccess, required R Function(ApiError e) onError});
}

class Ok<T> extends Result<T> {
  const Ok(this.data);
  final T data;
  @override
  R fold<R>({required R Function(T data) onSuccess, required R Function(ApiError e) onError}) => onSuccess(data);
}

class Err<T> extends Result<T> {
  const Err(this.error);
  final ApiError error;
  @override
  R fold<R>({required R Function(T data) onSuccess, required R Function(ApiError e) onError}) => onError(error);
}

/// Location/Places API with Nominatim-style endpoints and normalized outputs.
/// Defaults:
/// - baseUrl: https://nominatim.openstreetmap.org
/// - JSON format: jsonv2
/// - Includes address details for robust normalization
class LocationApi {
  LocationApi({
    this.baseUrl = 'https://nominatim.openstreetmap.org',
    this.userAgent = 'myapp/1.0 (contact@example.com)',
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  /// Base URL of the provider (Nominatim-compatible).
  final String baseUrl;

  /// User-Agent header to satisfy Nominatim usage policy.
  final String userAgent;

  final http.Client _client;
  final Duration timeout;

  Map<String, String> _headers() {
    return {
      'Accept': 'application/json',
      'User-Agent': userAgent,
    };
  }

  Uri _u(String path, [Map<String, String>? q]) {
    final clean = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$clean$path').replace(queryParameters: q);
  }

  // -----------------------------------------------------------
  // Search (autocomplete-style free text)
  // -----------------------------------------------------------

  /// Free-text search with optional country filtering and limit.
  ///
  /// Normalized list items contain:
  /// { name, secondary?, city?, region?, country?, lat, lng, placeId, source }
  Future<Result<List<Map<String, dynamic>>>> search({
    required String query,
    int limit = 10,
    List<String>? countryCodes, // e.g. ['in','us']
    bool includeNamedetails = false,
  }) async {
    if (query.trim().isEmpty) {
      return const Ok(<Map<String, dynamic>>[]);
    }

    final params = <String, String>{
      'q': query,
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '1',
      if (includeNamedetails) 'namedetails': '1',
      if (countryCodes != null && countryCodes.isNotEmpty) 'countrycodes': countryCodes.join(','),
    };

    try {
      final res = await _client.get(_u('/search', params), headers: _headers()).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        // FIX: return Err<T> directly from helper instead of wrapping it again.
        return _mapErrorFromResponse(res).toApiError<List<Map<String, dynamic>>>();
      }
      final data = jsonDecode(res.body);
      final list = (data is List) ? data.cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
      final normalized = list.map(_normalizeNominatim).toList(growable: false);
      return Ok(normalized);
    } on TimeoutException catch (e) {
      return Err(ApiError('Request timed out', cause: e));
    } on http.ClientException catch (e) {
      return Err(ApiError('Network error', cause: e));
    } catch (e) {
      return Err(ApiError('Unexpected error', cause: e));
    }
  }

  // -----------------------------------------------------------
  // Reverse geocoding
  // -----------------------------------------------------------

  /// Reverse geocode to an address/place string and components.
  ///
  /// Returns a normalized place map:
  /// { name, secondary?, city?, region?, country?, lat, lng, placeId, source }
  Future<Result<Map<String, dynamic>>> reverse({
    required double lat,
    required double lng,
    int zoom = 16,
  }) async {
    final params = <String, String>{
      'lat': lat.toString(),
      'lon': lng.toString(),
      'format': 'jsonv2',
      'zoom': '$zoom',
      'addressdetails': '1',
    };

    try {
      final res = await _client.get(_u('/reverse', params), headers: _headers()).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        // FIX: return the typed Err<Map<String,dynamic>> directly.
        return _mapErrorFromResponse(res).toApiError<Map<String, dynamic>>();
      }
      final data = jsonDecode(res.body);
      final m = (data is Map) ? data.cast<String, dynamic>() : const <String, dynamic>{};
      return Ok(_normalizeNominatim(m));
    } on TimeoutException catch (e) {
      return Err(ApiError('Request timed out', cause: e));
    } on http.ClientException catch (e) {
      return Err(ApiError('Network error', cause: e));
    } catch (e) {
      return Err(ApiError('Unexpected error', cause: e));
    }
  }

  // -----------------------------------------------------------
  // Lookup (optional, by OSM typed id: N|W|R + id)
  // -----------------------------------------------------------

  /// Lookup details for one or more OSM objects (ids like 'N123', 'W456', 'R789').
  Future<Result<List<Map<String, dynamic>>>> lookupByOsmIds(List<String> osmTypedIds) async {
    if (osmTypedIds.isEmpty) return const Ok(<Map<String, dynamic>>[]);
    final params = <String, String>{
      'osm_ids': osmTypedIds.join(','),
      'format': 'jsonv2',
      'addressdetails': '1',
    };

    try {
      final res = await _client.get(_u('/lookup', params), headers: _headers()).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        // FIX: return the typed Err<List<Map<String,dynamic>>> directly.
        return _mapErrorFromResponse(res).toApiError<List<Map<String, dynamic>>>();
      }
      final data = jsonDecode(res.body);
      final list = (data is List) ? data.cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
      final normalized = list.map(_normalizeNominatim).toList(growable: false);
      return Ok(normalized);
    } on TimeoutException catch (e) {
      return Err(ApiError('Request timed out', cause: e));
    } on http.ClientException catch (e) {
      return Err(ApiError('Network error', cause: e));
    } catch (e) {
      return Err(ApiError('Unexpected error', cause: e));
    }
  }

  // -----------------------------------------------------------
  // Normalization helpers
  // -----------------------------------------------------------

  Map<String, dynamic> _normalizeNominatim(Map<String, dynamic> m) {
    double? d(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lat = d(m['lat']);
    final lng = d(m['lon']);

    final namedetails =
        (m['namedetails'] is Map) ? (m['namedetails'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final nameRaw = (namedetails['name'] ?? m['name'] ?? '').toString().trim();
    final display = (m['display_name'] ?? '').toString();

    String secondaryFromDisplay(String s) {
      final parts = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.length <= 1) return '';
      return parts.sublist(1).join(', ');
    }

    final addr = (m['address'] is Map) ? (m['address'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['hamlet'] ?? '').toString();
    final region = (addr['state'] ?? addr['region'] ?? '').toString();
    final country = (addr['country'] ?? '').toString();

    final osmType = (m['osm_type'] ?? '').toString(); // node|way|relation
    final osmId = (m['osm_id'] ?? '').toString();
    String pid() {
      final prefix = switch (osmType) {
        'node' => 'N',
        'way' => 'W',
        'relation' => 'R',
        _ => '',
      };
      return (prefix.isEmpty || osmId.isEmpty) ? '' : '$prefix$osmId';
    }

    final name = nameRaw.isNotEmpty
        ? nameRaw
        : (display.isNotEmpty ? display.split(',').first.trim() : (city.isNotEmpty ? city : country));

    final secondary = nameRaw.isNotEmpty ? (display.isNotEmpty ? secondaryFromDisplay(display) : '') : '';

    return {
      'name': name,
      'secondary': secondary.isEmpty ? null : secondary,
      'city': city.isEmpty ? null : city,
      'region': region.isEmpty ? null : region,
      'country': country.isEmpty ? null : country,
      'lat': lat,
      'lng': lng,
      'placeId': pid(),
      'source': 'nominatim',
      'raw': m,
    };
  }

  // -----------------------------------------------------------
  // Error mapping
  // -----------------------------------------------------------

  _MapError _mapErrorFromResponse(http.Response res) {
    String msg = 'HTTP ${res.statusCode}';
    try {
      final json = jsonDecode(res.body);
      if (json is Map && json['error'] != null) {
        final e = json['error'];
        if (e is Map && e['message'] is String) msg = e['message'] as String;
        if (e is String) msg = e;
      }
    } catch (_) {
      // keep default
    }
    return _MapError(status: res.statusCode, message: msg, body: res.body);
  }
}

class _MapError {
  _MapError({required this.status, required this.message, this.body});
  final int status;
  final String message;
  final String? body;
  Err<T> toApiError<T>() => Err<T>(ApiError(message, status: status));
}
