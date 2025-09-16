// lib/models/trail_post.dart

import 'package:flutter/foundation.dart';

import 'coordinates.dart';

/// The kind of post content shared to the trail feed. [19]
enum TrailPostType { photo, video, text, checkIn, route }

/// Visibility controls for social sharing. [19]
enum TrailPostVisibility { public, followers, private }

/// Publication/moderation lifecycle states. [19]
enum TrailPostStatus { published, pending, hidden, deleted, flagged, edited }

/// Minimal author profile for attribution in feeds. [9]
@immutable
class TrailAuthor {
  const TrailAuthor({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.verified = false,
  });

  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final bool verified;

  String get handle => (username == null || username!.trim().isEmpty) ? '' : '@${username!.trim()}'; // [9]

  TrailAuthor copyWith({
    String? id,
    String? displayName,
    String? username,
    String? avatarUrl,
    bool? verified,
  }) {
    return TrailAuthor(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      verified: verified ?? this.verified,
    );
  }

  factory TrailAuthor.fromJson(Map<String, dynamic> json) => TrailAuthor(
        id: (json['id'] ?? '').toString(),
        displayName: (json['displayName'] ?? json['name'] ?? '').toString(),
        username: (json['username'] as String?)?.toString(),
        avatarUrl: (json['avatarUrl'] as String?)?.toString(),
        verified: (json['verified'] as bool?) ?? false,
      ); // [9]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'displayName': displayName,
        if (username != null) 'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'verified': verified,
      }; // [9]

  @override
  bool operator ==(Object other) =>
      other is TrailAuthor &&
      other.id == id &&
      other.displayName == displayName &&
      other.username == username &&
      other.avatarUrl == avatarUrl &&
      other.verified == verified; // [9]

  @override
  int get hashCode => Object.hash(id, displayName, username, avatarUrl, verified); // [9]
}

