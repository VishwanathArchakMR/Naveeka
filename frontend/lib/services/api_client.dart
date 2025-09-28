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

  // Add other seeded lists similarly:
  // Future<List<dynamic>> getAirports(...) { ... }
  // Future<List<dynamic>> getHotels(...) { ... }
}
