// lib/models/conversation_summary.dart

class ConversationSummary {
  final String id;
  final String title;
  final String lastMessage;
  final String lastMessageSender;
  final DateTime lastMessageTime;
  final int unreadCount;
  final List<String> participants;
  final String? avatarUrl;
  final bool isGroup;

  const ConversationSummary({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.lastMessageSender,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.participants,
    this.avatarUrl,
    this.isGroup = false,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      lastMessage: json['lastMessage'] ?? '',
      lastMessageSender: json['lastMessageSender'] ?? '',
      lastMessageTime: DateTime.parse(json['lastMessageTime']),
      unreadCount: json['unreadCount'] ?? 0,
      participants: List<String>.from(json['participants'] ?? []),
      avatarUrl: json['avatarUrl'],
      isGroup: json['isGroup'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lastMessage': lastMessage,
      'lastMessageSender': lastMessageSender,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'participants': participants,
      'avatarUrl': avatarUrl,
      'isGroup': isGroup,
    };
  }

  ConversationSummary copyWith({
    String? id,
    String? title,
    String? lastMessage,
    String? lastMessageSender,
    DateTime? lastMessageTime,
    int? unreadCount,
    List<String>? participants,
    String? avatarUrl,
    bool? isGroup,
  }) {
    return ConversationSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      participants: participants ?? this.participants,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGroup: isGroup ?? this.isGroup,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConversationSummary &&
        other.id == id &&
        other.title == title &&
        other.lastMessage == lastMessage &&
        other.lastMessageSender == lastMessageSender &&
        other.lastMessageTime == lastMessageTime &&
        other.unreadCount == unreadCount &&
        other.participants == participants &&
        other.avatarUrl == avatarUrl &&
        other.isGroup == isGroup;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      lastMessage,
      lastMessageSender,
      lastMessageTime,
      unreadCount,
      participants,
      avatarUrl,
      isGroup,
    );
  }

  @override
  String toString() {
    return 'ConversationSummary(id: $id, title: $title, lastMessage: $lastMessage, unreadCount: $unreadCount)';
  }
}

