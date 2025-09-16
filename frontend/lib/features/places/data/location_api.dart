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
  /// Example: https://nominatim.openstreetmap.org
  final String baseUrl;

  /// User-Agent header to satisfy Nominatim usage policy.
  /// Provide an app identifier and contact per service requirements.
  final String userAgent;

  final http.Client _client;
  final Duration timeout;

  Map<String, String> _headers() {
    return {
      // For GETs returning JSON, Accept is sufficient; for POST JSON endpoints, set Content-Type too.
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
    }; // Nominatim search supports q, format=json/jsonv2, limit, addressdetails, and countrycodes for filtering. [1][4]

    try {
      final res = await _client.get(_u('/search', params), headers: _headers()).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return Err(_mapErrorFromResponse(res).toApiError());
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
  } // Fetching JSON via package:http with headers and parsing the body aligns with Flutter’s networking cookbook and http usage. [21][22]

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
    }; // Nominatim reverse endpoint accepts lat, lon, format=json/jsonv2, and addressdetails for component fields. [14][2]

    try {
      final res = await _client.get(_u('/reverse', params), headers: _headers()).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return Err(_mapErrorFromResponse(res).toApiError());
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
  } // Using GET with Accept: application/json and decoding response into a normalized map is standard for REST JSON consumption in Flutter. [21][23]

  // -----------------------------------------------------------
  // Lookup (optional, by OSM typed id: N|W|R + id)
  // -----------------------------------------------------------

  /// Lookup details for one or more OSM objects (ids like 'N123', 'W456', 'R789').
  ///
  /// Note: Only applicable for Nominatim; some providers may not support this.
  Future<Result<List<Map<String, dynamic>>>> lookupByOsmIds(List<String> osmTypedIds) async {
    if (osmTypedIds.isEmpty) return const Ok(<Map<String, dynamic>>[]);
    final params = <String, String>{
      'osm_ids': osmTypedIds.join(','),
      'format': 'jsonv2',
      'addressdetails': '1',
    }; // Nominatim lookup endpoint accepts osm_ids list and returns JSON with address details when requested. [3][2]

    try {
      final res = await _client.get(_u('/lookup', params), headers: _headers()).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return Err(_mapErrorFromResponse(res).toApiError());
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
  } // The lookup method mirrors the search pattern and returns normalized places for consistency across the data layer. [3][21]

  // -----------------------------------------------------------
  // Normalization helpers
  // -----------------------------------------------------------

  Map<String, dynamic> _normalizeNominatim(Map<String, dynamic> m) {
    // Coordinates
    double? d(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    final lat = d(m['lat']);
    final lng = d(m['lon']);

    // Names
    final namedetails = (m['namedetails'] is Map) ? (m['namedetails'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final nameRaw = (namedetails['name'] ?? m['name'] ?? '').toString().trim();
    final display = (m['display_name'] ?? '').toString();

    // Secondary line: display name without the first component for compactness
    String secondaryFromDisplay(String s) {
      final parts = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.length <= 1) return '';
      return parts.sublist(1).join(', ');
    }

    // Address components
    final addr = (m['address'] is Map) ? (m['address'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['hamlet'] ?? '').toString();
    final region = (addr['state'] ?? addr['region'] ?? '').toString();
    final country = (addr['country'] ?? '').toString();

    // Place id from OSM type + id (e.g., N123, W456, R789)
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
        : (display.isNotEmpty ? display.split(',').first.trim() : (city.isNotEmpty ? city : country)); // Prefer namedetails.name, else first of display_name. [2][1]

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
      'raw': m, // keep raw for advanced use/debug
    };
  } // Normalization extracts stable fields across providers to a common shape suitable for UI pickers and downstream flows. [2][1]

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
