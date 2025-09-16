// lib/models/history_item.dart

import 'package:flutter/foundation.dart';

/// High-level category of a history/audit record. [create/update/delete/view/auth/share/system]
enum HistoryKind {
  created,
  updated,
  deleted,
  viewed,
  shared,
  favorited,
  unfavorited,
  wishlisted,
  unwishlisted,
  messageSent,
  login,
  logout,
  bookingCreated,
  bookingCanceled,
  reviewPosted,
  system,
}

/// What object this history item refers to.
enum HistoryTargetType {
  user,
  place,
  trail,
  post,
  review,
  booking,
  message,
  system,
  other,
}

/// Severity for quick filtering/badging.
enum HistorySeverity { info, warning, error }

/// A single field-level change, useful for audit details and diff views.
@immutable
class HistoryChange {
  const HistoryChange({
    required this.field,
    this.oldValue,
    this.newValue,
  });

  final String field;
  final String? oldValue;
  final String? newValue;

  HistoryChange copyWith({String? field, String? oldValue, String? newValue}) {
    return HistoryChange(
      field: field ?? this.field,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
    );
  }

  factory HistoryChange.fromJson(Map<String, dynamic> json) {
    return HistoryChange(
      field: (json['field'] ?? '').toString(),
      oldValue: (json['oldValue'] as String?)?.toString(),
      newValue: (json['newValue'] as String?)?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'field': field,
        if (oldValue != null) 'oldValue': oldValue,
        if (newValue != null) 'newValue': newValue,
      };

  @override
  bool operator ==(Object other) =>
      other is HistoryChange && other.field == field && other.oldValue == oldValue && other.newValue == newValue;

  @override
  int get hashCode => Object.hash(field, oldValue, newValue);
}

/// A normalized history/audit feed record for lists, detail timelines, and export.
@immutable
class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.kind,
    required this.targetType,
    required this.timestamp,
    this.actorId,
    this.targetId,
    this.summary,
    this.details,
    this.severity = HistorySeverity.info,
    this.ipAddress,
    this.userAgent,
    this.changes = const <HistoryChange>[],
    this.metadata,
  });

  /// Unique identifier of this history record.
  final String id;

  /// Category of action that occurred.
  final HistoryKind kind;

  /// The domain type of the target affected by this action.
  final HistoryTargetType targetType;

  /// When this action occurred (UTC recommended).
  final DateTime timestamp;

  /// Who performed the action (user id or service principal id).
  final String? actorId;

  /// The specific target id (e.g., placeId, trailId, bookingId).
  final String? targetId;

  /// Short, human-friendly summary for list rows.
  final String? summary;

  /// Optional longer text describing the event.
  final String? details;

  /// For quick filtering and badges.
  final HistorySeverity severity;

  /// Optional network info captured by backend.
  final String? ipAddress;

  /// Optional client identifier string.
  final String? userAgent;

  /// Field-level changes associated with this record, if any.
  final List<HistoryChange> changes;

  /// Extra server-defined attributes.
  final Map<String, dynamic>? metadata;

  /// Convenience label: "<kind> • <targetType>".
  String get label => '${kind.name} • ${targetType.name}';

  HistoryItem copyWith({
    String? id,
    HistoryKind? kind,
    HistoryTargetType? targetType,
    DateTime? timestamp,
    String? actorId,
    String? targetId,
    String? summary,
    String? details,
    HistorySeverity? severity,
    String? ipAddress,
    String? userAgent,
    List<HistoryChange>? changes,
    Map<String, dynamic>? metadata,
  }) {
    return HistoryItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      targetType: targetType ?? this.targetType,
      timestamp: timestamp ?? this.timestamp,
      actorId: actorId ?? this.actorId,
      targetId: targetId ?? this.targetId,
      summary: summary ?? this.summary,
      details: details ?? this.details,
      severity: severity ?? this.severity,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      changes: changes ?? this.changes,
      metadata: metadata ?? this.metadata,
    );
  }

  // -------- JSON --------

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    HistoryKind parseKind(Object? v) {
      final s = (v ?? 'system').toString();
      try {
        return HistoryKind.values.byName(s);
      } catch (_) {
        return HistoryKind.system;
      }
    }

    HistoryTargetType parseTarget(Object? v) {
      final s = (v ?? 'other').toString();
      try {
        return HistoryTargetType.values.byName(s);
      } catch (_) {
        return HistoryTargetType.other;
      }
    }

    HistorySeverity parseSeverity(Object? v) {
      final s = (v ?? 'info').toString();
      try {
        return HistorySeverity.values.byName(s);
      } catch (_) {
        return HistorySeverity.info;
      }
    }

    final rawChanges = (json['changes'] as List?) ?? const <dynamic>[];

    return HistoryItem(
      id: (json['id'] ?? '').toString(),
      kind: parseKind(json['kind']),
      targetType: parseTarget(json['targetType'] ?? json['target']),
      timestamp: DateTime.parse(json['timestamp'].toString()),
      actorId: (json['actorId'] as String?)?.toString(),
      targetId: (json['targetId'] as String?)?.toString(),
      summary: (json['summary'] as String?)?.toString(),
      details: (json['details'] as String?)?.toString(),
      severity: parseSeverity(json['severity']),
      ipAddress: (json['ipAddress'] as String?)?.toString(),
      userAgent: (json['userAgent'] as String?)?.toString(),
      changes: rawChanges.whereType<Map<String, dynamic>>().map(HistoryChange.fromJson).toList(growable: false),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  } // Manual JSON with enums via values.byName + safe fallback. [1][9]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'targetType': targetType.name,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (actorId != null) 'actorId': actorId,
        if (targetId != null) 'targetId': targetId,
        if (summary != null) 'summary': summary,
        if (details != null) 'details': details,
        'severity': severity.name,
        if (ipAddress != null) 'ipAddress': ipAddress,
        if (userAgent != null) 'userAgent': userAgent,
        if (changes.isNotEmpty) 'changes': changes.map((e) => e.toJson()).toList(growable: false),
        if (metadata != null) 'metadata': metadata,
      }; // Enum serialization with .name for stability. [1][6]

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is HistoryItem &&
            other.id == id &&
            other.kind == kind &&
            other.targetType == targetType &&
            other.timestamp == timestamp &&
            other.actorId == actorId &&
            other.targetId == targetId &&
            other.summary == summary &&
            other.details == details &&
            other.severity == severity &&
            other.ipAddress == ipAddress &&
            other.userAgent == userAgent &&
            listEquals(other.changes, changes) &&
            mapEquals(other.metadata, metadata));
  }

  @override
  int get hashCode => Object.hash(
        id,
        kind,
        targetType,
        timestamp,
        actorId,
        targetId,
        summary,
        details,
        severity,
        ipAddress,
        userAgent,
        Object.hashAll(changes),
        _mapHash(metadata),
      );

  int _mapHash(Map<String, dynamic>? m) =>
      m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
