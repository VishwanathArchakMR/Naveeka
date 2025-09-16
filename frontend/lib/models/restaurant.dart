// lib/models/restaurant.dart

import 'package:flutter/foundation.dart';

import 'location.dart' show PlaceLocation;
import 'booking.dart' show Money;

/// Broad cuisine taxonomy for filtering and discovery. Parsed by name with safe fallbacks. [examples: Indian, Italian, Chinese, Japanese, Thai, Mexican, French, Greek, MiddleEastern, American, Fusion]
enum CuisineType {
  indian,
  italian,
  chinese,
  japanese,
  thai,
  mexican,
  french,
  greek,
  middleEastern,
  american,
  spanish,
  korean,
  vietnamese,
  turkish,
  portuguese,
  german,
  british,
  fusion,
  other;

  static CuisineType parse(Object? v) {
    final s = (v ?? 'other').toString();
    try {
      return CuisineType.values.byName(s);
    } catch (_) {
      switch (s.toLowerCase()) {
        case 'middle_eastern':
        case 'middleeastern':
          return CuisineType.middleEastern;
        default:
          return CuisineType.other;
      }
    }
  }
}

/// Dietary options surfaced for badges and filters.
enum DietaryOption {
  vegetarian,
  vegan,
  jain,
  halal,
  kosher,
  glutenFree,
  dairyFree,
  eggless,
  none,
}

/// Meal sessions supported.
enum MealType { breakfast, brunch, lunch, highTea, dinner, lateNight, snacks, dessert }

/// Service options and facilities.
enum ServiceOption {
  dineIn,
  takeaway,
  delivery,
  curbside,
  outdoorSeating,
  reservations,
  bar,
  liveMusic,
  kidsFriendly,
  petFriendly,
  wheelchairAccessible,
  parking,
  valet,
  wifi,
  ac, // air conditioning
}

/// Price level for quick sorting/badging (approximate).
enum PriceLevel { cheap, moderate, expensive, luxury }

/// Contact info (kept minimal and model-only).
@immutable
class RestaurantContact {
  const RestaurantContact({this.phone, this.email, this.website, this.instagram, this.facebook, this.whatsapp});

  final String? phone;
  final String? email;
  final String? website;
  final String? instagram;
  final String? facebook;
  final String? whatsapp;

  RestaurantContact copyWith({
    String? phone,
    String? email,
    String? website,
    String? instagram,
    String? facebook,
    String? whatsapp,
  }) {
    return RestaurantContact(
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      whatsapp: whatsapp ?? this.whatsapp,
    );
  }

