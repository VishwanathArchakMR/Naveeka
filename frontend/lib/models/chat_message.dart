// lib/models/chat_message.dart

import 'package:flutter/foundation.dart';

/// The class of message content used by the UI and delivery pipeline. [text|image|video|audio|file|location|system] [15]
enum ChatMessageType { text, image, video, audio, file, location, system }

/// Delivery status for reliable UX: pending -> sent -> delivered -> read, with failed on error. [13][10]
enum ChatMessageStatus { pending, sent, delivered, read, failed }

/// A simple geo location payload for location messages or inline pins. [1]
@immutable
class ChatLocation {
  const ChatLocation({required this.lat, required this.lng, this.label, this.address, this.placeId});

  final double lat;
  final double lng;
  final String? label;
  final String? address;
  final String? placeId;

  ChatLocation copyWith({double? lat, double? lng, String? label, String? address, String? placeId}) {
    return ChatLocation(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      label: label ?? this.label,
      address: address ?? this.address,
      placeId: placeId ?? this.placeId,
    );
  }

  factory ChatLocation.fromJson(Map<String, dynamic> json) {
    return ChatLocation(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      label: (json['label'] as String?)?.toString(),
      address: (json['address'] as String?)?.toString(),
      placeId: (json['placeId'] as String?)?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': lat,
        'lng': lng,
        if (label != null) 'label': label,
        if (address != null) 'address': address,
        if (placeId != null) 'placeId': placeId,
      };

  @override
  bool operator ==(Object other) =>
      other is ChatLocation && other.lat == lat && other.lng == lng && other.label == label && other.address == address && other.placeId == placeId;

  @override
  int get hashCode => Object.hash(lat, lng, label, address, placeId);
}

/// A typed attachment supporting media and generic files with optional dimensions/duration/thumb. [1]
@immutable
class ChatAttachment {
  const ChatAttachment({
    required this.url,
    required this.kind, // image|video|audio|file
    this.name,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.durationSeconds,
    this.thumbnailUrl,
    this.metadata,
  });

  final String url;
  final String kind;
  final String? name;
  final String? mimeType;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final Map<String, dynamic>? metadata;

