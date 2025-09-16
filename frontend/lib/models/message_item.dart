// lib/models/message_item.dart

enum MessageType {
  text,
  image,
  location,
  place,
  booking,
  system,
}

class MessageItem {
  final String id;
  final String content;
  final MessageType type;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final String? replyToId;

  const MessageItem({
    required this.id,
    required this.content,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.metadata,
    this.isRead = false,
    this.replyToId,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      metadata: json['metadata'],
      isRead: json['isRead'] ?? false,
      replyToId: json['replyToId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.name,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'isRead': isRead,
      'replyToId': replyToId,
    };
  }

  MessageItem copyWith({
    String? id,
    String? content,
    MessageType? type,
    String? senderId,
    String? senderName,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    bool? isRead,
    String? replyToId,
  }) {
    return MessageItem(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
      replyToId: replyToId ?? this.replyToId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageItem &&
        other.id == id &&
        other.content == content &&
        other.type == type &&
        other.senderId == senderId &&
        other.senderName == senderName &&
        other.timestamp == timestamp &&
        other.metadata == metadata &&
        other.isRead == isRead &&
        other.replyToId == replyToId;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      content,
      type,
      senderId,
      senderName,
      timestamp,
      metadata,
      isRead,
      replyToId,
    );
  }

  @override
  String toString() {
    return 'MessageItem(id: $id, content: $content, type: $type, sender: $senderName, timestamp: $timestamp)';
  }
}

