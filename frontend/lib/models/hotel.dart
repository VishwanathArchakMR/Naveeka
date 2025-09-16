// lib/models/hotel.dart

import 'package:flutter/foundation.dart';
import 'booking.dart' show Money;
import 'coordinates.dart';

/// Star classification is widely used but not globally uniform; values 1–5 with half-stars optional. [2][8]
enum HotelStarClass { one, two, three, four, five, unrated }

/// Common amenity taxonomy; apps may map provider-specific labels into these buckets. [6][12]
enum HotelAmenity {
  wifi,
  breakfast,
  parking,
  pool,
  spa,
  gym,
  restaurant,
  bar,
  roomService,
  airConditioning,
  heating,
  tv,
  kettle,
  minibar,
  safe,
  hairdryer,
  workspace,
  laundry,
  accessible, // accessibility features present
  shuttle, // airport/city shuttle
  petsAllowed,
  nonSmoking,
  electricVehicleCharging,
  balcony,
  kitchenette,
  beachAccess,
  kidsClub,
  businessCenter,
  concierge,
  // generic fallback for unmapped labels
  other,
}

/// Rate policy flags that influence UI/UX for selection and cancellation.
enum RatePolicy { refundable, nonRefundable, payAtHotel, prepay, memberOnly, breakfastIncluded }

/// Address value object for display, search, and geocoding.
@immutable
class Address {
  const Address({
    this.line1,
    this.line2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.countryCode,
  });

  final String? line1;
  final String? line2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? countryCode; // ISO-2 like IN/US

  String get short => [city, country].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
  String get full {
    final parts = <String>[
      line1 ?? '',
      line2 ?? '',
      city ?? '',
      state ?? '',
      postalCode ?? '',
      country ?? ''
    ].where((e) => e.trim().isNotEmpty).toList(growable: false);
    return parts.join(', ');
  }

