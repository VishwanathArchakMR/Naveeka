// lib/features/quick_actions/data/messages_api.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Unified result wrapper compatible with fold/when patterns used across data modules.
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

/// Client configuration for base URL, timeouts, and default headers.
class MessagesApiConfig {
  const MessagesApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 25),
    this.sendTimeout = const Duration(seconds: 25),
    this.defaultHeaders = const {'Accept': 'application/json', 'Content-Type': 'application/json'},
  });
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final Map<String, String> defaultHeaders;
}

/// Messages API built on Dio with CancelToken support and multipart uploads.
class MessagesApi {
  MessagesApi({Dio? dio, MessagesApiConfig? config, String? authToken})
      : _config = config ?? const MessagesApiConfig(baseUrl: ''),
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
  final MessagesApiConfig _config;

  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // ----------------------------
  // Conversations
  // ----------------------------

  Future<ApiResult<ConversationPage>> listConversations({
    int page = 1,
    int limit = 30,
    String? q,
    CancelToken? cancelToken,
  }) async {
    final query = {
      'page': page,
      'limit': limit,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };
    return _get<ConversationPage>(
      path: '/v1/messages/conversations',
      query: query,
      parse: (data) => ConversationPage.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 2,
    ); // GET requests are cancelable via CancelToken and include limited retries for resilience. [21][3]
  }

  Future<ApiResult<Conversation>> getConversation({
    required String conversationId,
    CancelToken? cancelToken,
  }) async {
    return _get<Conversation>(
      path: '/v1/messages/conversations/$conversationId',
      parse: (data) => Conversation.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 1,
    ); // Basic GET that returns a typed Conversation with ISO‑8601 timestamps parsed into DateTime. [20]
  }

  Future<ApiResult<Conversation>> createConversation({
    required List<String> participantIds,
    String? title,
    CancelToken? cancelToken,
  }) async {
    return _post<Conversation>(
      path: '/v1/messages/conversations',
      body: {'participants': participantIds, if (title != null && title.trim().isNotEmpty) 'title': title.trim()},
      parse: (data) => Conversation.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 0,
    ); // POST avoids retries to prevent duplicate creation while still supporting cancelation. [21][3]
  }

  Future<ApiResult<void>> deleteConversation({
    required String conversationId,
    CancelToken? cancelToken,
  }) async {
    return _delete<void>(
      path: '/v1/messages/conversations/$conversationId',
      parse: (_) {},
      cancelToken: cancelToken,
    ); // DELETE is idempotent on the server and returns void for simpler UI flows. [3]
  }

  // ----------------------------
  // Messages (paging, send, mark read, typing)
  // ----------------------------

  Future<ApiResult<MessagePage>> listMessages({
    required String conversationId,
    int page = 1,
    int limit = 50,
    String? beforeId,
    String? afterId,
    CancelToken? cancelToken,
  }) async {
    final query = {
      'page': page,
      'limit': limit,
      if (beforeId != null) 'beforeId': beforeId,
      if (afterId != null) 'afterId': afterId,
    };
    return _get<MessagePage>(
      path: '/v1/messages/conversations/$conversationId/messages',
      query: query,
      parse: (data) => MessagePage.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 2,
    ); // Standard page/limit pagination with directional cursors supported by beforeId/afterId. [3]
  }

  Future<ApiResult<Message>> sendMessageText({
    required String conversationId,
    required String text,
    String? clientId, // idempotency key for dedup
    CancelToken? cancelToken,
  }) async {
    final headers = {if (clientId != null && clientId.isNotEmpty) 'Idempotency-Key': clientId};
    return _post<Message>(
      path: '/v1/messages/conversations/$conversationId/messages',
      body: {'type': 'text', 'text': text},
      extraHeaders: headers,
      parse: (data) => Message.fromJson(data as Map<String, dynamic>),
      cancelToken: cancelToken,
      retries: 0,
    ); // Text messages are simple JSON posts, with optional Idempotency-Key to deduplicate on the server. [3]
  }

