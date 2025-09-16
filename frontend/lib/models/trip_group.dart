// lib/models/trip_group.dart

import 'package:flutter/foundation.dart';

import 'booking.dart' show Money;
import 'coordinates.dart';

/// High-level lifecycle for a trip. [planning|active|completed|archived|canceled]
enum TripStatus { planning, active, completed, archived, canceled }

/// Access scope for discovery and collaboration. [private|friends|public]
enum TripVisibility { private, friends, public }

/// Member permissions for actions in the group. [owner|admin|editor|viewer|guest]
enum TripMemberRole { owner, admin, editor, viewer, guest }

/// Invite lifecycle for onboarding collaborators. [pending|accepted|declined|expired|revoked]
enum TripInviteStatus { pending, accepted, declined, expired, revoked }

/// Itinerary item kinds referencing other domain objects by ID (no tight coupling). [19]
enum ItineraryItemType {
  flight,
  hotel,
  train,
  bus,
  cab,
  activity,
  restaurant,
  place,
  landmark,
  note,
  transfer,
}

/// Member of a trip group with role and join details. [9]
@immutable
class TripMember {
  const TripMember({
    required this.userId,
    required this.role,
    this.displayName,
    this.avatarUrl,
    this.joinedAt,
    this.invitedAt,
    this.metadata,
  });

  final String userId;
  final TripMemberRole role;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? joinedAt;
  final DateTime? invitedAt;
  final Map<String, dynamic>? metadata;