  Address copyWith({
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? countryCode,
  }) {
    return Address(
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        line1: (json['line1'] as String?)?.toString(),
        line2: (json['line2'] as String?)?.toString(),
        city: (json['city'] as String?)?.toString(),
        state: (json['state'] as String?)?.toString(),
        postalCode: (json['postalCode'] as String?)?.toString(),
        country: (json['country'] as String?)?.toString(),
        countryCode: (json['countryCode'] as String?)?.toUpperCase(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (line1 != null) 'line1': line1,
        if (line2 != null) 'line2': line2,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (postalCode != null) 'postalCode': postalCode,
        if (country != null) 'country': country,
        if (countryCode != null) 'countryCode': countryCode,
      };

  @override
  bool operator ==(Object other) =>
      other is Address &&
      other.line1 == line1 &&
      other.line2 == line2 &&
      other.city == city &&
      other.state == state &&
      other.postalCode == postalCode &&
      other.country == country &&
      other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(line1, line2, city, state, postalCode, country, countryCode);
}

/// Basic photo asset; width/height allow responsive layout sizing.
@immutable
class HotelPhoto {
  const HotelPhoto({required this.url, this.caption, this.width, this.height, this.isCover = false});

  final String url;
  final String? caption;
  final int? width;
  final int? height;
  final bool isCover;

  HotelPhoto copyWith({String? url, String? caption, int? width, int? height, bool? isCover}) => HotelPhoto(
        url: url ?? this.url,
        caption: caption ?? this.caption,
        width: width ?? this.width,
        height: height ?? this.height,
        isCover: isCover ?? this.isCover,
      );

  factory HotelPhoto.fromJson(Map<String, dynamic> json) => HotelPhoto(
        url: (json['url'] ?? '').toString(),
        caption: (json['caption'] as String?)?.toString(),
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        isCover: (json['isCover'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        if (caption != null) 'caption': caption,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'isCover': isCover,
      };

  @override
  bool operator ==(Object other) =>
      other is HotelPhoto &&
      other.url == url &&
      other.caption == caption &&
      other.width == width &&
      other.height == height &&
      other.isCover == isCover;

  @override
  int get hashCode => Object.hash(url, caption, width, height, isCover);
}

/// Room definition (type-level), separate from pricing; e.g., Deluxe King, Twin, Suite.
@immutable
class HotelRoom {
  const HotelRoom({
    required this.id,
    required this.name,
    this.description,
    this.maxGuests,
    this.beds, // e.g., "1 King" or "2 Twin"
    this.sizeSqm,
    this.photos = const <HotelPhoto>[],
    this.amenities = const <HotelAmenity>[],
  });

  final String id;
  final String name;
  final String? description;
  final int? maxGuests;
  final String? beds;
  final double? sizeSqm;
  final List<HotelPhoto> photos;
  final List<HotelAmenity> amenities;

  bool hasAmenity(HotelAmenity a) => amenities.contains(a);

  HotelRoom copyWith({
    String? id,
    String? name,
    String? description,
    int? maxGuests,
    String? beds,
    double? sizeSqm,
    List<HotelPhoto>? photos,
    List<HotelAmenity>? amenities,
  }) {
    return HotelRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      maxGuests: maxGuests ?? this.maxGuests,
      beds: beds ?? this.beds,
      sizeSqm: sizeSqm ?? this.sizeSqm,
      photos: photos ?? this.photos,
      amenities: amenities ?? this.amenities,
    );
  }

  static HotelAmenity _parseAmenity(Object? v) {
    final s = (v ?? 'other').toString();
    try {
      return HotelAmenity.values.byName(s);
    } catch (_) {
      // basic mapping for common labels
      switch (s.toLowerCase()) {
        case 'wifi':
        case 'wi-fi':
          return HotelAmenity.wifi;
        case 'breakfast':
          return HotelAmenity.breakfast;
        case 'ac':
        case 'airconditioning':
          return HotelAmenity.airConditioning;
        default:
          return HotelAmenity.other;
      }
    }
  } // amenity parsing with safe fallback

  factory HotelRoom.fromJson(Map<String, dynamic> json) {
    final raws = (json['amenities'] as List?) ?? const <dynamic>[];
    final rawPhotos = (json['photos'] as List?) ?? const <dynamic>[];
    return HotelRoom(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] as String?)?.toString(),
      maxGuests: (json['maxGuests'] as num?)?.toInt(),
      beds: (json['beds'] as String?)?.toString(),
      sizeSqm: (json['sizeSqm'] as num?)?.toDouble(),
      photos: rawPhotos.whereType<Map<String, dynamic>>().map(HotelPhoto.fromJson).toList(growable: false),
      amenities: raws.map(_parseAmenity).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (maxGuests != null) 'maxGuests': maxGuests,
        if (beds != null) 'beds': beds,
        if (sizeSqm != null) 'sizeSqm': sizeSqm,
        if (photos.isNotEmpty) 'photos': photos.map((p) => p.toJson()).toList(growable: false),
        if (amenities.isNotEmpty) 'amenities': amenities.map((a) => a.name).toList(growable: false),
      };

  @override
  bool operator ==(Object other) =>
      other is HotelRoom &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.maxGuests == maxGuests &&
      other.beds == beds &&
      other.sizeSqm == sizeSqm &&
      listEquals(other.photos, photos) &&
      listEquals(other.amenities, amenities);

  @override
  int get hashCode => Object.hash(id, name, description, maxGuests, beds, sizeSqm, Object.hashAll(photos), Object.hashAll(amenities));
}

/// Rate plan pricing/conditions for a room on a specific date or range.
@immutable
class RatePlan {
  const RatePlan({
    required this.id,
    required this.roomId,
    required this.name,
    this.description,
    this.policies = const <RatePolicy>[],
    this.currency,
    this.base,
    this.taxes,
    this.total,
    this.freeCancellationUntil, // timestamp for refundable cutoff
    this.checkInFrom, // local time string HH:mm
    this.checkOutUntil, // local time string HH:mm
    this.includesBreakfast = false,
    this.metadata,
  });

  final String id;
  final String roomId;
  final String name;
  final String? description;
  final List<RatePolicy> policies;
  final String? currency;
  final Money? base;
  final Money? taxes;
  final Money? total;
  final DateTime? freeCancellationUntil;
  final String? checkInFrom;
  final String? checkOutUntil;
  final bool includesBreakfast;
  final Map<String, dynamic>? metadata;

  bool get isRefundable => policies.contains(RatePolicy.refundable) || freeCancellationUntil != null;
  bool get isPayAtHotel => policies.contains(RatePolicy.payAtHotel);

  RatePlan copyWith({
    String? id,
    String? roomId,
    String? name,
    String? description,
    List<RatePolicy>? policies,
    String? currency,
    Money? base,
    Money? taxes,
    Money? total,
    DateTime? freeCancellationUntil,
    String? checkInFrom,
    String? checkOutUntil,
    bool? includesBreakfast,
    Map<String, dynamic>? metadata,
  }) {
    return RatePlan(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      description: description ?? this.description,
      policies: policies ?? this.policies,
      currency: currency ?? this.currency,
      base: base ?? this.base,
      taxes: taxes ?? this.taxes,
      total: total ?? this.total,
      freeCancellationUntil: freeCancellationUntil ?? this.freeCancellationUntil,
      checkInFrom: checkInFrom ?? this.checkInFrom,
      checkOutUntil: checkOutUntil ?? this.checkOutUntil,
      includesBreakfast: includesBreakfast ?? this.includesBreakfast,
      metadata: metadata ?? this.metadata,
    );
  }

  static RatePolicy _parsePolicy(Object? v) {
    final s = (v ?? '').toString();
    try {
      return RatePolicy.values.byName(s);
    } catch (_) {
      switch (s.toLowerCase()) {
        case 'non_refundable':
        case 'nonrefundable':
          return RatePolicy.nonRefundable;
        case 'refundable':
          return RatePolicy.refundable;
        case 'pay_at_hotel':
        case 'payathotel':
          return RatePolicy.payAtHotel;
        case 'prepay':
          return RatePolicy.prepay;
        case 'member_only':
        case 'memberonly':
          return RatePolicy.memberOnly;
        case 'breakfast_included':
        case 'breakfast':
          return RatePolicy.breakfastIncluded;
        default:
          return RatePolicy.prepay;
      }
    }
  }

  factory RatePlan.fromJson(Map<String, dynamic> json) {
    final rawPolicies = (json['policies'] as List?) ?? const <dynamic>[];
    return RatePlan(
      id: (json['id'] ?? '').toString(),
      roomId: (json['roomId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] as String?)?.toString(),
      policies: rawPolicies.map(_parsePolicy).toList(growable: false),
      currency: (json['currency'] as String?)?.toUpperCase(),
      base: json['base'] != null ? Money.fromJson((json['base'] as Map).cast<String, dynamic>()) : null,
      taxes: json['taxes'] != null ? Money.fromJson((json['taxes'] as Map).cast<String, dynamic>()) : null,
      total: json['total'] != null ? Money.fromJson((json['total'] as Map).cast<String, dynamic>()) : null,
      freeCancellationUntil: json['freeCancellationUntil'] != null ? DateTime.tryParse(json['freeCancellationUntil'].toString()) : null,
      checkInFrom: (json['checkInFrom'] as String?)?.toString(),
      checkOutUntil: (json['checkOutUntil'] as String?)?.toString(),
      includesBreakfast: (json['includesBreakfast'] as bool?) ?? false,
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'roomId': roomId,
        'name': name,
        if (description != null) 'description': description,
        if (policies.isNotEmpty) 'policies': policies.map((p) => p.name).toList(growable: false),
        if (currency != null) 'currency': currency,
        if (base != null) 'base': base!.toJson(),
        if (taxes != null) 'taxes': taxes!.toJson(),
        if (total != null) 'total': total!.toJson(),
        if (freeCancellationUntil != null) 'freeCancellationUntil': freeCancellationUntil!.toUtc().toIso8601String(),
        if (checkInFrom != null) 'checkInFrom': checkInFrom,
        if (checkOutUntil != null) 'checkOutUntil': checkOutUntil,
        'includesBreakfast': includesBreakfast,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Root Hotel model with denormalized fields for fast UI and detailed lists for detail view.
@immutable
class Hotel {
  const Hotel({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    this.starClass = HotelStarClass.unrated,
    this.address,
    this.coordinates,
    this.phone,
    this.email,
    this.website,
    this.photos = const <HotelPhoto>[],
    this.amenities = const <HotelAmenity>[],
    this.rooms = const <HotelRoom>[],
    this.ratePlans = const <RatePlan>[],
    this.rating, // average guest rating 0..5
    this.reviewCount,
    this.checkInFrom,
    this.checkOutUntil,
    this.metadata,
  });

  final String id;
  final String name;
  final String? brand;
  final String? description;
  final HotelStarClass starClass;
  final Address? address;
  final Coordinates? coordinates;
  final String? phone;
  final String? email;
  final String? website;
  final List<HotelPhoto> photos;
  final List<HotelAmenity> amenities;
  final List<HotelRoom> rooms;
  final List<RatePlan> ratePlans;
  final double? rating;
  final int? reviewCount;
  final String? checkInFrom; // HH:mm local
  final String? checkOutUntil; // HH:mm local
  final Map<String, dynamic>? metadata;

  String get starText {
    switch (starClass) {
      case HotelStarClass.one:
        return '1★';
      case HotelStarClass.two:
        return '2★';
      case HotelStarClass.three:
        return '3★';
      case HotelStarClass.four:
        return '4★';
      case HotelStarClass.five:
        return '5★';
      case HotelStarClass.unrated:
        return 'Unrated';
    }
  } // user-friendly star label [2][5]

  /// Short location line like "City, Country".
  String get locationLine => address?.short ?? '';

  /// Returns the minimum total among rate plans if present.
  Money? get lowestTotal {
    if (ratePlans.isEmpty) return null;
    final totals = ratePlans.map((r) => r.total).whereType<Money>().toList(growable: false);
    if (totals.isEmpty) return null;
    totals.sort((a, b) => a.amountMinor.compareTo(b.amountMinor));
    return totals.first;
  }

  bool hasAmenity(HotelAmenity a) => amenities.contains(a);

  Hotel copyWith({
    String? id,
    String? name,
    String? brand,
    String? description,
    HotelStarClass? starClass,
    Address? address,
    Coordinates? coordinates,
    String? phone,
    String? email,
    String? website,
    List<HotelPhoto>? photos,
    List<HotelAmenity>? amenities,
    List<HotelRoom>? rooms,
    List<RatePlan>? ratePlans,
    double? rating,
    int? reviewCount,
    String? checkInFrom,
    String? checkOutUntil,
    Map<String, dynamic>? metadata,
  }) {
    return Hotel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      description: description ?? this.description,
      starClass: starClass ?? this.starClass,
      address: address ?? this.address,
      coordinates: coordinates ?? this.coordinates,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      photos: photos ?? this.photos,
      amenities: amenities ?? this.amenities,
      rooms: rooms ?? this.rooms,
      ratePlans: ratePlans ?? this.ratePlans,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      checkInFrom: checkInFrom ?? this.checkInFrom,
      checkOutUntil: checkOutUntil ?? this.checkOutUntil,
      metadata: metadata ?? this.metadata,
    );
  }

  static HotelStarClass _parseStars(Object? v) {
    final s = (v ?? 'unrated').toString();
    try {
      return HotelStarClass.values.byName(s);
    } catch (_) {
      // tolerate numeric or string like "5"
      switch (s) {
        case '1':
          return HotelStarClass.one;
        case '2':
          return HotelStarClass.two;
        case '3':
          return HotelStarClass.three;
        case '4':
          return HotelStarClass.four;
        case '5':
          return HotelStarClass.five;
        default:
          return HotelStarClass.unrated;
      }
    }
  } // star parsing with fallback [2][8]

  static HotelAmenity _parseAmenity(Object? v) => HotelRoom._parseAmenity(v);

  factory Hotel.fromJson(Map<String, dynamic> json) {
    final rawAmenities = (json['amenities'] as List?) ?? const <dynamic>[];
    final rawPhotos = (json['photos'] as List?) ?? const <dynamic>[];
    final rawRooms = (json['rooms'] as List?) ?? const <dynamic>[];
    final rawRates = (json['ratePlans'] as List?) ?? const <dynamic>[];

    return Hotel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      brand: (json['brand'] as String?)?.toString(),
      description: (json['description'] as String?)?.toString(),
      starClass: _parseStars(json['starClass'] ?? json['stars']),
      address: json['address'] != null ? Address.fromJson((json['address'] as Map).cast<String, dynamic>()) : null,
      coordinates: json['coordinates'] != null ? Coordinates.fromJson((json['coordinates'] as Map).cast<String, dynamic>()) : null,
      phone: (json['phone'] as String?)?.toString(),
      email: (json['email'] as String?)?.toString(),
      website: (json['website'] as String?)?.toString(),
      photos: rawPhotos.whereType<Map<String, dynamic>>().map(HotelPhoto.fromJson).toList(growable: false),
      amenities: rawAmenities.map(_parseAmenity).toList(growable: false),
      rooms: rawRooms.whereType<Map<String, dynamic>>().map(HotelRoom.fromJson).toList(growable: false),
      ratePlans: rawRates.whereType<Map<String, dynamic>>().map(RatePlan.fromJson).toList(growable: false),
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt(),
      checkInFrom: (json['checkInFrom'] as String?)?.toString(),
      checkOutUntil: (json['checkOutUntil'] as String?)?.toString(),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  } // Manual JSON per Flutter guidance, with robust nested parsing. [16][7]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (brand != null) 'brand': brand,
        if (description != null) 'description': description,
        'starClass': starClass.name,
        if (address != null) 'address': address!.toJson(),
        if (coordinates != null) 'coordinates': coordinates!.toJson(),
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (website != null) 'website': website,
        if (photos.isNotEmpty) 'photos': photos.map((p) => p.toJson()).toList(growable: false),
        if (amenities.isNotEmpty) 'amenities': amenities.map((a) => a.name).toList(growable: false),
        if (rooms.isNotEmpty) 'rooms': rooms.map((r) => r.toJson()).toList(growable: false),
        if (ratePlans.isNotEmpty) 'ratePlans': ratePlans.map((r) => r.toJson()).toList(growable: false),
        if (rating != null) 'rating': rating,
        if (reviewCount != null) 'reviewCount': reviewCount,
        if (checkInFrom != null) 'checkInFrom': checkInFrom,
        if (checkOutUntil != null) 'checkOutUntil': checkOutUntil,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is Hotel &&
      other.id == id &&
      other.name == name &&
      other.brand == brand &&
      other.description == description &&
      other.starClass == starClass &&
      other.address == address &&
      other.coordinates == coordinates &&
      other.phone == phone &&
      other.email == email &&
      other.website == website &&
      listEquals(other.photos, photos) &&
      listEquals(other.amenities, amenities) &&
      listEquals(other.rooms, rooms) &&
      listEquals(other.ratePlans, ratePlans) &&
      other.rating == rating &&
      other.reviewCount == reviewCount &&
      other.checkInFrom == checkInFrom &&
      other.checkOutUntil == checkOutUntil &&
      mapEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        brand,
        description,
        starClass,
        address,
        coordinates,
        phone,
        email,
        website,
        Object.hashAll(photos),
        Object.hashAll(amenities),
        Object.hashAll(rooms),
        Object.hashAll(ratePlans),
        rating,
        reviewCount,
        checkInFrom,
        checkOutUntil,
        _mapHash(metadata),
      );

  int _mapHash(Map<String, dynamic>? m) => m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
