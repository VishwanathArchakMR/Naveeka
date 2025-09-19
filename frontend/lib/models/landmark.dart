// lib/models/landmark.dart

import 'package:flutter/foundation.dart';

import 'coordinates.dart';
import 'booking.dart' show Money; // optional for ticketFrom

/// Broad POI types aligned with common tourism/place catalogs for consistent filtering and UI. [tourism, culture, nature, infrastructure]
/// Examples are mapped from widely used POI taxonomies (e.g., museum, monument, viewpoint, park). [3][4]
enum LandmarkType {
  natural,        // mountains, lakes, waterfalls, canyons
  viewpoint,      // scenic overlooks, towers
  museum,         // museums, galleries
  monument,       // monuments, memorials, statues
  heritage,       // UNESCO or protected heritage
  religious,      // temples, mosques, churches
  fort,           // forts, castles, citadels
  palace,         // palaces, havelis
  bridge,         // iconic bridges
  park,           // parks, gardens, botanic
  beach,          // beaches, coastal spots
  market,         // bazaars, craft markets
  stadium,        // stadiums, arenas
  university,     // campuses
  lighthouse,     // lighthouses
  art,            // public art, installations
  neighborhood,   // historic quarters
  zoo,            // zoos, aquariums
  themePark,      // theme parks, attractions
  other,          // fallback
}

/// Basic accessibility flags to surface inclusive travel info in UI cards and filters. [14]
@immutable
class LandmarkAccessibility {
  const LandmarkAccessibility({
    this.wheelchairAccessible = false,
    this.strollerFriendly = false,
    this.petFriendly = false,
    this.audioGuideAvailable = false,
    this.signageAvailable = false, // braille/visual aids
  });

  final bool wheelchairAccessible;
  final bool strollerFriendly;
  final bool petFriendly;
  final bool audioGuideAvailable;
  final bool signageAvailable;

  LandmarkAccessibility copyWith({
    bool? wheelchairAccessible,
    bool? strollerFriendly,
    bool? petFriendly,
    bool? audioGuideAvailable,
    bool? signageAvailable,
  }) {
    return LandmarkAccessibility(
      wheelchairAccessible: wheelchairAccessible ?? this.wheelchairAccessible,
      strollerFriendly: strollerFriendly ?? this.strollerFriendly,
      petFriendly: petFriendly ?? this.petFriendly,
      audioGuideAvailable: audioGuideAvailable ?? this.audioGuideAvailable,
      signageAvailable: signageAvailable ?? this.signageAvailable,
    );
  }

  factory LandmarkAccessibility.fromJson(Map<String, dynamic> json) => LandmarkAccessibility(
        wheelchairAccessible: (json['wheelchairAccessible'] as bool?) ?? false,
        strollerFriendly: (json['strollerFriendly'] as bool?) ?? false,
        petFriendly: (json['petFriendly'] as bool?) ?? false,
        audioGuideAvailable: (json['audioGuideAvailable'] as bool?) ?? false,
        signageAvailable: (json['signageAvailable'] as bool?) ?? false,
      ); // Manual JSON is dependency-free and fast. [10]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'wheelchairAccessible': wheelchairAccessible,
        'strollerFriendly': strollerFriendly,
        'petFriendly': petFriendly,
        'audioGuideAvailable': audioGuideAvailable,
        'signageAvailable': signageAvailable,
      };

  @override
  bool operator ==(Object other) =>
      other is LandmarkAccessibility &&
      other.wheelchairAccessible == wheelchairAccessible &&
      other.strollerFriendly == strollerFriendly &&
      other.petFriendly == petFriendly &&
      other.audioGuideAvailable == audioGuideAvailable &&
      other.signageAvailable == signageAvailable;

  @override
  int get hashCode =>
      Object.hash(wheelchairAccessible, strollerFriendly, petFriendly, audioGuideAvailable, signageAvailable);
}

/// Simple photo asset with optional dimensions for responsive layout hints. [10]
@immutable
class LandmarkPhoto {
  const LandmarkPhoto({required this.url, this.caption, this.width, this.height, this.isCover = false});

  final String url;
  final String? caption;
  final int? width;
  final int? height;
  final bool isCover;

  LandmarkPhoto copyWith({String? url, String? caption, int? width, int? height, bool? isCover}) => LandmarkPhoto(
        url: url ?? this.url,
        caption: caption ?? this.caption,
        width: width ?? this.width,
        height: height ?? this.height,
        isCover: isCover ?? this.isCover,
      );