  factory RestaurantContact.fromJson(Map<String, dynamic> json) => RestaurantContact(
        phone: (json['phone'] as String?)?.toString(),
        email: (json['email'] as String?)?.toString(),
        website: (json['website'] as String?)?.toString(),
        instagram: (json['instagram'] as String?)?.toString(),
        facebook: (json['facebook'] as String?)?.toString(),
        whatsapp: (json['whatsapp'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (website != null) 'website': website,
        if (instagram != null) 'instagram': instagram,
        if (facebook != null) 'facebook': facebook,
        if (whatsapp != null) 'whatsapp': whatsapp,
      };

  @override
  bool operator ==(Object other) =>
      other is RestaurantContact &&
      other.phone == phone &&
      other.email == email &&
      other.website == website &&
      other.instagram == instagram &&
      other.facebook == facebook &&
      other.whatsapp == whatsapp;

  @override
  int get hashCode => Object.hash(phone, email, website, instagram, facebook, whatsapp);
}

/// Per-day opening hours; use simple strings for UI; real parsing can be added later.
@immutable
class RestaurantHours {
  const RestaurantHours({
    this.mon,
    this.tue,
    this.wed,
    this.thu,
    this.fri,
    this.sat,
    this.sun,
    this.isAlwaysOpen = false,
  });

  final String? mon;
  final String? tue;
  final String? wed;
  final String? thu;
  final String? fri;
  final String? sat;
  final String? sun;
  final bool isAlwaysOpen;

  bool get hasAny =>
      (mon ?? tue ?? wed ?? thu ?? fri ?? sat ?? sun) != null || isAlwaysOpen;

  RestaurantHours copyWith({
    String? mon,
    String? tue,
    String? wed,
    String? thu,
    String? fri,
    String? sat,
    String? sun,
    bool? isAlwaysOpen,
  }) {
    return RestaurantHours(
      mon: mon ?? this.mon,
      tue: tue ?? this.tue,
      wed: wed ?? this.wed,
      thu: thu ?? this.thu,
      fri: fri ?? this.fri,
      sat: sat ?? this.sat,
      sun: sun ?? this.sun,
      isAlwaysOpen: isAlwaysOpen ?? this.isAlwaysOpen,
    );
  }

  factory RestaurantHours.fromJson(Map<String, dynamic> json) => RestaurantHours(
        mon: (json['mon'] as String?)?.toString(),
        tue: (json['tue'] as String?)?.toString(),
        wed: (json['wed'] as String?)?.toString(),
        thu: (json['thu'] as String?)?.toString(),
        fri: (json['fri'] as String?)?.toString(),
        sat: (json['sat'] as String?)?.toString(),
        sun: (json['sun'] as String?)?.toString(),
        isAlwaysOpen: (json['isAlwaysOpen'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (mon != null) 'mon': mon,
        if (tue != null) 'tue': tue,
        if (wed != null) 'wed': wed,
        if (thu != null) 'thu': thu,
        if (fri != null) 'fri': fri,
        if (sat != null) 'sat': sat,
        if (sun != null) 'sun': sun,
        'isAlwaysOpen': isAlwaysOpen,
      };

  @override
  bool operator ==(Object other) =>
      other is RestaurantHours &&
      other.mon == mon &&
      other.tue == tue &&
      other.wed == wed &&
      other.thu == thu &&
      other.fri == fri &&
      other.sat == sat &&
      other.sun == sun &&
      other.isAlwaysOpen == isAlwaysOpen;

  @override
  int get hashCode => Object.hash(mon, tue, wed, thu, fri, sat, sun, isAlwaysOpen);
}

/// Simple menu item for detail views or inline menus.
@immutable
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    this.description,
    this.category, // Starters/Main/Dessert/Drinks
    this.imageUrl,
    this.price,
    this.dietary = const <DietaryOption>[],
    this.spicyLevel, // 1..3 optional
    this.metadata,
  });

  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? imageUrl;
  final Money? price;
  final List<DietaryOption> dietary;
  final int? spicyLevel;
  final Map<String, dynamic>? metadata;

  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? imageUrl,
    Money? price,
    List<DietaryOption>? dietary,
    int? spicyLevel,
    Map<String, dynamic>? metadata,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      dietary: dietary ?? this.dietary,
      spicyLevel: spicyLevel ?? this.spicyLevel,
      metadata: metadata ?? this.metadata,
    );
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final dietRaw = (json['dietary'] as List?) ?? const <dynamic>[];
    return MenuItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] as String?)?.toString(),
      category: (json['category'] as String?)?.toString(),
      imageUrl: (json['imageUrl'] as String?)?.toString(),
      price: json['price'] != null ? Money.fromJson((json['price'] as Map).cast<String, dynamic>()) : null,
      dietary: dietRaw.map((e) {
        final s = e.toString();
        try {
          return DietaryOption.values.byName(s);
        } catch (_) {
          switch (s.toLowerCase()) {
            case 'gluten_free':
            case 'gluten-free':
              return DietaryOption.glutenFree;
            case 'dairy_free':
            case 'dairy-free':
              return DietaryOption.dairyFree;
            default:
              return DietaryOption.none;
          }
        }
      }).toList(growable: false),
      spicyLevel: (json['spicyLevel'] as num?)?.toInt(),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (price != null) 'price': price!.toJson(),
        if (dietary.isNotEmpty) 'dietary': dietary.map((d) => d.name).toList(growable: false),
        if (spicyLevel != null) 'spicyLevel': spicyLevel,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Root Restaurant model used across discovery, details, and bookings.