  Future<ApiResult<Message>> sendMessageWithAttachments({
    required String conversationId,
    String? text,
    required List<AttachmentInput> attachments,
    String? clientId,
    CancelToken? cancelToken,
  }) async {
    // Build multipart form with text + files.
    final files = <MapEntry<String, MultipartFile>>[];
    for (var i = 0; i < attachments.length; i++) {
      final a = attachments[i];
      final mf = MultipartFile.fromBytes(
        a.bytes,
        filename: a.filename,
        contentType: a.contentType != null ? HeadersContentType.parse(a.contentType!) : null,
      );
      files.add(MapEntry('files', mf));
    }
    final form = FormData.fromMap({
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      'type': 'mixed',
      'files': files,
    });
    final opts = Options(headers: {if (clientId != null && clientId.isNotEmpty) 'Idempotency-Key': clientId});
    try {
      final res = await _dio.post<dynamic>(
        '/v1/messages/conversations/$conversationId/messages',
        data: form,
        cancelToken: cancelToken,
        options: opts,
      );
      return _parseResponse<Message>(res, (data) => Message.fromJson(data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return const ApiFailure<Message>(ApiError(message: 'Cancelled', code: -1));
      }
      return ApiFailure<Message>(_mapDioError(e));
    }
  } // Multipart uploads use Dio’s MultipartFile and FormData to send binary attachments along with text fields. [2][3]

  Future<ApiResult<void>> markRead({
    required String conversationId,
    required String messageId,
    DateTime? at,
    CancelToken? cancelToken,
  }) async {
    return _post<void>(
      path: '/v1/messages/conversations/$conversationId/read',
      body: {'messageId': messageId, 'at': (at ?? DateTime.now()).toIso8601String()},
      parse: (_) {},
      cancelToken: cancelToken,
      retries: 0,
    ); // Read receipts send ISO‑8601 timestamps using DateTime.toIso8601String for portable serialization. [7]
  }

  Future<ApiResult<void>> typing({
    required String conversationId,
    required bool isTyping,
    CancelToken? cancelToken,
  }) async {
    return _post<void>(
      path: '/v1/messages/conversations/$conversationId/typing',
      body: {'typing': isTyping},
      parse: (_) {},
      cancelToken: cancelToken,
      retries: 0,
    ); // Typing indicators are short‑lived POSTs that the server can broadcast to other participants. [3]
  }

  Future<ApiResult<void>> deleteMessage({
    required String conversationId,
    required String messageId,
    CancelToken? cancelToken,
  }) async {
    return _delete<void>(
      path: '/v1/messages/conversations/$conversationId/messages/$messageId',
      parse: (_) {},
      cancelToken: cancelToken,
    ); // Message deletion is idempotent server‑side and returns void for simpler UI handling. [3]
  }

  // ----------------------------
  // Low‑level helpers with retry for GET
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
        final res = await _dio.get<dynamic>(path, queryParameters: query, cancelToken: cancelToken);
        return _parseResponse<T>(res, parse);
      },
    ); // CancelToken enables canceling in‑flight GETs when the view unmounts or filters change. [21]
  }

  Future<ApiResult<T>> _post<T>({
    required String path,
    required Map<String, dynamic>? body,
    required T Function(dynamic data) parse,
    Map<String, String>? extraHeaders,
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
          options: Options(headers: extraHeaders),
        );
        return _parseResponse<T>(res, parse);
      },
    ); // POST is not retried aggressively to avoid duplicate mutations while still leveraging Dio’s cancellations. [3][21]
  }

  Future<ApiResult<T>> _delete<T>({
    required String path,
    required T Function(dynamic data) parse,
    CancelToken? cancelToken,
    int retries = 0,
  }) async {
    return _withRetry<T>(
      retries: retries,
      request: () async {
        final res = await _dio.delete<dynamic>(path, cancelToken: cancelToken);
        return _parseResponse<T>(res, parse);
      },
    ); // DELETE avoids retries and supports cancellation with CancelToken for responsive UIs. [21][3]
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
        if (CancelToken.isCancel(e)) {
          return ApiFailure<T>(const ApiError(message: 'Cancelled', code: -1));
        }
        attempt += 1;
        final transient = _isTransient(e);
        if (!transient || attempt > retries) {
          return ApiFailure<T>(_mapDioError(e));
        }
        final delayMs = _backoffDelayMs(attempt);
        await Future.delayed(Duration(milliseconds: delayMs));
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
        return code >= 500;
      default:
        return false;
    }
  }

  int _backoffDelayMs(int attempt) {
    final base = 250 * (1 << (attempt - 1));
    final jitter = (base * 0.2).toInt();
    return base + (DateTime.now().microsecondsSinceEpoch % (jitter == 0 ? 1 : jitter));
  }

  ApiResult<T> _parseResponse<T>(Response res, T Function(dynamic) parse) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) {
      return ApiSuccess<T>(parse(res.data));
    }
    return ApiFailure<T>(ApiError(
      message: res.statusMessage ?? 'HTTP $code',
      code: code,
      details: _asMap(res.data),
    ));
  }

  ApiError _mapDioError(DioException e) {
    final code = e.response?.statusCode;
    final msg = e.message ?? 'Network error';
    return ApiError(message: msg, code: code, details: _asMap(e.response?.data));
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

class Conversation {
  Conversation({
    required this.id,
    required this.createdAt,
    this.title,
    this.lastMessage,
    this.unreadCount = 0,
    this.participants = const [],
  });

  final String id;
  final DateTime createdAt;
  final String? title;
  final Message? lastMessage;
  final int unreadCount;
  final List<UserCard> participants;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: (json['id'] ?? '') as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      title: json['title'] as String?,
      lastMessage: json['lastMessage'] != null ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>) : null,
      unreadCount: (json['unreadCount'] ?? 0) as int,
      participants: ((json['participants'] as List?) ?? const [])
          .map((e) => UserCard.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class ConversationPage {
  ConversationPage({required this.items, required this.page, required this.limit, required this.total});
  final List<Conversation> items;
  final int page;
  final int limit;
  final int total;

  factory ConversationPage.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List?) ?? const [];
    return ConversationPage(
      items: list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList(growable: false),
      page: (json['page'] ?? 1) as int,
      limit: (json['limit'] ?? list.length) as int,
      total: (json['total'] ?? list.length) as int,
    );
  }
}

