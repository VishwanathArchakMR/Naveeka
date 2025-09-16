import 'dart:convert';
import 'location.dart';

enum EmotionCategory {
  peaceful('Peaceful', '🕊️'),
  spiritual('Spiritual', '🙏'),
  adventure('Adventure', '🏔️'),
  heritage('Heritage', '🏛️'),
  nature('Nature', '🌿');

  const EmotionCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum PlaceCategory {
  temple('Temple'),
  monument('Monument'),
  museum('Museum'),
  park('Park'),
  beach('Beach'),
  mountain('Mountain'),
  lake('Lake'),
  hotel('Hotel'),
  restaurant('Restaurant'),
  cafe('Cafe'),
  activity('Activity'),
  tour('Tour'),
  transport('Transport'),
  shopping('Shopping'),
  entertainment('Entertainment'),
  other('Other');

  const PlaceCategory(this.label);
  final String label;
}

class PlaceTimings {
  final String? openTime;
  final String? closeTime;
  final List<String>? openDays;
  final Map<String, String>? specialTimings; // Holiday/seasonal timings
  final bool isAlwaysOpen;

  const PlaceTimings({
    this.openTime,
    this.closeTime,
    this.openDays,
    this.specialTimings,
    this.isAlwaysOpen = false,
  });

  factory PlaceTimings.fromJson(Map<String, dynamic> json) {
    return PlaceTimings(
      openTime: json['openTime'] as String?,
      closeTime: json['closeTime'] as String?,
      openDays: (json['openDays'] as List<dynamic>?)?.cast<String>(),
      specialTimings: (json['specialTimings'] as Map<String, dynamic>?)?.cast<String, String>(),
      isAlwaysOpen: json['isAlwaysOpen'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'openTime': openTime,
    'closeTime': closeTime,
    'openDays': openDays,
    'specialTimings': specialTimings,
    'isAlwaysOpen': isAlwaysOpen,
  };

  bool get isOpenNow {
    if (isAlwaysOpen) return true;
    if (openTime == null || closeTime == null) return false;
    
    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday);
    
    if (openDays != null && !openDays!.contains(currentDay)) {
      return false;
    }

    // Simple time check (would need proper time parsing in real app)
    return true; // Simplified for now
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }
}

class PlacePricing {
  final double? entryFee;
  final double? foreignerFee;
  final String? currency;
  final Map<String, double>? categoryPricing; // Adult, child, senior pricing
  final bool isFree;

  const PlacePricing({
    this.entryFee,
    this.foreignerFee,
    this.currency = 'INR',
    this.categoryPricing,
    this.isFree = false,
  });

