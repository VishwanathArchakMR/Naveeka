// lib/features/navee_ai/data/navee_ai_api.dart

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
  R fold<R>(
      {required R Function(T data) onSuccess,
      required R Function(ApiError e) onError});
}

class Ok<T> extends Result<T> {
  const Ok(this.data);
  final T data;
  @override
  R fold<R>(
          {required R Function(T data) onSuccess,
          required R Function(ApiError e) onError}) =>
      onSuccess(data);
}

class Err<T> extends Result<T> {
  const Err(this.error);
  final ApiError error;
  @override
  R fold<R>(
          {required R Function(T data) onSuccess,
          required R Function(ApiError e) onError}) =>
      onError(error);
}

/// OpenAI-compatible Chat + helpers (plan/suggest/moderate).
///
/// Defaults to OpenAI-style routes:
/// - POST {baseUrl}/chat/completions
/// - POST {baseUrl}/moderations
///
/// Pass a different baseUrl if using a proxy/gateway that mimics these routes.
class NaveeAiApi {
  NaveeAiApi({
    required this.baseUrl,
    required this.apiKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.defaultModel = 'gpt-4o-mini',
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _client;
  final Duration timeout;
  final String defaultModel;

  Map<String, String> _headers({Map<String, String>? extra}) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      if (extra != null) ...extra,
    };
  }