  ChatAttachment copyWith({
    String? url,
    String? kind,
    String? name,
    String? mimeType,
    int? sizeBytes,
    int? width,
    int? height,
    int? durationSeconds,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) {
    return ChatAttachment(
      url: url ?? this.url,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        url: (json['url'] ?? '').toString(),
        kind: (json['kind'] ?? 'file').toString(),
        name: (json['name'] as String?)?.toString(),
        mimeType: (json['mimeType'] as String?)?.toString(),
        sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        thumbnailUrl: (json['thumbnailUrl'] as String?)?.toString(),
        metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'kind': kind,
        if (name != null) 'name': name,
        if (mimeType != null) 'mimeType': mimeType,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is ChatAttachment &&
      other.url == url &&
      other.kind == kind &&
      other.name == name &&
      other.mimeType == mimeType &&
      other.sizeBytes == sizeBytes &&
      other.width == width &&
      other.height == height &&
      other.durationSeconds == durationSeconds &&
      other.thumbnailUrl == thumbnailUrl &&
      mapEquals(other.metadata, metadata);

  @override
  int get hashCode =>
      Object.hash(url, kind, name, mimeType, sizeBytes, width, height, durationSeconds, thumbnailUrl, _mapHash(metadata));

  int _mapHash(Map<String, dynamic>? m) => m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}

/// A single emoji reaction by a user on a message. [1]
@immutable
class ChatReaction {
  const ChatReaction({required this.userId, required this.emoji, required this.createdAt});

  final String userId;
  final String emoji;
  final DateTime createdAt;

  ChatReaction copyWith({String? userId, String? emoji, DateTime? createdAt}) =>
      ChatReaction(userId: userId ?? this.userId, emoji: emoji ?? this.emoji, createdAt: createdAt ?? this.createdAt);

  factory ChatReaction.fromJson(Map<String, dynamic> json) => ChatReaction(
        userId: (json['userId'] ?? '').toString(),
        emoji: (json['emoji'] ?? '').toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userId': userId,
        'emoji': emoji,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is ChatReaction && other.userId == userId && other.emoji == emoji && other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(userId, emoji, createdAt);
}

/// Root chat message model used across message lists, inbox previews, and send flows. [1]
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.updatedAt,
    this.text,
    this.attachments = const <ChatAttachment>[],
    this.location,
    this.replyToId,
    this.status = ChatMessageStatus.sent,
    this.readBy = const <String>[],
    this.deliveredTo = const <String>[],
    this.reactions = const <ChatReaction>[],
    this.metadata,
  });

  final String id;
  final String conversationId;
  final String senderId;

  final ChatMessageType type;
  final DateTime createdAt;
  final DateTime? updatedAt;

  final String? text;
  final List<ChatAttachment> attachments;
  final ChatLocation? location;

  final String? replyToId;

  final ChatMessageStatus status;
  final List<String> readBy;
  final List<String> deliveredTo;

  final List<ChatReaction> reactions;
  final Map<String, dynamic>? metadata;

  bool get hasText => (text ?? '').trim().isNotEmpty;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasLocation => location != null;

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    ChatMessageType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? text,
    List<ChatAttachment>? attachments,
    ChatLocation? location,
    String? replyToId,
    ChatMessageStatus? status,
    List<String>? readBy,
    List<String>? deliveredTo,
    List<ChatReaction>? reactions,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      location: location ?? this.location,
      replyToId: replyToId ?? this.replyToId,
      status: status ?? this.status,
      readBy: readBy ?? this.readBy,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      reactions: reactions ?? this.reactions,
      metadata: metadata ?? this.metadata,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    ChatMessageType parseType(Object? v) {
      final s = (v ?? 'text').toString();
      try {
        return ChatMessageType.values.byName(s);
      } catch (_) {
        // fallback for common synonyms
        switch (s.toLowerCase()) {
          case 'photo':
            return ChatMessageType.image;
          case 'voice':
          case 'audio':
            return ChatMessageType.audio;
          default:
            return ChatMessageType.text;
        }
      }
    } // [12][6]

    ChatMessageStatus parseStatus(Object? v) {
      final s = (v ?? 'sent').toString();
      try {
        return ChatMessageStatus.values.byName(s);
      } catch (_) {
        switch (s.toLowerCase()) {
          case 'pending':
            return ChatMessageStatus.pending;
          case 'delivered':
            return ChatMessageStatus.delivered;
          case 'read':
          case 'seen':
            return ChatMessageStatus.read;
          case 'failed':
          case 'error':
            return ChatMessageStatus.failed;
          default:
            return ChatMessageStatus.sent;
        }
      }
    } // [13][10]

    final atts = ((json['attachments'] as List?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChatAttachment.fromJson)
        .toList(growable: false);

    final reacts = ((json['reactions'] as List?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChatReaction.fromJson)
        .toList(growable: false);

    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      type: parseType(json['type']),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      text: (json['text'] as String?)?.toString(),
      attachments: atts,
      location: json['location'] != null ? ChatLocation.fromJson((json['location'] as Map).cast<String, dynamic>()) : null,
      replyToId: (json['replyToId'] as String?)?.toString(),
      status: parseStatus(json['status']),
      readBy: ((json['readBy'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      deliveredTo: ((json['deliveredTo'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      reactions: reacts,
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  } // [1][2]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'type': type.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (text != null) 'text': text,
        if (attachments.isNotEmpty) 'attachments': attachments.map((e) => e.toJson()).toList(growable: false),
        if (location != null) 'location': location!.toJson(),
        if (replyToId != null) 'replyToId': replyToId,
        'status': status.name,
        if (readBy.isNotEmpty) 'readBy': readBy,
        if (deliveredTo.isNotEmpty) 'deliveredTo': deliveredTo,
        if (reactions.isNotEmpty) 'reactions': reactions.map((e) => e.toJson()).toList(growable: false),
        if (metadata != null) 'metadata': metadata,
      }; // [1][15]

  @override
  bool operator ==(Object other) =>
      other is ChatMessage &&
      other.id == id &&
      other.conversationId == conversationId &&
      other.senderId == senderId &&
      other.type == type &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.text == text &&
      listEquals(other.attachments, attachments) &&
      other.location == location &&
      other.replyToId == replyToId &&
      other.status == status &&
      listEquals(other.readBy, readBy) &&
      listEquals(other.deliveredTo, deliveredTo) &&
      listEquals(other.reactions, reactions) &&
      mapEquals(other.metadata, metadata); // [1]

  @override
  int get hashCode => Object.hash(
        id,
        conversationId,
        senderId,
        type,
        createdAt,
        updatedAt,
        text,
        Object.hashAll(attachments),
        location,
        replyToId,
        status,
        Object.hashAll(readBy),
        Object.hashAll(deliveredTo),
        Object.hashAll(reactions),
        _mapHash(metadata),
      ); // [1]

  int _mapHash(Map<String, dynamic>? m) => m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value))); // [1]
}