  factory PlacePricing.fromJson(Map<String, dynamic> json) {
    return PlacePricing(
      entryFee: (json['entryFee'] as num?)?.toDouble(),
      foreignerFee: (json['foreignerFee'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      categoryPricing: (json['categoryPricing'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      isFree: json['isFree'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'entryFee': entryFee,
    'foreignerFee': foreignerFee,
    'currency': currency,
    'categoryPricing': categoryPricing,
    'isFree': isFree,
  };
}

class PlaceContact {
  final String? phone;
  final String? email;
  final String? website;
  final Map<String, String>? socialMedia;

  const PlaceContact({
    this.phone,
    this.email,
    this.website,
    this.socialMedia,
  });

  factory PlaceContact.fromJson(Map<String, dynamic> json) {
    return PlaceContact(
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      socialMedia: (json['socialMedia'] as Map<String, dynamic>?)?.cast<String, String>(),
    );
  }

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'email': email,
    'website': website,
    'socialMedia': socialMedia,
  };
}

class PlaceAccessibility {
  final bool wheelchairAccessible;
  final bool hasParking;
  final String? parkingInfo;
  final bool hasRestrooms;
  final bool hasWifi;
  final List<String>? amenities;

  const PlaceAccessibility({
    this.wheelchairAccessible = false,
    this.hasParking = false,
    this.parkingInfo,
    this.hasRestrooms = false,
    this.hasWifi = false,
    this.amenities,
  });

  factory PlaceAccessibility.fromJson(Map<String, dynamic> json) {
    return PlaceAccessibility(
      wheelchairAccessible: json['wheelchairAccessible'] as bool? ?? false,
      hasParking: json['hasParking'] as bool? ?? false,
      parkingInfo: json['parkingInfo'] as String?,
      hasRestrooms: json['hasRestrooms'] as bool? ?? false,
      hasWifi: json['hasWifi'] as bool? ?? false,
      amenities: (json['amenities'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
    'wheelchairAccessible': wheelchairAccessible,
    'hasParking': hasParking,
    'parkingInfo': parkingInfo,
    'hasRestrooms': hasRestrooms,
    'hasWifi': hasWifi,
    'amenities': amenities,
  };
}

class Place {
  final String id;
  final String name;
  final String? description;
  final PlaceCategory category;
  final List<EmotionCategory> emotions;
  final PlaceLocation location;
  final List<String> images;
  final double rating;
  final int reviewCount;
  final PlaceTimings? timings;
  final PlacePricing? pricing;
  final PlaceContact? contact;
  final PlaceAccessibility accessibility;
  final List<String> tags;
  final List<String> nearbyPlaceIds;
  final Map<String, dynamic>? additionalInfo; // Category-specific data
  final DateTime? lastUpdated;
  final bool isVerified;
  final bool isFeatured;

  const Place({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    this.emotions = const [],
    required this.location,
    this.images = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    this.timings,
    this.pricing,
    this.contact,
    this.accessibility = const PlaceAccessibility(),
    this.tags = const [],
    this.nearbyPlaceIds = const [],
    this.additionalInfo,
    this.lastUpdated,
    this.isVerified = false,
    this.isFeatured = false,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: PlaceCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => PlaceCategory.other,
      ),
      emotions: (json['emotions'] as List<dynamic>?)
          ?.map((e) => EmotionCategory.values.firstWhere(
                (emotion) => emotion.name == e,
                orElse: () => EmotionCategory.peaceful,
              ))
          .toList() ?? [],
      location: PlaceLocation.fromJson(json['location'] as Map<String, dynamic>),
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      timings: json['timings'] != null 
          ? PlaceTimings.fromJson(json['timings'] as Map<String, dynamic>)
          : null,
      pricing: json['pricing'] != null
          ? PlacePricing.fromJson(json['pricing'] as Map<String, dynamic>)
          : null,
      contact: json['contact'] != null
          ? PlaceContact.fromJson(json['contact'] as Map<String, dynamic>)
          : null,
      accessibility: json['accessibility'] != null
          ? PlaceAccessibility.fromJson(json['accessibility'] as Map<String, dynamic>)
          : const PlaceAccessibility(),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      nearbyPlaceIds: (json['nearbyPlaceIds'] as List<dynamic>?)?.cast<String>() ?? [],
      additionalInfo: json['additionalInfo'] as Map<String, dynamic>?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,
      isVerified: json['isVerified'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category.name,
    'emotions': emotions.map((e) => e.name).toList(),
    'location': location.toJson(),
    'images': images,
    'rating': rating,
    'reviewCount': reviewCount,
    'timings': timings?.toJson(),
    'pricing': pricing?.toJson(),
    'contact': contact?.toJson(),
    'accessibility': accessibility.toJson(),
    'tags': tags,
    'nearbyPlaceIds': nearbyPlaceIds,
    'additionalInfo': additionalInfo,
    'lastUpdated': lastUpdated?.toIso8601String(),
    'isVerified': isVerified,
    'isFeatured': isFeatured,
  };

  // Convenience getters
  String get primaryEmotion => emotions.isNotEmpty ? emotions.first.label : 'General';
  
  String get emotionEmojis => emotions.map((e) => e.emoji).join(' ');
  
  bool get isOpenNow => timings?.isOpenNow ?? false;
  
  bool get isFree => pricing?.isFree ?? false;
  
  String get formattedRating => rating.toStringAsFixed(1);
  
  String get categoryLabel => category.label;

  String get distanceText {
    if (location.distanceFromUser == null) return '';
    
    final distance = location.distanceFromUser!;
    if (distance < 1000) {
      return '${distance.round()}m away';
    } else {
      final km = distance / 1000;
      return '${km.toStringAsFixed(1)}km away';
    }
  }

  // Helper methods for specific place types
  bool get isHotel => category == PlaceCategory.hotel;
  bool get isRestaurant => category == PlaceCategory.restaurant || category == PlaceCategory.cafe;
  bool get isActivity => category == PlaceCategory.activity || category == PlaceCategory.tour;
  bool get isTransport => category == PlaceCategory.transport;
  bool get isCultural => category == PlaceCategory.temple || 
                          category == PlaceCategory.monument || 
                          category == PlaceCategory.museum;

  // Copy with method for updates
  Place copyWith({
    String? id,
    String? name,
    String? description,
    PlaceCategory? category,
    List<EmotionCategory>? emotions,
    PlaceLocation? location,
    List<String>? images,
    double? rating,
    int? reviewCount,
    PlaceTimings? timings,
    PlacePricing? pricing,
    PlaceContact? contact,
    PlaceAccessibility? accessibility,
    List<String>? tags,
    List<String>? nearbyPlaceIds,
    Map<String, dynamic>? additionalInfo,
    DateTime? lastUpdated,
    bool? isVerified,
    bool? isFeatured,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      emotions: emotions ?? this.emotions,
      location: location ?? this.location,
      images: images ?? this.images,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      timings: timings ?? this.timings,
      pricing: pricing ?? this.pricing,
      contact: contact ?? this.contact,
      accessibility: accessibility ?? this.accessibility,
      tags: tags ?? this.tags,
      nearbyPlaceIds: nearbyPlaceIds ?? this.nearbyPlaceIds,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  @override
  String toString() => json.encode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Place &&
      runtimeType == other.runtimeType &&
      id == other.id;

  @override
  int get hashCode => id.hashCode;
}