  TripMember copyWith({
    String? userId,
    TripMemberRole? role,
    String? displayName,
    String? avatarUrl,
    DateTime? joinedAt,
    DateTime? invitedAt,
    Map<String, dynamic>? metadata,
  }) {
    return TripMember(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedAt: invitedAt ?? this.invitedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  factory TripMember.fromJson(Map<String, dynamic> json) {
    TripMemberRole parseRole(Object? v) {
      final s = (v ?? 'viewer').toString();
      try {
        return TripMemberRole.values.byName(s);
      } catch (_) {
        return TripMemberRole.viewer;
      }
    }
    return TripMember(
      userId: (json['userId'] ?? '').toString(),
      role: parseRole(json['role']),
      displayName: (json['displayName'] as String?)?.toString(),
      avatarUrl: (json['avatarUrl'] as String?)?.toString(),
      joinedAt: json['joinedAt'] != null ? DateTime.tryParse(json['joinedAt'].toString()) : null,
      invitedAt: json['invitedAt'] != null ? DateTime.tryParse(json['invitedAt'].toString()) : null,
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userId': userId,
        'role': role.name,
        if (displayName != null) 'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (joinedAt != null) 'joinedAt': joinedAt!.toUtc().toIso8601String(),
        if (invitedAt != null) 'invitedAt': invitedAt!.toUtc().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is TripMember &&
      other.userId == userId &&
      other.role == role &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.joinedAt == joinedAt &&
      other.invitedAt == invitedAt &&
      mapEquals(other.metadata, metadata);

  @override
  int get hashCode =>
      Object.hash(userId, role, displayName, avatarUrl, joinedAt, invitedAt, _mapHash(metadata));
}

/// Invitation to collaborate on a trip. [6]
@immutable
class TripInvite {
  const TripInvite({
    required this.id,
    required this.createdBy,
    required this.createdAt,
    required this.role,
    this.email,
    this.targetUserId,
    this.status = TripInviteStatus.pending,
    this.acceptedAt,
    this.expiresAt,
    this.message,
    this.metadata,
  });

  final String id;
  final String createdBy;
  final DateTime createdAt;

  final TripMemberRole role;

  final String? email;
  final String? targetUserId;

  final TripInviteStatus status;
  final DateTime? acceptedAt;
  final DateTime? expiresAt;
  final String? message;

  final Map<String, dynamic>? metadata;

  TripInvite copyWith({
    String? id,
    String? createdBy,
    DateTime? createdAt,
    TripMemberRole? role,
    String? email,
    String? targetUserId,
    TripInviteStatus? status,
    DateTime? acceptedAt,
    DateTime? expiresAt,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    return TripInvite(
      id: id ?? this.id,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      email: email ?? this.email,
      targetUserId: targetUserId ?? this.targetUserId,
      status: status ?? this.status,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      message: message ?? this.message,
      metadata: metadata ?? this.metadata,
    );
  }

  factory TripInvite.fromJson(Map<String, dynamic> json) {
    TripMemberRole parseRole(Object? v) {
      final s = (v ?? 'viewer').toString();
      try {
        return TripMemberRole.values.byName(s);
      } catch (_) {
        return TripMemberRole.viewer;
      }
    }
    TripInviteStatus parseStatus(Object? v) {
      final s = (v ?? 'pending').toString();
      try {
        return TripInviteStatus.values.byName(s);
      } catch (_) {
        return TripInviteStatus.pending;
      }
    }
    return TripInvite(
      id: (json['id'] ?? '').toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      role: parseRole(json['role']),
      email: (json['email'] as String?)?.toString(),
      targetUserId: (json['targetUserId'] as String?)?.toString(),
      status: parseStatus(json['status']),
      acceptedAt: json['acceptedAt'] != null ? DateTime.tryParse(json['acceptedAt'].toString()) : null,
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) : null,
      message: (json['message'] as String?)?.toString(),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'role': role.name,
        if (email != null) 'email': email,
        if (targetUserId != null) 'targetUserId': targetUserId,
        'status': status.name,
        if (acceptedAt != null) 'acceptedAt': acceptedAt!.toUtc().toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
        if (message != null) 'message': message,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is TripInvite &&
      other.id == id &&
      other.createdBy == createdBy &&
      other.createdAt == createdAt &&
      other.role == role &&
      other.email == email &&
      other.targetUserId == targetUserId &&
      other.status == status &&
      other.acceptedAt == acceptedAt &&
      other.expiresAt == expiresAt &&
      other.message == message &&
      mapEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(
        id,
        createdBy,
        createdAt,
        role,
        email,
        targetUserId,
        status,
        acceptedAt,
        expiresAt,
        message,
        _mapHash(metadata),
      );
}

/// A single itinerary entry for a day or a specific timestamp, referencing other models by ID. [2]
@immutable
class ItineraryItem {
  const ItineraryItem({
    required this.id,
    required this.type,
    this.date,              // local date "yyyy-MM-dd" for grouping
    this.startTime,         // local "HH:mm"
    this.endTime,           // local "HH:mm"
    this.title,
    this.subtitle,
    this.notes,
    this.location,          // optional geotag
    this.placeId,           // link to a Place/Landmark/Restaurant/etc.
    this.bookingId,         // link to a Booking (flight/hotel/etc.)
    this.refId,             // generic upstream reference (PNR, ticket ID, etc.)
    this.cost,              // Money for this item (est. or actual)
    this.tags = const <String>[],
    this.metadata,
  });

  final String id;
  final ItineraryItemType type;

  final String? date;
  final String? startTime;
  final String? endTime;

  final String? title;
  final String? subtitle;
  final String? notes;

  final Coordinates? location;

  final String? placeId;
  final String? bookingId;
  final String? refId;

  final Money? cost;

  final List<String> tags;
  final Map<String, dynamic>? metadata;

  ItineraryItem copyWith({
    String? id,
    ItineraryItemType? type,
    String? date,
    String? startTime,
    String? endTime,
    String? title,
    String? subtitle,
    String? notes,
    Coordinates? location,
    String? placeId,
    String? bookingId,
    String? refId,
    Money? cost,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return ItineraryItem(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      placeId: placeId ?? this.placeId,
      bookingId: bookingId ?? this.bookingId,
      refId: refId ?? this.refId,
      cost: cost ?? this.cost,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    ItineraryItemType parseType(Object? v) {
      final s = (v ?? 'note').toString();
      try {
        return ItineraryItemType.values.byName(s);
      } catch (_) {
        return ItineraryItemType.note;
      }
    }
    return ItineraryItem(
      id: (json['id'] ?? '').toString(),
      type: parseType(json['type']),
      date: (json['date'] as String?)?.toString(),
      startTime: (json['startTime'] as String?)?.toString(),
      endTime: (json['endTime'] as String?)?.toString(),
      title: (json['title'] as String?)?.toString(),
      subtitle: (json['subtitle'] as String?)?.toString(),
      notes: (json['notes'] as String?)?.toString(),
      location: json['location'] != null ? Coordinates.fromJson((json['location'] as Map).cast<String, dynamic>()) : null,
      placeId: (json['placeId'] as String?)?.toString(),
      bookingId: (json['bookingId'] as String?)?.toString(),
      refId: (json['refId'] as String?)?.toString(),
      cost: json['cost'] != null ? Money.fromJson((json['cost'] as Map).cast<String, dynamic>()) : null,
      tags: ((json['tags'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        if (date != null) 'date': date,
        if (startTime != null) 'startTime': startTime,
        if (endTime != null) 'endTime': endTime,
        if (title != null) 'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (notes != null) 'notes': notes,
        if (location != null) 'location': location!.toJson(),
        if (placeId != null) 'placeId': placeId,
        if (bookingId != null) 'bookingId': bookingId,
        if (refId != null) 'refId': refId,
        if (cost != null) 'cost': cost!.toJson(),
        if (tags.isNotEmpty) 'tags': tags,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is ItineraryItem &&
      other.id == id &&
      other.type == type &&
      other.date == date &&
      other.startTime == startTime &&
      other.endTime == endTime &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.notes == notes &&
      other.location == location &&
      other.placeId == placeId &&
      other.bookingId == bookingId &&
      other.refId == refId &&
      other.cost == cost &&
      listEquals(other.tags, tags) &&
      mapEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(
        id,
        type,
        date,
        startTime,
        endTime,
        title,
        subtitle,
        notes,
        location,
        placeId,
        bookingId,
        refId,
        cost,
        Object.hashAll(tags),
        _mapHash(metadata),
      );
}

/// Root collaborative trip with members, itinerary, budget, and permissions. [2]
@immutable
class TripGroup {
  const TripGroup({
    required this.id,
    required this.name,
    required this.ownerId,
    this.status = TripStatus.planning,
    this.visibility = TripVisibility.private,

    this.startDate,          // yyyy-MM-dd local
    this.endDate,            // yyyy-MM-dd local
    this.timezone,           // IANA tz for the trip anchor

    this.coverImageUrl,
    this.description,
    this.destinations = const <String>[],     // city/country labels
    this.destinationCoords,                   // map center or default view
    this.tags = const <String>[],

    this.members = const <TripMember>[],
    this.invites = const <TripInvite>[],
    this.itinerary = const <ItineraryItem>[],
    this.budget,                               // planned budget
    this.actualCost,                           // running total
    this.currency,                             // redundant if Money carries it

    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  final String id;
  final String name;
  final String ownerId;

  final TripStatus status;
  final TripVisibility visibility;

  final String? startDate;
  final String? endDate;
  final String? timezone;

  final String? coverImageUrl;
  final String? description;
  final List<String> destinations;
  final Coordinates? destinationCoords;
  final List<String> tags;

  final List<TripMember> members;
  final List<TripInvite> invites;
  final List<ItineraryItem> itinerary;

  final Money? budget;
  final Money? actualCost;
  final String? currency;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final Map<String, dynamic>? metadata;

  bool get isOwnerOnly => members.every((m) => m.userId == ownerId || m.role == TripMemberRole.guest); // quick scope check [9]
  int get dayCount {
    if (startDate == null || endDate == null) return 0;
    // Expecting yyyy-MM-dd; caller can compute precise counts elsewhere if needed.
    return itinerary.isEmpty ? 0 : itinerary.map((e) => e.date).whereType<String>().toSet().length;
  } // itinerary-driven count for rendering [2]

  TripGroup copyWith({
    String? id,
    String? name,
    String? ownerId,
    TripStatus? status,
    TripVisibility? visibility,
    String? startDate,
    String? endDate,
    String? timezone,
    String? coverImageUrl,
    String? description,
    List<String>? destinations,
    Coordinates? destinationCoords,
    List<String>? tags,
    List<TripMember>? members,
    List<TripInvite>? invites,
    List<ItineraryItem>? itinerary,
    Money? budget,
    Money? actualCost,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return TripGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timezone: timezone ?? this.timezone,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      description: description ?? this.description,
      destinations: destinations ?? this.destinations,
      destinationCoords: destinationCoords ?? this.destinationCoords,
      tags: tags ?? this.tags,
      members: members ?? this.members,
      invites: invites ?? this.invites,
      itinerary: itinerary ?? this.itinerary,
      budget: budget ?? this.budget,
      actualCost: actualCost ?? this.actualCost,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // -------- JSON --------

  factory TripGroup.fromJson(Map<String, dynamic> json) {
    TripStatus parseStatus(Object? v) {
      final s = (v ?? 'planning').toString();
      try {
        return TripStatus.values.byName(s);
      } catch (_) {
        return TripStatus.planning;
      }
    }
    TripVisibility parseVis(Object? v) {
      final s = (v ?? 'private').toString();
      try {
        return TripVisibility.values.byName(s);
      } catch (_) {
        return TripVisibility.private;
      }
    }

    final rawMembers = (json['members'] as List?) ?? const <dynamic>[];
    final rawInvites = (json['invites'] as List?) ?? const <dynamic>[];
    final rawItems = (json['itinerary'] as List?) ?? const <dynamic>[];

    return TripGroup(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      ownerId: (json['ownerId'] ?? '').toString(),
      status: parseStatus(json['status']),
      visibility: parseVis(json['visibility']),
      startDate: (json['startDate'] as String?)?.toString(),
      endDate: (json['endDate'] as String?)?.toString(),
      timezone: (json['timezone'] as String?)?.toString(),
      coverImageUrl: (json['coverImageUrl'] as String?)?.toString(),
      description: (json['description'] as String?)?.toString(),
      destinations: ((json['destinations'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      destinationCoords: json['destinationCoords'] != null
          ? Coordinates.fromJson((json['destinationCoords'] as Map).cast<String, dynamic>())
          : null,
      tags: ((json['tags'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      members: rawMembers.whereType<Map<String, dynamic>>().map(TripMember.fromJson).toList(growable: false),
      invites: rawInvites.whereType<Map<String, dynamic>>().map(TripInvite.fromJson).toList(growable: false),
      itinerary: rawItems.whereType<Map<String, dynamic>>().map(ItineraryItem.fromJson).toList(growable: false),
      budget: json['budget'] != null ? Money.fromJson((json['budget'] as Map).cast<String, dynamic>()) : null,
      actualCost: json['actualCost'] != null ? Money.fromJson((json['actualCost'] as Map).cast<String, dynamic>()) : null,
      currency: (json['currency'] as String?)?.toUpperCase(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'status': status.name,
        'visibility': visibility.name,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (timezone != null) 'timezone': timezone,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (description != null) 'description': description,
        if (destinations.isNotEmpty) 'destinations': destinations,
        if (destinationCoords != null) 'destinationCoords': destinationCoords!.toJson(),
        if (tags.isNotEmpty) 'tags': tags,
        if (members.isNotEmpty) 'members': members.map((m) => m.toJson()).toList(growable: false),
        if (invites.isNotEmpty) 'invites': invites.map((i) => i.toJson()).toList(growable: false),
        if (itinerary.isNotEmpty) 'itinerary': itinerary.map((i) => i.toJson()).toList(growable: false),
        if (budget != null) 'budget': budget!.toJson(),
        if (actualCost != null) 'actualCost': actualCost!.toJson(),
        if (currency != null) 'currency': currency,
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is TripGroup &&
      other.id == id &&
      other.name == name &&
      other.ownerId == ownerId &&
      other.status == status &&
      other.visibility == visibility &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.timezone == timezone &&
      other.coverImageUrl == coverImageUrl &&
      other.description == description &&
      listEquals(other.destinations, destinations) &&
      other.destinationCoords == destinationCoords &&
      listEquals(other.tags, tags) &&
      listEquals(other.members, members) &&
      listEquals(other.invites, invites) &&
      listEquals(other.itinerary, itinerary) &&
      other.budget == budget &&
      other.actualCost == actualCost &&
      other.currency == currency &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      mapEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        ownerId,
        status,
        visibility,
        startDate,
        endDate,
        timezone,
        coverImageUrl,
        description,
        Object.hash(Object.hashAll(destinations), destinationCoords),
        Object.hashAll(tags),
        Object.hashAll(members),
        Object.hashAll(invites),
        Object.hashAll(itinerary),
        budget,
        actualCost,
        currency,
        createdAt,
        updatedAt,
        _mapHash(metadata),
      );
}

int _mapHash(Map<String, dynamic>? m) =>
    m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
