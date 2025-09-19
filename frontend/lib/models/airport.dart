// lib/models/airport.dart

import 'package:flutter/foundation.dart';

/// A world airport or aerodrome with standard codes and geo metadata.
/// - IATA: three-letter commercial code (e.g., SFO) [passenger-facing]
/// - ICAO: four-letter operations code (e.g., KSFO) [ATC/operations] [8][1]
@immutable
class Airport {
  const Airport({
    required this.id,
    required this.name,
    this.iata,
    this.icao,
    this.city,
    this.country,
    this.countryCode, // ISO-2 if available (e.g., US, IN)
    this.latitude,
    this.longitude,
    this.elevationM,
    this.timezone, // IANA TZ (e.g., Asia/Kolkata)
    this.tzOffsetMinutes, // UTC offset minutes at standard time (approx)
    this.phone,
    this.website,
    this.isInternational = false,
    this.isMilitary = false,
    this.isClosed = false,
    this.metadata,
  });

  final String id;
  final String name;

  final String? iata; // 3-letter IATA
  final String? icao; // 4-letter ICAO

  final String? city;
  final String? country;
  final String? countryCode;

  final double? latitude;
  final double? longitude;
  final double? elevationM;

  /// IANA tz identifier such as 'Asia/Kolkata' (preferred for correctness). [13][7]
  final String? timezone;

  /// UTC offset in minutes (e.g., +330 for IST); optional convenience.
  final int? tzOffsetMinutes;

  final String? phone;
  final String? website;

  final bool isInternational;
  final bool isMilitary;
  final bool isClosed;

  /// Extra server-defined properties (e.g., terminals, runways, servedCities).
  final Map<String, dynamic>? metadata;

  // ---------- Derived helpers ----------

  /// Code to show in UI preference order: IATA > ICAO > id.
  String get code => (iata?.trim().isNotEmpty == true)
      ? iata!.toUpperCase()
      : (icao?.trim().isNotEmpty == true)
          ? icao!.toUpperCase()
          : id.toUpperCase();

  /// "CODE — Name" e.g., "SFO — San Francisco International Airport".
  String get codeTitle => '$code — $name';

  /// "City, Country" or best available.
  String get placeLabel {
    final c = (city ?? '').trim();
    final k = (country ?? '').trim();
    if (c.isNotEmpty && k.isNotEmpty) return '$c, $k';
    if (c.isNotEmpty) return c;
    if (k.isNotEmpty) return k;
    return '';
  }

  Airport copyWith({
    String? id,
    String? name,
    String? iata,
    String? icao,
    String? city,
    String? country,
    String? countryCode,
    double? latitude,
    double? longitude,
    double? elevationM,
    String? timezone,
    int? tzOffsetMinutes,
    String? phone,
    String? website,
    bool? isInternational,
    bool? isMilitary,
    bool? isClosed,
    Map<String, dynamic>? metadata,
  }) {
    return Airport(
      id: id ?? this.id,
      name: name ?? this.name,
      iata: iata ?? this.iata,
      icao: icao ?? this.icao,
      city: city ?? this.city,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevationM: elevationM ?? this.elevationM,
      timezone: timezone ?? this.timezone,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      isInternational: isInternational ?? this.isInternational,
      isMilitary: isMilitary ?? this.isMilitary,
      isClosed: isClosed ?? this.isClosed,
      metadata: metadata ?? this.metadata,
    );
  }

  // ---------- JSON ----------

  factory Airport.fromJson(Map<String, dynamic> json) {
    double? toD(Object? x) {
      if (x == null) return null;
      if (x is num) return x.toDouble();
      final s = x.toString().trim();
      if (s.isEmpty) return null;
      return double.tryParse(s);
    }

    int? toI(Object? x) {
      if (x == null) return null;
      if (x is num) return x.toInt();
      final s = x.toString().trim();
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }

    return Airport(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      iata: (json['iata'] as String?)?.toUpperCase(),
      icao: (json['icao'] as String?)?.toUpperCase(),
      city: (json['city'] as String?)?.toString(),
      country: (json['country'] as String?)?.toString(),
      countryCode: (json['countryCode'] as String?)?.toUpperCase(),
      latitude: toD(json['lat'] ?? json['latitude']),
      longitude: toD(json['lng'] ?? json['longitude']),
      elevationM: toD(json['elevationM'] ?? json['elevation']),
      timezone: (json['timezone'] as String?)?.toString(),
      tzOffsetMinutes: toI(json['tzOffsetMinutes'] ?? json['utcOffsetMinutes']),
      phone: (json['phone'] as String?)?.toString(),
      website: (json['website'] as String?)?.toString(),
      isInternational: (json['isInternational'] as bool?) ?? false,
      isMilitary: (json['isMilitary'] as bool?) ?? false,
      isClosed: (json['isClosed'] as bool?) ?? false,
      metadata: (json['metadata'] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      if (iata != null) 'iata': iata,
      if (icao != null) 'icao': icao,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (countryCode != null) 'countryCode': countryCode,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
      if (elevationM != null) 'elevationM': elevationM,
      if (timezone != null) 'timezone': timezone,
      if (tzOffsetMinutes != null) 'tzOffsetMinutes': tzOffsetMinutes,
      if (phone != null) 'phone': phone,
      if (website != null) 'website': website,
      'isInternational': isInternational,
      'isMilitary': isMilitary,
      'isClosed': isClosed,
      if (metadata != null) 'metadata': metadata,
    };
  }

  // ---------- Equality / hash / debug ----------

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Airport &&
            other.id == id &&
            other.name == name &&
            other.iata == iata &&
            other.icao == icao &&
            other.city == city &&
            other.country == country &&
            other.countryCode == countryCode &&
            other.latitude == latitude &&
            other.longitude == longitude &&
            other.elevationM == elevationM &&
            other.timezone == timezone &&
            other.tzOffsetMinutes == tzOffsetMinutes &&
            other.phone == phone &&
            other.website == website &&
            other.isInternational == isInternational &&
            other.isMilitary == isMilitary &&
            other.isClosed == isClosed &&
            mapEquals(other.metadata, metadata));
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        iata,
        icao,
        city,
        country,
        countryCode,
        latitude,
        longitude,
        elevationM,
        timezone,
        tzOffsetMinutes,
        phone,
        website,
        isInternational,
        isMilitary,
        isClosed,
        _mapHash(metadata),
      );

  int _mapHash(Map<String, dynamic>? m) {
    if (m == null) return 0;
    return Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
  }

  @override
  String toString() => 'Airport($codeTitle, $placeLabel)';
}
