// lib/models/review.dart

import 'package:flutter/foundation.dart';

/// The domain object a review refers to. [1]
enum ReviewTargetType {
  place,
  trail,
  hotel,
  restaurant,
  landmark,
  activity,
  bus,
  flight,
  cab,
  post,
  other,
}

/// Publication/moderation lifecycle for a review. [1]
enum ReviewStatus { published, pending, rejected, deleted, flagged, edited }

/// Small user profile shown with reviews. [1]
@immutable
class Reviewer {
  const Reviewer({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.verified = false,
    this.badges = const <String>[],
  });

  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final bool verified;
  final List<String> badges;

  String get handle => (username == null || username!.trim().isEmpty) ? '' : '@${username!.trim()}';

  Reviewer copyWith({
    String? id,
    String? displayName,
    String? username,
    String? avatarUrl,
    bool? verified,
    List<String>? badges,
  }) {
    return Reviewer(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      verified: verified ?? this.verified,
      badges: badges ?? this.badges,
    );
  }

  factory Reviewer.fromJson(Map<String, dynamic> json) => Reviewer(
        id: (json['id'] ?? '').toString(),
        displayName: (json['displayName'] ?? json['name'] ?? '').toString(),
        username: (json['username'] as String?)?.toString(),
        avatarUrl: (json['avatarUrl'] as String?)?.toString(),
        verified: (json['verified'] as bool?) ?? false,
        badges: ((json['badges'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'displayName': displayName,
        if (username != null) 'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'verified': verified,
        if (badges.isNotEmpty) 'badges': badges,
      };

  @override
  bool operator ==(Object other) =>
      other is Reviewer &&
      other.id == id &&
      other.displayName == displayName &&
      other.username == username &&
      other.avatarUrl == avatarUrl &&
      other.verified == verified &&
      listEquals(other.badges, badges);

  @override
  int get hashCode => Object.hash(id, displayName, username, avatarUrl, verified, Object.hashAll(badges));
}

/// Media attached to a review (images/videos/files). [1]
@immutable
class ReviewAttachment {
  const ReviewAttachment({
    required this.url,
    this.kind = 'image', // image|video|file
    this.mimeType,
    this.width,
    this.height,
    this.durationSeconds,
    this.thumbnailUrl,
    this.metadata,
  });

  final String url;
  final String kind;
  final String? mimeType;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final String? thumbnailUrl;
  final Map<String, dynamic>? metadata;

  ReviewAttachment copyWith({
    String? url,
    String? kind,
    String? mimeType,
    int? width,
    int? height,
    int? durationSeconds,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) {
    return ReviewAttachment(
      url: url ?? this.url,
      kind: kind ?? this.kind,
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  factory ReviewAttachment.fromJson(Map<String, dynamic> json) => ReviewAttachment(
        url: (json['url'] ?? '').toString(),
        kind: (json['kind'] ?? 'image').toString(),
        mimeType: (json['mimeType'] as String?)?.toString(),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        thumbnailUrl: (json['thumbnailUrl'] as String?)?.toString(),
        metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'kind': kind,
        if (mimeType != null) 'mimeType': mimeType,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is ReviewAttachment &&
      other.url == url &&
      other.kind == kind &&
      other.mimeType == mimeType &&
      other.width == width &&
      other.height == height &&
      other.durationSeconds == durationSeconds &&
      other.thumbnailUrl == thumbnailUrl &&
      mapEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(url, kind, mimeType, width, height, durationSeconds, thumbnailUrl, _mapHash(metadata));

  static int _mapHash(Map<String, dynamic>? m) =>
      m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}

/// Owner/host response to a review. [1]
@immutable
class OwnerResponse {
  const OwnerResponse({
    required this.text,
    required this.createdAt,
    this.userId,
    this.userName,
  });

  final String text;
  final DateTime createdAt;
  final String? userId;
  final String? userName;

  OwnerResponse copyWith({String? text, DateTime? createdAt, String? userId, String? userName}) {
    return OwnerResponse(
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
    );
  }

  factory OwnerResponse.fromJson(Map<String, dynamic> json) => OwnerResponse(
        text: (json['text'] ?? '').toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
        userId: (json['userId'] as String?)?.toString(),
        userName: (json['userName'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (userId != null) 'userId': userId,
        if (userName != null) 'userName': userName,
      };

  @override
  bool operator ==(Object other) =>
      other is OwnerResponse &&
      other.text == text &&
      other.createdAt == createdAt &&
      other.userId == userId &&
      other.userName == userName;

  @override
  int get hashCode => Object.hash(text, createdAt, userId, userName);
}

/// Optional threaded reply under a review. [1]
@immutable
class ReviewReply {
  const ReviewReply({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.userName,
    this.avatarUrl,
  });

  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;
  final String? userName;
  final String? avatarUrl;

  ReviewReply copyWith({
    String? id,
    String? userId,
    String? text,
    DateTime? createdAt,
    String? userName,
    String? avatarUrl,
  }) {
    return ReviewReply(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory ReviewReply.fromJson(Map<String, dynamic> json) => ReviewReply(
        id: (json['id'] ?? '').toString(),
        userId: (json['userId'] ?? '').toString(),
        text: (json['text'] ?? '').toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
        userName: (json['userName'] as String?)?.toString(),
        avatarUrl: (json['avatarUrl'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (userName != null) 'userName': userName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };

  @override
  bool operator ==(Object other) =>
      other is ReviewReply &&
      other.id == id &&
      other.userId == userId &&
      other.text == text &&
      other.createdAt == createdAt &&
      other.userName == userName &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(id, userId, text, createdAt, userName, avatarUrl);
}

/// Root Review model. [1]
@immutable
class Review {
  const Review({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reviewer,
    required this.rating, // 0.0 .. 5.0
    required this.createdAt,
    this.updatedAt,
    this.title,
    this.text,
    this.language,
    this.attachments = const <ReviewAttachment>[],
    this.tags = const <String>[],
    this.status = ReviewStatus.published,
    this.ownerResponse,
    this.replies = const <ReviewReply>[],
    this.helpfulCount = 0,
    this.reportCount = 0,
    this.myHelpful = false,
    this.myReported = false,
    this.visitDate,
    this.metadata,
  });

  final String id;

  final ReviewTargetType targetType;
  final String targetId;

  final Reviewer reviewer;

  final double rating;

  final DateTime createdAt;
  final DateTime? updatedAt;

  final String? title;
  final String? text;
  final String? language; // ISO language code like "en", "hi"

  final List<ReviewAttachment> attachments;
  final List<String> tags;

  final ReviewStatus status;

  final OwnerResponse? ownerResponse;
  final List<ReviewReply> replies;

  final int helpfulCount;
  final int reportCount;
  final bool myHelpful;
  final bool myReported;

  final DateTime? visitDate;

  final Map<String, dynamic>? metadata;

  // -------- Convenience --------

  bool get hasText => (text ?? '').trim().isNotEmpty; // [1]
  bool get hasAttachments => attachments.isNotEmpty; // [1]
  bool get hasOwnerResponse => ownerResponse != null; // [1]
  String get ratingLabel => '${rating.toStringAsFixed(1)}★'; // [1]
  String get contentSummary {
    final t = (text ?? '').trim();
    return t.length <= 160 ? t : '${t.substring(0, 157)}...';
  } // [1]

  Review copyWith({
    String? id,
    ReviewTargetType? targetType,
    String? targetId,
    Reviewer? reviewer,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    String? text,
    String? language,
    List<ReviewAttachment>? attachments,
    List<String>? tags,
    ReviewStatus? status,
    OwnerResponse? ownerResponse,
    List<ReviewReply>? replies,
    int? helpfulCount,
    int? reportCount,
    bool? myHelpful,
    bool? myReported,
    DateTime? visitDate,
    Map<String, dynamic>? metadata,
  }) {
    return Review(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      reviewer: reviewer ?? this.reviewer,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      text: text ?? this.text,
      language: language ?? this.language,
      attachments: attachments ?? this.attachments,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      ownerResponse: ownerResponse ?? this.ownerResponse,
      replies: replies ?? this.replies,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      reportCount: reportCount ?? this.reportCount,
      myHelpful: myHelpful ?? this.myHelpful,
      myReported: myReported ?? this.myReported,
      visitDate: visitDate ?? this.visitDate,
      metadata: metadata ?? this.metadata,
    );
  }

  // -------- JSON --------

  factory Review.fromJson(Map<String, dynamic> json) {
    ReviewTargetType parseTarget(Object? v) {
      final s = (v ?? 'other').toString();
      try {
        return ReviewTargetType.values.byName(s);
      } catch (_) {
        return ReviewTargetType.other;
      }
    } // Robust enum parsing via values.byName with fallback. [2]

    ReviewStatus parseStatus(Object? v) {
      final s = (v ?? 'published').toString();
      try {
        return ReviewStatus.values.byName(s);
      } catch (_) {
        return ReviewStatus.published;
      }
    } // Enum parsing with safe fallback. [2]

    final attRaw = (json['attachments'] as List?) ?? const <dynamic>[];
    final repRaw = (json['replies'] as List?) ?? const <dynamic>[];

    return Review(
      id: (json['id'] ?? '').toString(),
      targetType: parseTarget(json['targetType'] ?? json['target']),
      targetId: (json['targetId'] ?? '').toString(),
      reviewer: Reviewer.fromJson((json['reviewer'] as Map).cast<String, dynamic>()),
      rating: ((json['rating'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 5.0),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      title: (json['title'] as String?)?.toString(),
      text: (json['text'] as String?)?.toString(),
      language: (json['language'] as String?)?.toString(),
      attachments: attRaw.whereType<Map<String, dynamic>>().map(ReviewAttachment.fromJson).toList(growable: false),
      tags: ((json['tags'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      status: parseStatus(json['status']),
      ownerResponse: json['ownerResponse'] != null
          ? OwnerResponse.fromJson((json['ownerResponse'] as Map).cast<String, dynamic>())
          : null,
      replies: repRaw.whereType<Map<String, dynamic>>().map(ReviewReply.fromJson).toList(growable: false),
      helpfulCount: (json['helpfulCount'] as num?)?.toInt() ?? 0,
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      myHelpful: (json['myHelpful'] as bool?) ?? false,
      myReported: (json['myReported'] as bool?) ?? false,
      visitDate: json['visitDate'] != null ? DateTime.tryParse(json['visitDate'].toString()) : null,
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  } // Manual JSON per Flutter guidance keeps models fast and dependency-free. [1]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'targetType': targetType.name,
        'targetId': targetId,
        'reviewer': reviewer.toJson(),
        'rating': rating,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (title != null) 'title': title,
        if (text != null) 'text': text,
        if (language != null) 'language': language,
        if (attachments.isNotEmpty) 'attachments': attachments.map((a) => a.toJson()).toList(growable: false),
        if (tags.isNotEmpty) 'tags': tags,
        'status': status.name,
        if (ownerResponse != null) 'ownerResponse': ownerResponse!.toJson(),
        if (replies.isNotEmpty) 'replies': replies.map((r) => r.toJson()).toList(growable: false),
        'helpfulCount': helpfulCount,
        'reportCount': reportCount,
        'myHelpful': myHelpful,
        'myReported': myReported,
        if (visitDate != null) 'visitDate': visitDate!.toUtc().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      }; // Enums serialized via .name for stability and readability. [2]

  @override
  bool operator ==(Object other) =>
      other is Review &&
      other.id == id &&
      other.targetType == targetType &&
      other.targetId == targetId &&
      other.reviewer == reviewer &&
      other.rating == rating &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.title == title &&
      other.text == text &&
      other.language == language &&
      listEquals(other.attachments, attachments) &&
      listEquals(other.tags, tags) &&
      other.status == status &&
      other.ownerResponse == ownerResponse &&
      listEquals(other.replies, replies) &&
      other.helpfulCount == helpfulCount &&
      other.reportCount == reportCount &&
      other.myHelpful == myHelpful &&
      other.myReported == myReported &&
      other.visitDate == visitDate &&
      mapEquals(other.metadata, metadata); // Value equality supports reliable provider updates. [1]

  @override
  int get hashCode => Object.hash(
        id,
        targetType,
        targetId,
        reviewer,
        rating,
        createdAt,
        updatedAt,
        title,
        text,
        language,
        Object.hash(Object.hashAll(attachments), Object.hashAll(tags)),
        status,
        ownerResponse,
        Object.hashAll(replies),
        helpfulCount,
        reportCount,
        myHelpful,
        myReported,
        visitDate,
        _mapHash(metadata),
      ); // Stable hashing for list diffing. [1]

  static int _mapHash(Map<String, dynamic>? m) =>
      m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