  factory LandmarkPhoto.fromJson(Map<String, dynamic> json) => LandmarkPhoto(
        url: (json['url'] ?? '').toString(),
        caption: (json['caption'] as String?)?.toString(),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        isCover: (json['isCover'] as bool?) ?? false,
      ); // Manual fromJson/toJson recommended for small models. [10]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        if (caption != null) 'caption': caption,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'isCover': isCover,
      };

  @override
  bool operator ==(Object other) =>
      other is LandmarkPhoto &&
      other.url == url &&
      other.caption == caption &&
      other.width == width &&
      other.height == height &&
      other.isCover == isCover;

  @override
  int get hashCode => Object.hash(url, caption, width, height, isCover);
}

/// A tourism landmark / point of interest suitable for maps, lists, and detail pages. [4]
@immutable
class Landmark {
  const Landmark({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.coordinates,
    this.address,       // free-form address line
    this.city,
    this.country,
    this.countryCode,   // ISO-2
    this.website,
    this.phone,
    this.email,
    this.rating,
    this.reviewCount,
    this.savedCount,
    this.ticketFrom,    // optional lowest ticket price
    this.openingHours,  // free-form per-day string or summary
    this.accessibility = const LandmarkAccessibility(),
    this.photos = const <LandmarkPhoto>[],
    this.tags = const <String>[],
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final LandmarkType type;

  final String? description;
  final Coordinates? coordinates;

  final String? address;
  final String? city;
  final String? country;
  final String? countryCode;

  final String? website;
  final String? phone;
  final String? email;

  final double? rating;      // 0..5
  final int? reviewCount;
  final int? savedCount;

  final Money? ticketFrom;

  /// Suggest using a simple map like {"mon":"9:00-17:00","tue":"closed",...} or a sentence summary.
  final Map<String, String>? openingHours;

  final LandmarkAccessibility accessibility;

  final List<LandmarkPhoto> photos;
  final List<String> tags;

  final Map<String, dynamic>? metadata;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// “City, Country” label fallback for compact UI chips.
  String get placeLine {
    final c = (city ?? '').trim();
    final k = (country ?? '').trim();
    if (c.isNotEmpty && k.isNotEmpty) return '$c, $k';
    if (c.isNotEmpty) return c;
    if (k.isNotEmpty) return k;
    return '';
  } // Concise locality line enhances list readability. [4]

  /// Distance in meters from an origin if coordinates are available.
  double? distanceFrom(Coordinates origin) => coordinates == null ? null : origin.distanceTo(coordinates!); // Haversine used in Coordinates. [10]

  /// GeoJSON Feature for mapping: Point with [lng, lat] order per RFC 7946. [6][9]
  Map<String, dynamic> toGeoJsonFeature() {
    final props = <String, dynamic>{
      'id': id,
      'name': name,
      'type': type.name,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (countryCode != null) 'countryCode': countryCode,
      if (website != null) 'website': website,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (rating != null) 'rating': rating,
      if (reviewCount != null) 'reviewCount': reviewCount,
      if (savedCount != null) 'savedCount': savedCount,
      if (tags.isNotEmpty) 'tags': tags,
    };
    final geom = coordinates == null
        ? null
        : {
            'type': 'Point',
            'coordinates': [coordinates!.longitude, coordinates!.latitude],
          };
    return {
      'type': 'Feature',
      if (geom != null) 'geometry': geom,
      'properties': props,
    };
  } // GeoJSON requires [longitude, latitude] order and a Feature wrapper. [6][12]

  Landmark copyWith({
    String? id,
    String? name,
    LandmarkType? type,
    String? description,
    Coordinates? coordinates,
    String? address,
    String? city,
    String? country,
    String? countryCode,
    String? website,
    String? phone,
    String? email,
    double? rating,
    int? reviewCount,
    int? savedCount,
    Money? ticketFrom,
    Map<String, String>? openingHours,
    LandmarkAccessibility? accessibility,
    List<LandmarkPhoto>? photos,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Landmark(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      coordinates: coordinates ?? this.coordinates,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      website: website ?? this.website,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      savedCount: savedCount ?? this.savedCount,
      ticketFrom: ticketFrom ?? this.ticketFrom,
      openingHours: openingHours ?? this.openingHours,
      accessibility: accessibility ?? this.accessibility,
      photos: photos ?? this.photos,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static LandmarkType _parseType(Object? v) {
    final s = (v ?? 'other').toString();
    try {
      return LandmarkType.values.byName(s);
    } catch (_) {
      // Common label fallbacks from POI catalogs
      switch (s.toLowerCase()) {
        case 'museum':
        case 'gallery':
          return LandmarkType.museum;
        case 'monument':
        case 'memorial':
        case 'statue':
          return LandmarkType.monument;
        case 'viewpoint':
        case 'lookout':
        case 'tower':
          return LandmarkType.viewpoint;
        case 'park':
        case 'garden':
        case 'botanic':
          return LandmarkType.park;
        case 'beach':
          return LandmarkType.beach;
        case 'temple':
        case 'mosque':
        case 'church':
          return LandmarkType.religious;
        case 'heritage':
        case 'unesco':
          return LandmarkType.heritage;
        case 'fort':
        case 'castle':
          return LandmarkType.fort;
        case 'palace':
          return LandmarkType.palace;
        case 'bridge':
          return LandmarkType.bridge;
        case 'market':
        case 'bazaar':
          return LandmarkType.market;
        case 'lighthouse':
          return LandmarkType.lighthouse;
        case 'stadium':
        case 'arena':
          return LandmarkType.stadium;
        case 'university':
        case 'campus':
          return LandmarkType.university;
        case 'themepark':
        case 'theme_park':
          return LandmarkType.themePark;
        case 'natural':
        case 'mountain':
        case 'lake':
        case 'river':
        case 'waterfall':
          return LandmarkType.natural;
        default:
          return LandmarkType.other;
      }
    }
  } // Map provider/category labels into a stable enum domain. [3][4]

  factory Landmark.fromJson(Map<String, dynamic> json) {
    final rawPhotos = (json['photos'] as List?) ?? const <dynamic>[];
    final rawTags = (json['tags'] as List?) ?? const <dynamic>[];
    final rawHours = (json['openingHours'] as Map?)?.cast<String, dynamic>();

    return Landmark(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: _parseType(json['type'] ?? json['category'] ?? json['poiType']),
      description: (json['description'] as String?)?.toString(),
      coordinates: json['coordinates'] != null ? Coordinates.fromJson((json['coordinates'] as Map).cast<String, dynamic>()) : null,
      address: (json['address'] as String?)?.toString(),
      city: (json['city'] as String?)?.toString(),
      country: (json['country'] as String?)?.toString(),
      countryCode: (json['countryCode'] as String?)?.toUpperCase(),
      website: (json['website'] as String?)?.toString(),
      phone: (json['phone'] as String?)?.toString(),
      email: (json['email'] as String?)?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt(),
      savedCount: (json['savedCount'] as num?)?.toInt(),
      ticketFrom: json['ticketFrom'] != null ? Money.fromJson((json['ticketFrom'] as Map).cast<String, dynamic>()) : null,
      openingHours: rawHours?.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      accessibility: json['accessibility'] != null
          ? LandmarkAccessibility.fromJson((json['accessibility'] as Map).cast<String, dynamic>())
          : const LandmarkAccessibility(),
      photos: rawPhotos.whereType<Map<String, dynamic>>().map(LandmarkPhoto.fromJson).toList(growable: false),
      tags: rawTags.map((e) => e.toString()).toList(growable: false),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  } // Manual JSON keeps models lightweight and portable across layers. [10]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.name,
        if (description != null) 'description': description,
        if (coordinates != null) 'coordinates': coordinates!.toJson(),
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (countryCode != null) 'countryCode': countryCode,
        if (website != null) 'website': website,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (rating != null) 'rating': rating,
        if (reviewCount != null) 'reviewCount': reviewCount,
        if (savedCount != null) 'savedCount': savedCount,
        if (ticketFrom != null) 'ticketFrom': ticketFrom!.toJson(),
        if (openingHours != null) 'openingHours': openingHours,
        'accessibility': accessibility.toJson(),
        if (photos.isNotEmpty) 'photos': photos.map((p) => p.toJson()).toList(growable: false),
        if (tags.isNotEmpty) 'tags': tags,
        if (metadata != null) 'metadata': metadata,
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      }; // Enum serialization via .name and ISO timestamps are idiomatic in Dart/Flutter. [10]

  @override
  bool operator ==(Object other) =>
      other is Landmark &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.description == description &&
      other.coordinates == coordinates &&
      other.address == address &&
      other.city == city &&
      other.country == country &&
      other.countryCode == countryCode &&
      other.website == website &&
      other.phone == phone &&
      other.email == email &&
      other.rating == rating &&
      other.reviewCount == reviewCount &&
      other.savedCount == savedCount &&
      other.ticketFrom == ticketFrom &&
      mapEquals(other.openingHours, openingHours) &&
      other.accessibility == accessibility &&
      listEquals(other.photos, photos) &&
      listEquals(other.tags, tags) &&
      mapEquals(other.metadata, metadata) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt; // Value equality supports reliable state updates. [10]

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        description,
        coordinates,
        address,
        city,
        country,
        countryCode,
        website,
        phone,
        email,
        rating,
        reviewCount,
        savedCount,
        ticketFrom,
        _mapHash(openingHours),
        accessibility,
        Object.hash(Object.hashAll(photos), Object.hashAll(tags), _mapHash(metadata)),
        createdAt,
        updatedAt,
      );

  static int _mapHash(Map<String, dynamic>? m) =>
      m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
