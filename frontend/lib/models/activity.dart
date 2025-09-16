// lib/models/activity.dart

import 'package:flutter/foundation.dart';

/// The type/kind of an activity event in the app.
/// Uses enhanced enums; serialize with `.name` and parse with `values.byName`.
enum ActivityKind {
  like,
  comment,
  follow,
  message,
  review,
  wishlistAdd,
  wishlistRemove,
  favorite,
  trailCreated,
  trailUpdated,
  system;
}

/// A small reference to an entity related to the activity (user/trail/place/post).
@immutable
class ActivityRef {
  const ActivityRef({
    required this.id,
    required this.type, // e.g., 'user' | 'trail' | 'place' | 'post'
    this.label,
    this.thumbnailUrl,
  });

  final String id;
  final String type;
  final String? label;
  final String? thumbnailUrl;

  ActivityRef copyWith({
    String? id,
    String? type,
    String? label,
    String? thumbnailUrl,
  }) {
    return ActivityRef(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  factory ActivityRef.fromJson(Map<String, dynamic> json) {
    return ActivityRef(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      label: (json['label'] as String?)?.toString(),
      thumbnailUrl: (json['thumbnailUrl'] as String?)?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      if (label != null) 'label': label,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ActivityRef &&
            other.id == id &&
            other.type == type &&
            other.label == label &&
            other.thumbnailUrl == thumbnailUrl);
  }

  @override
  int get hashCode => Object.hash(id, type, label, thumbnailUrl);

  @override
  String toString() => 'ActivityRef(id: $id, type: $type, label: $label)';
}

/// A normalized activity record suitable for feeds, inboxes, and notifications.
/// - Immutable with const constructor
/// - Manual JSON from/to for performance and zero dependencies
/// - Enum serialized via `.name` and parsed via `values.byName`
@immutable
class Activity {
  const Activity({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.read,
    this.actor,
    this.target,
    this.title,
    this.body,
    this.metadata,
  });

  final String id;
  final ActivityKind kind;
  final DateTime createdAt;
  final bool read;

  /// Who performed the activity (usually a user).
  final ActivityRef? actor;

  /// The object of the activity (trail/place/post/user).
  final ActivityRef? target;

  /// Short headline for compact UI.
  final String? title;

  /// Optional detailed text.
  final String? body;

  /// Extra data for flexible server payloads (IDs, flags, counters).
  final Map<String, dynamic>? metadata;

  bool get isUnread => !read;

  Activity copyWith({
    String? id,
    ActivityKind? kind,
    DateTime? createdAt,
    bool? read,
    ActivityRef? actor,
    ActivityRef? target,
    String? title,
    String? body,
    Map<String, dynamic>? metadata,
  }) {
    return Activity(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      actor: actor ?? this.actor,
      target: target ?? this.target,
      title: title ?? this.title,
      body: body ?? this.body,
      metadata: metadata ?? this.metadata,
    );
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    // Parse enum safely using values.byName; fall back to system.
    final kindStr = (json['kind'] ?? json['type'] ?? 'system').toString();
    ActivityKind kindParsed;
    try {
      kindParsed = ActivityKind.values.byName(kindStr);
    } catch (_) {
      kindParsed = ActivityKind.system;
    }

    return Activity(
      id: (json['id'] ?? '').toString(),
      kind: kindParsed,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      read: (json['read'] as bool?) ?? false,
      actor: (json['actor'] is Map<String, dynamic>) ? ActivityRef.fromJson(json['actor'] as Map<String, dynamic>) : null,
      target: (json['target'] is Map<String, dynamic>) ? ActivityRef.fromJson(json['target'] as Map<String, dynamic>) : null,
      title: (json['title'] as String?)?.toString(),
      body: (json['body'] as String?)?.toString(),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      // Serialize enum as stable string name
      'kind': kind.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'read': read,
      if (actor != null) 'actor': actor!.toJson(),
      if (target != null) 'target': target!.toJson(),
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Activity &&
            other.id == id &&
            other.kind == kind &&
            other.createdAt == createdAt &&
            other.read == read &&
            mapEquals(other.metadata, metadata) &&
            other.actor == actor &&
            other.target == target &&
            other.title == title &&
            other.body == body);
  }

  @override
  int get hashCode => Object.hash(id, kind, createdAt, read, actor, target, title, body, _mapHash(metadata));

  int _mapHash(Map<String, dynamic>? m) {
    if (m == null) return 0;
    // Order-independent hash for small metadata maps
    return Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
  }

  @override
  String toString() => 'Activity(id: $id, kind: ${kind.name}, read: $read)';
}