@immutable
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.location,
    this.description,
    this.cuisines = const <CuisineType>[],
    this.meals = const <MealType>[],
    this.dietary = const <DietaryOption>[],
    this.services = const <ServiceOption>[],
    this.priceLevel,
    this.averageCostForTwo, // optional quick estimator
    this.rating = 0.0,
    this.reviewCount = 0,
    this.hours,
    this.contact,
    this.photos = const <String>[], // URLs
    this.menu = const <MenuItem>[],
    this.tags = const <String>[],
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final PlaceLocation location;

  final String? description;
  final List<CuisineType> cuisines;
  final List<MealType> meals;
  final List<DietaryOption> dietary;
  final List<ServiceOption> services;

  final PriceLevel? priceLevel;
  final Money? averageCostForTwo;

  final double rating; // 0..5
  final int reviewCount;

  final RestaurantHours? hours;
  final RestaurantContact? contact;

  final List<String> photos;
  final List<MenuItem> menu;

  final List<String> tags;
  final Map<String, dynamic>? metadata;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // -------- Convenience --------

  String? get primaryPhoto => photos.isNotEmpty ? photos.first : null;

  bool get isOpenAlways => hours?.isAlwaysOpen ?? false;

  /// Simple open-now heuristic (string presence); for precise checks, parse hours to local times.
  bool get isOpenNow => (hours?.isAlwaysOpen ?? false) || (hours?.hasAny ?? false);

  /// Humanized distance string based on location.distanceFromUser (km).
  String get distanceText {
    final dKm = location.distanceFromUser;
    if (dKm == null) return '';
    if (dKm < 1.0) return '${(dKm * 1000).round()}m away';
    if (dKm < 10.0) return '${dKm.toStringAsFixed(1)}km away';
    return '${dKm.toStringAsFixed(0)}km away';
  }

  /// Currency symbolization by price level (approx only).
  String get priceLabel {
    switch (priceLevel) {
      case PriceLevel.cheap:
        return '₹';
      case PriceLevel.moderate:
        return '₹₹';
      case PriceLevel.expensive:
        return '₹₹₹';
      case PriceLevel.luxury:
        return '₹₹₹₹';
      default:
        return '';
    }
  }

  /// GeoJSON Feature for mapping; geometry uses [lon, lat] ordering.
  Map<String, dynamic> toGeoJsonFeature({Map<String, dynamic>? properties}) {
    final props = <String, dynamic>{
      ...?properties,
      'id': id,
      'name': name,
      if (cuisines.isNotEmpty) 'cuisines': cuisines.map((c) => c.name).toList(growable: false),
      if (rating > 0) 'rating': rating,
      if (priceLevel != null) 'priceLevel': priceLevel!.name,
    };
    return <String, dynamic>{
      'type': 'Feature',
      'geometry': <String, dynamic>{
        'type': 'Point',
        'coordinates': <double>[location.longitude, location.latitude],
      },
      'properties': props,
    };
  }

  Restaurant copyWith({
    String? id,
    String? name,
    PlaceLocation? location,
    String? description,
    List<CuisineType>? cuisines,
    List<MealType>? meals,
    List<DietaryOption>? dietary,
    List<ServiceOption>? services,
    PriceLevel? priceLevel,
    Money? averageCostForTwo,
    double? rating,
    int? reviewCount,
    RestaurantHours? hours,
    RestaurantContact? contact,
    List<String>? photos,
    List<MenuItem>? menu,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.description,
      cuisines: cuisines ?? this.cuisines,
      meals: meals ?? this.meals,
      dietary: dietary ?? this.dietary,
      services: services ?? this.services,
      priceLevel: priceLevel ?? this.priceLevel,
      averageCostForTwo: averageCostForTwo ?? this.averageCostForTwo,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      hours: hours ?? this.hours,
      contact: contact ?? this.contact,
      photos: photos ?? this.photos,
      menu: menu ?? this.menu,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // -------- JSON --------

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    List<T> parseEnumList<T>(List? raw, T Function(String) parseOne) {
      final xs = (raw ?? const <dynamic>[]);
      return xs.map((e) => parseOne(e.toString())).toList(growable: false);
    }

    CuisineType parseCuisine(String s) => CuisineType.parse(s);
    MealType parseMeal(String s) {
      try {
        return MealType.values.byName(s);
      } catch (_) {
        switch (s.toLowerCase()) {
          case 'late_night':
          case 'latenight':
            return MealType.lateNight;
          case 'high_tea':
          case 'hightea':
            return MealType.highTea;
          default:
            return MealType.dinner;
        }
      }
    }

    DietaryOption parseDiet(String s) {
      try {
        return DietaryOption.values.byName(s);
      } catch (_) {
        switch (s.toLowerCase()) {
          case 'gluten_free':
          case 'gluten-free':
            return DietaryOption.glutenFree;
          default:
            return DietaryOption.none;
        }
      }
    }

    ServiceOption parseService(String s) {
      try {
        return ServiceOption.values.byName(s);
      } catch (_) {
        switch (s.toLowerCase()) {
          case 'outdoor_seating':
          case 'outdoorseating':
            return ServiceOption.outdoorSeating;
          case 'wheelchair_accessible':
          case 'wheelchair':
            return ServiceOption.wheelchairAccessible;
          case 'wifi':
            return ServiceOption.wifi;
          case 'a/c':
          case 'airconditioning':
          case 'air_conditioning':
            return ServiceOption.ac;
          default:
            return ServiceOption.dineIn;
        }
      }
    }

    PriceLevel? parsePrice(Object? v) {
      if (v == null) return null;
      final s = v.toString();
      try {
        return PriceLevel.values.byName(s);
      } catch (_) {
        switch (s) {
          case '₹':
            return PriceLevel.cheap;
          case '₹₹':
            return PriceLevel.moderate;
          case '₹₹₹':
            return PriceLevel.expensive;
          case '₹₹₹₹':
            return PriceLevel.luxury;
          default:
            return null;
        }
      }
    }

    final menuRaw = (json['menu'] as List?) ?? const <dynamic>[];

    return Restaurant(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      location: PlaceLocation.fromJson((json['location'] as Map).cast<String, dynamic>()),
      description: (json['description'] as String?)?.toString(),
      cuisines: parseEnumList<CuisineType>(json['cuisines'] as List?, parseCuisine),
      meals: parseEnumList<MealType>(json['meals'] as List?, parseMeal),
      dietary: parseEnumList<DietaryOption>(json['dietary'] as List?, parseDiet),
      services: parseEnumList<ServiceOption>(json['services'] as List?, parseService),
      priceLevel: parsePrice(json['priceLevel']),
      averageCostForTwo: json['averageCostForTwo'] != null
          ? Money.fromJson((json['averageCostForTwo'] as Map).cast<String, dynamic>())
          : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      hours: json['hours'] != null ? RestaurantHours.fromJson((json['hours'] as Map).cast<String, dynamic>()) : null,
      contact: json['contact'] != null ? RestaurantContact.fromJson((json['contact'] as Map).cast<String, dynamic>()) : null,
      photos: ((json['photos'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      menu: menuRaw.whereType<Map<String, dynamic>>().map(MenuItem.fromJson).toList(growable: false),
      tags: ((json['tags'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList(growable: false),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'location': location.toJson(),
        if (description != null) 'description': description,
        if (cuisines.isNotEmpty) 'cuisines': cuisines.map((c) => c.name).toList(growable: false),
        if (meals.isNotEmpty) 'meals': meals.map((m) => m.name).toList(growable: false),
        if (dietary.isNotEmpty) 'dietary': dietary.map((d) => d.name).toList(growable: false),
        if (services.isNotEmpty) 'services': services.map((s) => s.name).toList(growable: false),
        if (priceLevel != null) 'priceLevel': priceLevel!.name,
        if (averageCostForTwo != null) 'averageCostForTwo': averageCostForTwo!.toJson(),
        'rating': rating,
        'reviewCount': reviewCount,
        if (hours != null) 'hours': hours!.toJson(),
        if (contact != null) 'contact': contact!.toJson(),
        if (photos.isNotEmpty) 'photos': photos,
        if (menu.isNotEmpty) 'menu': menu.map((m) => m.toJson()).toList(growable: false),
        if (tags.isNotEmpty) 'tags': tags,
        if (metadata != null) 'metadata': metadata,
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is Restaurant &&
      other.id == id &&
      other.name == name &&
      other.location == location &&
      listEquals(other.cuisines, cuisines) &&
      listEquals(other.meals, meals) &&
      listEquals(other.dietary, dietary) &&
      listEquals(other.services, services) &&
      other.priceLevel == priceLevel &&
      other.averageCostForTwo == averageCostForTwo &&
      other.rating == rating &&
      other.reviewCount == reviewCount &&
      other.hours == hours &&
      other.contact == contact &&
      listEquals(other.photos, photos) &&
      listEquals(other.menu, menu) &&
      listEquals(other.tags, tags) &&
      mapEquals(other.metadata, metadata) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        location,
        Object.hashAll(cuisines),
        Object.hashAll(meals),
        Object.hashAll(dietary),
        Object.hashAll(services),
        priceLevel,
        averageCostForTwo,
        rating,
        reviewCount,
        hours,
        contact,
        Object.hashAll(photos),
        Object.hashAll(menu),
        Object.hashAll(tags),
        _mapHash(metadata),
        createdAt,
        updatedAt,
      );

  int _mapHash(Map<String, dynamic>? m) => m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