class Message {
  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.sentAt,
    required this.type, // text | image | file | mixed
    this.text,
    this.attachments = const [],
    this.editedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final DateTime sentAt;
  final String type;
  final String? text;
  final List<Attachment> attachments;
  final DateTime? editedAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] ?? '') as String,
      conversationId: (json['conversationId'] ?? '') as String,
      senderId: (json['senderId'] ?? '') as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      type: (json['type'] ?? 'text') as String,
      text: json['text'] as String?,
      attachments: ((json['attachments'] as List?) ?? const [])
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt'] as String) : null,
    );
  }
}

class MessagePage {
  MessagePage({required this.items, required this.page, required this.limit, required this.total});
  final List<Message> items;
  final int page;
  final int limit;
  final int total;

  factory MessagePage.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List?) ?? const [];
    return MessagePage(
      items: list.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList(growable: false),
      page: (json['page'] ?? 1) as int,
      limit: (json['limit'] ?? list.length) as int,
      total: (json['total'] ?? list.length) as int,
    );
  }
}

class Attachment {
  Attachment({
    required this.url,
    required this.filename,
    required this.bytes,
    required this.mime,
    this.width,
    this.height,
  });

  final String url;
  final String filename;
  final int bytes;
  final String mime;
  final int? width;
  final int? height;

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      url: (json['url'] ?? '') as String,
      filename: (json['filename'] ?? '') as String,
      bytes: (json['bytes'] ?? 0) as int,
      mime: (json['mime'] ?? 'application/octet-stream') as String,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }
}

class UserCard {
  UserCard({required this.id, required this.name, this.username, this.avatarUrl, this.verified = false});
  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final bool verified;

  factory UserCard.fromJson(Map<String, dynamic> json) {
    return UserCard(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      verified: (json['verified'] ?? false) as bool,
    );
  }
}

/// Input for uploading an attachment using multipart/form-data (bytes + filename + contentType).
class AttachmentInput {
  AttachmentInput({required this.bytes, required this.filename, this.contentType});
  final Uint8List bytes;
  final String filename;
  final String? contentType;
}
