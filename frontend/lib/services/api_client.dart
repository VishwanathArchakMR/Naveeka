// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  const ApiClient(this.baseUrl);

  Map<String, String> get _jsonHeaders => const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> getHealth() async {
    final res = await http.get(Uri.parse('$baseUrl/health'), headers: _jsonHeaders);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Health failed: ${res.statusCode} ${res.body}');
  }

  // Example: seeded activities
  Future<List<dynamic>> getActivities({Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl/api/activities').replace(queryParameters: query);
    final res = await http.get(uri, headers: _jsonHeaders);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      return (data['activities'] as List<dynamic>? ?? []);
    }
    throw Exception('Activities failed: ${res.statusCode} ${res.body}');
  }

  // Places list (supports optional filters via query params)
  Future<List<Map<String, dynamic>>> getPlaces({Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl/api/places').replace(queryParameters: query);
    final res = await http.get(uri, headers: _jsonHeaders);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = json.decode(res.body);
      if (decoded is List) {
        // API returns array at top-level
        return decoded.cast<Map<String, dynamic>>();
      }
      // API returns { data: { places: [...] } }
      final body = decoded as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final list = data['places'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Places failed: ${res.statusCode} ${res.body}');
  }

  // Regions list (supports optional filters via query params)
  Future<List<Map<String, dynamic>>> getRegions({Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl/api/regions').replace(queryParameters: query);
    final res = await http.get(uri, headers: _jsonHeaders);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = json.decode(res.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      final body = decoded as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>? ?? {};
      final list = data['regions'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Regions failed: ${res.statusCode} ${res.body}');
  }

  // Add other seeded lists similarly:
  // Future<List<Map<String, dynamic>>> getAirports({Map<String, String>? query}) async { ... }
  // Future<List<Map<String, dynamic>>> getHotels({Map<String, String>? query}) async { ... }
}
