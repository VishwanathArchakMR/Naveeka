// lib/models/user.dart

import 'package:flutter/foundation.dart';

/// App roles for access control and partner workflows.
enum UserRole { user, partner, admin }

@immutable
class User {
  const User({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.role = UserRole.user,
    this.profileImage,
    this.preferences = const <String>[],
    this.isActive = true,
    this.verified = false,
    this.createdAt,
    this.token,
  });

  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final UserRole role;
  final String? profileImage;
  final List<String> preferences; // emotion labels or other preference tags
  final bool isActive;
  final bool verified;
  final DateTime? createdAt;
  final String? token; // optional JWT after login/register

  // -------- Helpers --------

  /// A non-empty label for UI display, falls back to email/phone/id if name is null/empty.
  String get displayLabel {
    if ((name ?? '').trim().isNotEmpty) return name!.trim();
    if ((email ?? '').trim().isNotEmpty) return email!.trim();
    if ((phone ?? '').trim().isNotEmpty) return phone!.trim();
    return id;
  }

  /// Normalized preference labels (lowercase, trimmed).
  List<String> get normalizedPreferences =>
      preferences.map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).toList(growable: false);

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? profileImage,
    List<String>? preferences,
    bool? isActive,
    bool? verified,
    DateTime? createdAt,
    String? token,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      preferences: preferences ?? this.preferences,
      isActive: isActive ?? this.isActive,
      verified: verified ?? this.verified,
      createdAt: createdAt ?? this.createdAt,
      token: token ?? this.token,
    );
  }

  // -------- JSON --------

  static UserRole parseRole(Object? value) {
    final s = (value ?? 'user').toString();
    try {
      return UserRole.values.byName(s);
    } catch (_) {
      final l = s.toLowerCase();
      if (l.contains('partner')) return UserRole.partner;
      if (l.contains('admin')) return UserRole.admin;
      return UserRole.user;
    }
  } // Robust enum parsing via values.byName + safe fallbacks. [2]

  factory User.fromJson(Map<String, dynamic> json) {
    final List<dynamic> prefsRaw = (json['preferences'] as List?) ?? const <dynamic>[];
    return User(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] as String?)?.toString(),
      email: (json['email'] as String?)?.toString(),
      phone: (json['phone'] as String?)?.toString(),
      role: parseRole(json['role']),
      // Accept both profileImage and avatarUrl from various backends
      profileImage: (json['profileImage'] ?? json['avatarUrl'] as String?)?.toString(),
      preferences: prefsRaw.map((e) => e.toString()).toList(growable: false),
      isActive: json['isActive'] == null ? true : (json['isActive'] == true),
      verified: (json['verified'] as bool?) ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      token: (json['token'] as String?)?.toString(),
    );
  } // Manual fromJson keeps parsing fast and dependency-free. [1]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        'role': role.name,
        if (profileImage != null) 'profileImage': profileImage,
        if (preferences.isNotEmpty) 'preferences': preferences,
        'isActive': isActive,
        'verified': verified,
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (token != null) 'token': token,
      }; // Enum serialization via .name per modern Dart practice. [2][1]

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.phone == phone &&
      other.role == role &&
      other.profileImage == profileImage &&
      listEquals(other.preferences, preferences) &&
      other.isActive == isActive &&
      other.verified == verified &&
      other.createdAt == createdAt &&
      other.token == token; // Value equality for reliable provider updates. [1]

  @override
  int get hashCode => Object.hash(
        id,
        name,
        email,
        phone,
        role,
        profileImage,
        Object.hashAll(preferences),
        isActive,
        verified,
        createdAt,
        token,
      ); // Stable hashing for list diffing and caches. [1]
}