  Uri _u(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r"/$"), "")}$path');

  // ------------------------
  // Core: Chat Completions
  // ------------------------

  /// Send a chat request. `messages` must follow the roles: system|user|assistant.
  /// Example message: {"role": "user", "content": "Hello"}
  Future<Result<Map<String, dynamic>>> chat({
    required List<Map<String, String>> messages,
    String? model,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final body = {
        'model': model ?? defaultModel,
        'messages': messages,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
        if (extra != null) ...extra,
      };

      final res = await _client
          .post(_u('/chat/completions'),
              headers: _headers(), body: jsonEncode(body))
          .timeout(
              timeout); // Use http with application/json headers and parse JSON per cookbook guidance [6][7]

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return Err<Map<String, dynamic>>(
            MapError.fromResponse(res).toApiError());
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return Ok(data);
    } on TimeoutException catch (e) {
      return Err(ApiError('Request timed out', cause: e));
    } on http.ClientException catch (e) {
      return Err(ApiError('Network error', cause: e));
    } catch (e) {
      return Err(ApiError('Unexpected error', cause: e));
    }
  } // Endpoint matches the OpenAI chat completions shape and headers with Bearer auth and JSON body [17][8]

  // ------------------------
  // Helpers: Travel planning
  // ------------------------

  /// Ask the model to return a structured trip plan JSON.
  ///
  /// Returns: { "days": [{ "date": "YYYY-MM-DD", "items": [{ "time":"HH:mm", "title":"", "notes":"", "lat":?, "lng":? }] }], "summary": {...} }
  Future<Result<Map<String, dynamic>>> planTrip({
    required String origin,
    required String destination,
    required String startDateIso,
    required String endDateIso,
    int adults = 2,
    int children = 0,
    String? style, // e.g., "family", "romantic", "budget", "luxury"
    List<String> interests =
        const <String>[], // e.g., ["beaches","museums","food"]
    String? currency, // format budget-related outputs
    String? language, // preferred language for text
    String? model,
  }) async {
    const sys =
        'You are Navee, a travel AI that outputs STRICT JSON with no extra text.'; // System role per chat API roles [5]
    final user = '''
Build a city itinerary with the following fields:
{
  "days": [
    { "date": "YYYY-MM-DD", "items": [ { "time": "HH:mm", "title": "", "notes": "", "lat": null, "lng": null } ] }
  ],
  "summary": { "city": "$destination", "origin": "$origin", "adults": $adults, "children": $children, "style": "${style ?? ''}", "interests": ${jsonEncode(interests)}, "currency": "${currency ?? ''}", "language": "${language ?? ''}" }
}
Constraints:
- Dates from $startDateIso to $endDateIso.
- Prefer walkable clusters; minimize backtracking.
- Output ONLY valid JSON (no markdown, no commentary).
''';

    final r = await chat(
      model: model,
      messages: [
        {'role': 'system', 'content': sys},
        {'role': 'user', 'content': user},
      ],
      temperature: 0.6,
      maxTokens: 1200,
    ); // Messages follow system+user roles and are sent as an array per chat completions guidance [5][17]

    return r.fold(
      onSuccess: (data) {
        final content = _firstMessage(data);
        if (content == null || content.isEmpty) {
          return Err<Map<String, dynamic>>(ApiError('Empty response'));
        }
        final json = _extractJson(content);
        if (json == null) {
          return Err<Map<String, dynamic>>(
              ApiError('Failed to parse plan JSON'));
        }
        return Ok(json);
      },
      onError: (e) => Err<Map<String, dynamic>>(e),
    );
  }

  /// Suggest multiple itinerary stubs for a destination.
  ///
  /// Returns: [{ "title":"", "days": n, "highlights": ["",""], "budgetFrom": num? }]
  Future<Result<List<Map<String, dynamic>>>> suggestItineraries({
    required String destination,
    int maxSuggestions = 5,
    String? model,
  }) async {
    const sys =
        'You are Navee, outputting STRICT JSON arrays only.'; // System instruction to constrain output format [5]
    final user = '''
Suggest up to $maxSuggestions high-level itinerary ideas for $destination.
Schema:
[
  {"title":"", "days": 3, "highlights": ["","",""], "budgetFrom": null}
]
Only return JSON array with objects following the schema; no comments.
''';

    final r = await chat(
      model: model,
      messages: [
        {'role': 'system', 'content': sys},
        {'role': 'user', 'content': user},
      ],
      temperature: 0.8,
      maxTokens: 800,
    ); // Chat request uses JSON body and returns a standard choices[].message.content payload to parse [17][6]

    return r.fold(
      onSuccess: (data) {
        final content = _firstMessage(data);
        if (content == null || content.isEmpty) {
          return Err<List<Map<String, dynamic>>>(ApiError('Empty response'));
        }
        final json = _extractJson(content);
        if (json is List) {
          return Ok(List<Map<String, dynamic>>.from(json));
        }
        return Err<List<Map<String, dynamic>>>(
            ApiError('Unexpected suggestions format'));
      },
      onError: (e) => Err<List<Map<String, dynamic>>>(e),
    );
  }

  // ------------------------
  // Moderation
  // ------------------------

  /// Optional moderation endpoint compatibility; returns raw provider payload.
  Future<Result<Map<String, dynamic>>> moderate(
      {required String input, String? model}) async {
    try {
      final body = {
        if (model != null) 'model': model,
        'input': input,
      };
      final res = await _client
          .post(_u('/moderations'), headers: _headers(), body: jsonEncode(body))
          .timeout(
              timeout); // JSON Content-Type is the standard for POST request bodies conveying JSON payloads [16][13]

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return Err<Map<String, dynamic>>(
            MapError.fromResponse(res).toApiError());
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return Ok(data);
    } on TimeoutException catch (e) {
      return Err(ApiError('Request timed out', cause: e));
    } on http.ClientException catch (e) {
      return Err(ApiError('Network error', cause: e));
    } catch (e) {
      return Err(ApiError('Unexpected error', cause: e));
    }
  }

  // ------------------------
  // Utilities
  // ------------------------

  /// Extract the first message content from an OpenAI-compatible response.
  String? _firstMessage(Map<String, dynamic> data) {
    try {
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final msg = (choices.first as Map)['message'] as Map?;
      return msg?['content']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Try to parse JSON safely from content; supports cases where the model might
  /// return fenced blocks `````` or plain JSON.
  dynamic _extractJson(String content) {
    final trimmed = content.trim();
    try {
      // Remove fenced markdown if present
      final cleaned = _stripFences(trimmed);
      return jsonDecode(cleaned);
    } catch (_) {
      return null;
    }
  }

  String _stripFences(String s) {
    final fence = RegExp(r'^``````$', multiLine: true);
    final m = fence.firstMatch(s);
    if (m != null && m.groupCount >= 1) return m.group(1)!;
    return s;
    // Chat completions content is plain text; clients often strip code fences before JSON decoding [17][8]
  }
}

/// Helper to turn non-2xx http.Response into ApiError with a safe message.
class MapError {
  MapError({required this.status, required this.message, this.body});

  final int status;
  final String message;
  final String? body;

  static MapError fromResponse(http.Response res) {
    String msg = 'HTTP ${res.statusCode}';
    try {
      final json = jsonDecode(res.body);
      if (json is Map && json['error'] != null) {
        final e = json['error'];
        if (e is Map && e['message'] is String) msg = e['message'] as String;
        if (e is String) msg = e;
      }
    } catch (_) {
      // keep default message
    }
    return MapError(status: res.statusCode, message: msg, body: res.body);
  }

  ApiError toApiError() => ApiError(message, status: status);
}