/// Media attached to the post (image/video/file) with optional dimensions and thumbnails. [9]
@immutable
class TrailMedia {
  const TrailMedia({
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

  bool get isImage => kind.toLowerCase() == 'image'; // [9]
  bool get isVideo => kind.toLowerCase() == 'video'; // [9]

  TrailMedia copyWith({
    String? url,
    String? kind,
    String? mimeType,
    int? width,
    int? height,
    int? durationSeconds,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) {
    return TrailMedia(
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

  factory TrailMedia.fromJson(Map<String, dynamic> json) => TrailMedia(
        url: (json['url'] ?? '').toString(),
        kind: (json['kind'] ?? 'image').toString(),
        mimeType: (json['mimeType'] as String?)?.toString(),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        thumbnailUrl: (json['thumbnailUrl'] as String?)?.toString(),
        metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
      ); // [9]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        'kind': kind,
        if (mimeType != null) 'mimeType': mimeType,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (metadata != null) 'metadata': metadata,
      }; // [9]

  @override
  bool operator ==(Object other) =>
      other is TrailMedia &&
      other.url == url &&
      other.kind == kind &&
      other.mimeType == mimeType &&
      other.width == width &&
      other.height == height &&
      other.durationSeconds == durationSeconds &&
      other.thumbnailUrl == thumbnailUrl &&
      mapEquals(other.metadata, metadata); // [9]

  @override
  int get hashCode => Object.hash(url, kind, mimeType, width, height, durationSeconds, thumbnailUrl, _mapHash(metadata)); // [9]

  static int _mapHash(Map<String, dynamic>? m) =>
      m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value))); // [9]
}

/// Lightweight comment for inline display under a post. [9]
@immutable
class TrailComment {
  const TrailComment({
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

  TrailComment copyWith({
    String? id,
    String? userId,
    String? text,
    DateTime? createdAt,
    String? userName,
    String? avatarUrl,
  }) {
    return TrailComment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory TrailComment.fromJson(Map<String, dynamic> json) => TrailComment(
        id: (json['id'] ?? '').toString(),
        userId: (json['userId'] ?? '').toString(),
        text: (json['text'] ?? '').toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
        userName: (json['userName'] as String?)?.toString(),
        avatarUrl: (json['avatarUrl'] as String?)?.toString(),
      ); // [9]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (userName != null) 'userName': userName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      }; // [9]

  @override
  bool operator ==(Object other) =>
      other is TrailComment &&
      other.id == id &&
      other.userId == userId &&
      other.text == text &&
      other.createdAt == createdAt &&
      other.userName == userName &&
      other.avatarUrl == avatarUrl; // [9]

  @override
  int get hashCode => Object.hash(id, userId, text, createdAt, userName, avatarUrl); // [9]
}

/// Root trail post used in discovery feeds and trail detail timelines. [9]
@immutable
class TrailPost {
  const TrailPost({
    required this.id,
    required this.trailId,
    required this.type,
    required this.author,
    required this.createdAt,
    this.updatedAt,
    this.caption,
    this.language,
    this.media = const <TrailMedia>[],
    this.visibility = TrailPostVisibility.public,
    this.status = TrailPostStatus.published,
    this.coordinates,
    this.placeId,
    this.tags = const <String>[],
    this.mentions = const <String>[],
    this.likeCount = 0,
    this.commentCount = 0,
    this.saveCount = 0,
    this.myLiked = false,
    this.mySaved = false,
    this.comments = const <TrailComment>[],
    this.metadata,
  });

  final String id;
  final String trailId;

  final TrailPostType type;
  final TrailAuthor author;

  final DateTime createdAt;
  final DateTime? updatedAt;

  final String? caption;
  final String? language;

  final List<TrailMedia> media;

  final TrailPostVisibility visibility;
  final TrailPostStatus status;

  /// Optional geotag for map pins; if present, emits GeoJSON Feature with Point geometry. [1]
  final Coordinates? coordinates;

  /// Optional related place identifier for deep links. [9]
  final String? placeId;

  final List<String> tags;
  final List<String> mentions;

  final int likeCount;
  final int commentCount;
  final int saveCount;

  final bool myLiked;
  final bool mySaved;

  final List<TrailComment> comments;

  final Map<String, dynamic>? metadata;

  // -------- Convenience --------

  bool get hasCaption => (caption ?? '').trim().isNotEmpty; // [9]
  bool get hasMedia => media.isNotEmpty; // [9]
  TrailMedia? get primaryMedia => media.isNotEmpty ? media.first : null; // [9]

  /// Minimal GeoJSON Feature for mapping UIs when coordinates exist, using [lon, lat] ordering per RFC 7946. [1][2]
  Map<String, dynamic>? toGeoJsonFeature({Map<String, dynamic>? properties}) {
    if (coordinates == null) return null;
    final props = <String, dynamic>{
      ...?properties,
      'id': id,
      'trailId': trailId,
      'type': type.name,
      if (caption != null && caption!.trim().isNotEmpty) 'caption': caption,
      if (likeCount > 0) 'likes': likeCount,
      if (commentCount > 0) 'comments': commentCount,
    };
    return <String, dynamic>{
      'type': 'Feature',
      'geometry': <String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[coordinates!.longitude, coordinates!.latitude],
      },
      'properties': props,
    };
  }

  TrailPost copyWith({
    String? id,
    String? trailId,
    TrailPostType? type,
    TrailAuthor? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? caption,
    String? language,
    List<TrailMedia>? media,
    TrailPostVisibility? visibility,
    TrailPostStatus? status,
    Coordinates? coordinates,
    String? placeId,
    List<String>? tags,
    List<String>? mentions,
    int? likeCount,
    int? commentCount,
    int? saveCount,
    bool? myLiked,
    bool? mySaved,
    List<TrailComment>? comments,
    Map<String, dynamic>? metadata,
  }) {
    return TrailPost(
      id: id ?? this.id,
      trailId: trailId ?? this.trailId,
      type: type ?? this.type,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      caption: caption ?? this.caption,
      language: language ?? this.language,
      media: media ?? this.media,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      coordinates: coordinates ?? this.coordinates,
      placeId: placeId ?? this.placeId,
      tags: tags ?? this.tags,
      mentions: mentions ?? this.mentions,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      saveCount: saveCount ?? this.saveCount,
      myLiked: myLiked ?? this.myLiked,
      mySaved: mySaved ?? this.mySaved,
      comments: comments ?? this.comments,
      metadata: metadata ?? this.metadata,
    );
  }

  // -------- JSON --------

  factory TrailPost.fromJson(Map<String, dynamic> json) {
    TrailPostType parseType(Object? v) {
      final s = (v ?? 'photo').toString();
      try {
        return TrailPostType.values.byName(s);
      } catch (_) {
        switch (s.toLowerCase()) {
          case 'video':
            return TrailPostType.video;
          case 'text':
            return TrailPostType.text;
          case 'checkin':
          case 'check_in':
            return TrailPostType.checkIn;
          case 'route':
            return TrailPostType.route;
          default:
            return TrailPostType.photo;
        }
      }
    } // Prefer enums by name with safe fallbacks. [7][13]

    TrailPostVisibility parseVis(Object? v) {
      final s = (v ?? 'public').toString();
      try {
        return TrailPostVisibility.values.byName(s);
      } catch (_) {
        return TrailPostVisibility.public;
      }
    } // [13]

    TrailPostStatus parseStatus(Object? v) {
      final s = (v ?? 'published').toString();
      try {
        return TrailPostStatus.values.byName(s);
      } catch (_) {
        return TrailPostStatus.published;
      }
    } // [13]

    final rawMedia = (json['media'] as List?) ?? const <dynamic>[];
    final rawComments = (json['comments'] as List?) ?? const <dynamic>[];

    return TrailPost(
      id: (json['id'] ?? '').toString(),
      trailId: (json['trailId'] ?? '').toString(),
      type: parseType(json['type']),
      author: TrailAuthor.fromJson((json['author'] as Map).cast<String, dynamic>()),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      caption: (json['caption'] as String?)?.toString(),
      language: (json['language'] as String?)?.toString(),
      media: rawMedia.whereType<Map<String, dynamic>>().map(TrailMedia.fromJson).toList(growable: false),
      visibility: parseVis(json['visibility']),
      status: parseStatus(json['status']),
      coordinates: json['coordinates'] != null ? Coordinates.fromJson((json['coordinates'] as Map).cast<String, dynamic>()) : null,
      placeId: (json['placeId'] as String?)?.toString(),
      tags: ((json['tags'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      mentions: ((json['mentions'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      saveCount: (json['saveCount'] as num?)?.toInt() ?? 0,
      myLiked: (json['myLiked'] as bool?) ?? false,
      mySaved: (json['mySaved'] as bool?) ?? false,
      comments: rawComments.whereType<Map<String, dynamic>>().map(TrailComment.fromJson).toList(growable: false),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  } // Manual JSON for fast, dependency-free models in Flutter. [9]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'trailId': trailId,
        'type': type.name,
        'author': author.toJson(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (caption != null) 'caption': caption,
        if (language != null) 'language': language,
        if (media.isNotEmpty) 'media': media.map((m) => m.toJson()).toList(growable: false),
        'visibility': visibility.name,
        'status': status.name,
        if (coordinates != null) 'coordinates': coordinates!.toJson(),
        if (placeId != null) 'placeId': placeId,
        if (tags.isNotEmpty) 'tags': tags,
        if (mentions.isNotEmpty) 'mentions': mentions,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'saveCount': saveCount,
        'myLiked': myLiked,
        'mySaved': mySaved,
        if (comments.isNotEmpty) 'comments': comments.map((c) => c.toJson()).toList(growable: false),
        if (metadata != null) 'metadata': metadata,
      }; // Enums serialized via .name; ISO timestamps for portability. [13][9]

  @override
  bool operator ==(Object other) =>
      other is TrailPost &&
      other.id == id &&
      other.trailId == trailId &&
      other.type == type &&
      other.author == author &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.caption == caption &&
      other.language == language &&
      listEquals(other.media, media) &&
      other.visibility == visibility &&
      other.status == status &&
      other.coordinates == coordinates &&
      other.placeId == placeId &&
      listEquals(other.tags, tags) &&
      listEquals(other.mentions, mentions) &&
      other.likeCount == likeCount &&
      other.commentCount == commentCount &&
      other.saveCount == saveCount &&
      other.myLiked == myLiked &&
      other.mySaved == mySaved &&
      listEquals(other.comments, comments) &&
      mapEquals(other.metadata, metadata); // [9]

  @override
  int get hashCode => Object.hash(
        id,
        trailId,
        type,
        author,
        createdAt,
        updatedAt,
        caption,
        language,
        Object.hashAll(media),
        visibility,
        status,
        coordinates,
        placeId,
        Object.hash(Object.hashAll(tags), Object.hashAll(mentions)),
        likeCount,
        commentCount,
        saveCount,
        myLiked,
        mySaved,
        Object.hashAll(comments),
        _mapHash(metadata),
      ); // [9]

  static int _mapHash(Map<String, dynamic>? m) =>
      m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value))); // [9]
}
