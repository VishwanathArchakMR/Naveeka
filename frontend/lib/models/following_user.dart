// lib/models/following_user.dart

import 'package:flutter/foundation.dart';

/// Relationship state from the current user's perspective. [20]
enum FollowState {
  none,        // no relationship
  following,   // current user follows target
  requested,   // follow request sent (private accounts)
  blocked,     // current user blocked target
  muted,       // updates muted but may still follow
}

/// Minimal badge/tag for profile chips. Purely textual to keep model lean. [1]
@immutable
class UserBadge {
  const UserBadge({required this.label, this.colorHex, this.icon});

  final String label;      // e.g., "Guide", "Pro", "Verified"
  final String? colorHex;  // HEX like "4CAF50" (no leading #)
  final String? icon;      // optional symbolic name

  UserBadge copyWith({String? label, String? colorHex, String? icon}) =>
      UserBadge(label: label ?? this.label, colorHex: colorHex ?? this.colorHex, icon: icon ?? this.icon);

  factory UserBadge.fromJson(Map<String, dynamic> json) => UserBadge(
        label: (json['label'] ?? '').toString(),
        colorHex: (json['colorHex'] as String?)?.toUpperCase(),
        icon: (json['icon'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        if (colorHex != null) 'colorHex': colorHex,
        if (icon != null) 'icon': icon,
      };

  @override
  bool operator ==(Object other) =>
      other is UserBadge && other.label == label && other.colorHex == colorHex && other.icon == icon;

  @override
  int get hashCode => Object.hash(label, colorHex, icon);
}

/// Compact profile model used in follow lists, suggestions, and mutuals. [7]
@immutable
class FollowingUser {
  const FollowingUser({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.bio,
    this.location,
    this.verified = false,

    // Relationship markers
    this.isFollowing = false, // current user -> this user
    this.isFollower = false,  // this user -> current user
    this.followState = FollowState.none,
    this.followedAt,          // when current user followed

    // Mutual signals for ranking/suggestions
    this.mutualFollowers = 0,
    this.mutualTrails = 0,

    this.badges = const <UserBadge>[],
    this.lastActiveAt,
    this.metadata,
  });

  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final bool verified;

  final bool isFollowing;
  final bool isFollower;
  final FollowState followState;
  final DateTime? followedAt;

  final int mutualFollowers;
  final int mutualTrails;

  final List<UserBadge> badges;

  final DateTime? lastActiveAt;

  final Map<String, dynamic>? metadata;

  /// Convenience: "@handle" or empty if no username. [1]
  String get handle => (username == null || username!.trim().isEmpty) ? '' : '@${username!.trim()}';

  /// Two-way connection indicator often labeled “Mutual”. [10]
  bool get isMutual => isFollowing && isFollower;

  FollowingUser copyWith({
    String? id,
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bio,
    String? location,
    bool? verified,
    bool? isFollowing,
    bool? isFollower,
    FollowState? followState,
    DateTime? followedAt,
    int? mutualFollowers,
    int? mutualTrails,
    List<UserBadge>? badges,
    DateTime? lastActiveAt,
    Map<String, dynamic>? metadata,
  }) {
    return FollowingUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      verified: verified ?? this.verified,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollower: isFollower ?? this.isFollower,
      followState: followState ?? this.followState,
      followedAt: followedAt ?? this.followedAt,
      mutualFollowers: mutualFollowers ?? this.mutualFollowers,
      mutualTrails: mutualTrails ?? this.mutualTrails,
      badges: badges ?? this.badges,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // -------- JSON --------

  factory FollowingUser.fromJson(Map<String, dynamic> json) {
    FollowState parseState(Object? v) {
      final s = (v ?? 'none').toString();
      try {
        return FollowState.values.byName(s);
      } catch (_) {
        return FollowState.none;
      }
    } // Prefer enums by name with safe fallback. [9][6]

    final rawBadges = (json['badges'] as List?) ?? const <dynamic>[];
    return FollowingUser(
      id: (json['id'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['name'] ?? '').toString(),
      username: (json['username'] as String?)?.toString(),
      avatarUrl: (json['avatarUrl'] as String?)?.toString(),
      bio: (json['bio'] as String?)?.toString(),
      location: (json['location'] as String?)?.toString(),
      verified: (json['verified'] as bool?) ?? false,
      isFollowing: (json['isFollowing'] as bool?) ?? (json['following'] as bool?) ?? false,
      isFollower: (json['isFollower'] as bool?) ?? (json['follower'] as bool?) ?? false,
      followState: parseState(json['followState']),
      followedAt: json['followedAt'] != null ? DateTime.tryParse(json['followedAt'].toString()) : null,
      mutualFollowers: (json['mutualFollowers'] as num?)?.toInt() ?? 0,
      mutualTrails: (json['mutualTrails'] as num?)?.toInt() ?? 0,
      badges: rawBadges
          .whereType<Map<String, dynamic>>()
          .map(UserBadge.fromJson)
          .toList(growable: false),
      lastActiveAt: json['lastActiveAt'] != null ? DateTime.tryParse(json['lastActiveAt'].toString()) : null,
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  } // Manual JSON per Flutter guidance. [1][4]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'displayName': displayName,
        if (username != null) 'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (bio != null) 'bio': bio,
        if (location != null) 'location': location,
        'verified': verified,
        'isFollowing': isFollowing,
        'isFollower': isFollower,
        'followState': followState.name,
        if (followedAt != null) 'followedAt': followedAt!.toUtc().toIso8601String(),
        'mutualFollowers': mutualFollowers,
        'mutualTrails': mutualTrails,
        if (badges.isNotEmpty) 'badges': badges.map((b) => b.toJson()).toList(growable: false),
        if (lastActiveAt != null) 'lastActiveAt': lastActiveAt!.toUtc().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      }; // Enum serialization via .name for stability. [9][1]

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is FollowingUser &&
            other.id == id &&
            other.displayName == displayName &&
            other.username == username &&
            other.avatarUrl == avatarUrl &&
            other.bio == bio &&
            other.location == location &&
            other.verified == verified &&
            other.isFollowing == isFollowing &&
            other.isFollower == isFollower &&
            other.followState == followState &&
            other.followedAt == followedAt &&
            other.mutualFollowers == mutualFollowers &&
            other.mutualTrails == mutualTrails &&
            listEquals(other.badges, badges) &&
            other.lastActiveAt == lastActiveAt &&
            mapEquals(other.metadata, metadata));
  } // Value equality for clean Riverpod updates. [1]

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        username,
        avatarUrl,
        bio,
        location,
        verified,
        isFollowing,
        isFollower,
        followState,
        followedAt,
        mutualFollowers,
        mutualTrails,
        Object.hashAll(badges),
        lastActiveAt,
        _mapHash(metadata),
      );

  int _mapHash(Map<String, dynamic>? m) =>
      m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
