// lib/models/train_station.dart

import 'package:flutter/foundation.dart';
import 'coordinates.dart';

/// GTFS location_type values: 0 stop/platform, 1 station, 2 entrance/exit, 3 generic node, 4 boarding area. [station-centric]
enum StationLocationType {
  stopPlatform, // 0
  station,      // 1
  entranceExit, // 2
  genericNode,  // 3
  boardingArea, // 4
}

/// GTFS wheelchair_boarding semantics: 0 unknown/inherit, 1 accessible, 2 not accessible.
enum WheelchairBoarding {
  unknownOrInherit, // 0
  accessible,       // 1
  notAccessible,    // 2
}

@immutable
class TrainStation {
  const TrainStation({
    required this.id,            // GTFS stop_id
    required this.name,          // stop_name
    this.code,                   // stop_code
    this.coordinates,            // (lat, lon)
    this.city,
    this.country,
    this.countryCode,            // ISO-2
    this.timezone,               // IANA tz like Asia/Kolkata
    this.zoneId,                 // GTFS fare zone
    this.locationType = StationLocationType.station,
    this.parentStation,          // references another stop_id when this is a platform/entrance
    this.platformCode,           // platform identifier (e.g., "2" or "A")
    this.wheelchairBoarding = WheelchairBoarding.unknownOrInherit,
    this.operators = const <String>[],
    this.lines = const <String>[],
    this.address,
    this.amenities = const <String>[],
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? code;
  final Coordinates? coordinates;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? timezone;
  final String? zoneId;

  final StationLocationType locationType;
  final String? parentStation;
  final String? platformCode;
  final WheelchairBoarding wheelchairBoarding;

  /// Operator brands (e.g., IR, Metro, National Rail codes).
  final List<String> operators;

  /// Lines/services that serve the station (e.g., "Blue Line", "Vande Bharat 22439").
  final List<String> lines;

  /// Optional free-form address line for display/search.
  final String? address;

  /// Amenities like "parking", "restrooms", "food court".
  final List<String> amenities;

  final Map<String, dynamic>? metadata;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ---------- Derived helpers ----------

  /// Prefer stop_code if present, else stop_id.
  String get displayCode => (code != null && code!.trim().isNotEmpty) ? code!.trim() : id;

  /// "CODE — Name" e.g., "NDLS — New Delhi".
  String get codeTitle => '$displayCode — $name';

  /// "City, Country" or best available.
  String get placeLabel {
    final c = (city ?? '').trim();
    final k = (country ?? '').trim();
    if (c.isNotEmpty && k.isNotEmpty) return '$c, $k';
    if (c.isNotEmpty) return c;
    if (k.isNotEmpty) return k;
    return '';
  }

  bool get hasCoordinates => coordinates != null;

  TrainStation copyWith({
    String? id,
    String? name,
    String? code,
    Coordinates? coordinates,
    String? city,
    String? country,
    String? countryCode,
    String? timezone,
    String? zoneId,
    StationLocationType? locationType,
    String? parentStation,
    String? platformCode,
    WheelchairBoarding? wheelchairBoarding,
    List<String>? operators,
    List<String>? lines,
    String? address,
    List<String>? amenities,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainStation(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      coordinates: coordinates ?? this.coordinates,
      city: city ?? this.city,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      timezone: timezone ?? this.timezone,
      zoneId: zoneId ?? this.zoneId,
      locationType: locationType ?? this.locationType,
      parentStation: parentStation ?? this.parentStation,
      platformCode: platformCode ?? this.platformCode,
      wheelchairBoarding: wheelchairBoarding ?? this.wheelchairBoarding,
      operators: operators ?? this.operators,
      lines: lines ?? this.lines,
      address: address ?? this.address,
      amenities: amenities ?? this.amenities,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ---------- JSON ----------

  static StationLocationType _locFrom(Object? x) {
    final raw = (x ?? '').toString().trim();
    if (raw.isEmpty || raw == '0') return StationLocationType.stopPlatform;
    switch (raw) {
      case '1':
        return StationLocationType.station;
      case '2':
        return StationLocationType.entranceExit;
      case '3':
        return StationLocationType.genericNode;
      case '4':
        return StationLocationType.boardingArea;
      default:
        try {
          return StationLocationType.values.byName(raw);
        } catch (_) {
          return StationLocationType.station;
        }
    }
  }

  static String _locTo(StationLocationType t) {
    switch (t) {
      case StationLocationType.stopPlatform:
        return '0';
      case StationLocationType.station:
        return '1';
      case StationLocationType.entranceExit:
        return '2';
      case StationLocationType.genericNode:
        return '3';
      case StationLocationType.boardingArea:
        return '4';
    }
  }

  static WheelchairBoarding _wcFrom(Object? x) {
    final raw = (x ?? '').toString().trim();
    if (raw.isEmpty || raw == '0') return WheelchairBoarding.unknownOrInherit;
    if (raw == '1') return WheelchairBoarding.accessible;
    if (raw == '2') return WheelchairBoarding.notAccessible;
    try {
      return WheelchairBoarding.values.byName(raw);
    } catch (_) {
      return WheelchairBoarding.unknownOrInherit;
    }
  }

  static String _wcTo(WheelchairBoarding w) {
    switch (w) {
      case WheelchairBoarding.unknownOrInherit:
        return '0';
      case WheelchairBoarding.accessible:
        return '1';
      case WheelchairBoarding.notAccessible:
        return '2';
    }
  }

  factory TrainStation.fromJson(Map<String, dynamic> json) {
    // Accept GTFS-style inputs and app-specific fields.
    final coords = (json['coordinates'] as Map?)?.cast<String, dynamic>();
    Coordinates? parseCoords() {
      if (coords != null) return Coordinates.fromJson(coords);
      // Tolerate lat/lon layouts from GTFS fields.
      final lat = json['stop_lat'] ?? json['lat'];
      final lon = json['stop_lon'] ?? json['lon'] ?? json['lng'];
      if (lat != null && lon != null) {
        return Coordinates.fromJson({'lat': lat, 'lng': lon});
      }
      return null;
    }

    List<String> parseList(List? raw) => (raw ?? const <dynamic>[])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);

    return TrainStation(
      id: (json['stop_id'] ?? json['id'] ?? '').toString(),
      name: (json['stop_name'] ?? json['name'] ?? '').toString(),
      code: (json['stop_code'] ?? json['code'] as String?)?.toString(),
      coordinates: parseCoords(),
      city: (json['city'] as String?)?.toString(),
      country: (json['country'] as String?)?.toString(),
      countryCode: (json['countryCode'] as String?)?.toUpperCase(),
      timezone: (json['stop_timezone'] as String?)?.toString(),
      zoneId: (json['zone_id'] as String?)?.toString(),
      locationType: _locFrom(json['location_type']),
      parentStation: (json['parent_station'] as String?)?.toString(),
      platformCode: (json['platform_code'] as String?)?.toString(),
      wheelchairBoarding: _wcFrom(json['wheelchair_boarding']),
      operators: parseList(json['operators'] as List?),
      lines: parseList(json['lines'] as List?),
      address: (json['address'] as String?)?.toString(),
      amenities: parseList(json['amenities'] as List?),
      metadata: (json['metadata'] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        // GTFS-compatible fields where relevant
        'stop_id': id,
        'stop_name': name,
        if (code != null) 'stop_code': code,
        if (coordinates != null) ...coordinates!.toJson(),
        if (coordinates != null) 'coordinates': coordinates!.toJson(),
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (countryCode != null) 'countryCode': countryCode,
        if (timezone != null) 'stop_timezone': timezone,
        if (zoneId != null) 'zone_id': zoneId,
        'location_type': _locTo(locationType),
        if (parentStation != null) 'parent_station': parentStation,
        if (platformCode != null) 'platform_code': platformCode,
        'wheelchair_boarding': _wcTo(wheelchairBoarding),
        if (operators.isNotEmpty) 'operators': operators,
        if (lines.isNotEmpty) 'lines': lines,
        if (address != null) 'address': address,
        if (amenities.isNotEmpty) 'amenities': amenities,
        if (metadata != null) 'metadata': metadata,
        if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
      };

  /// GeoJSON Feature output with Point geometry and [lon, lat] order, per RFC 7946.
  Map<String, dynamic>? toGeoJsonFeature({Map<String, dynamic>? properties}) {
    if (coordinates == null) return null;
    final props = <String, dynamic>{
      ...?properties,
      'id': id,
      'name': name,
      'location_type': _locTo(locationType),
      if (code != null) 'code': code,
      if (platformCode != null) 'platform_code': platformCode,
      if (timezone != null) 'timezone': timezone,
      if (lines.isNotEmpty) 'lines': lines,
      if (operators.isNotEmpty) 'operators': operators,
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

  // ---------- Equality / hash ----------

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is TrainStation &&
            other.id == id &&
            other.name == name &&
            other.code == code &&
            other.coordinates == coordinates &&
            other.city == city &&
            other.country == country &&
            other.countryCode == countryCode &&
            other.timezone == timezone &&
            other.zoneId == zoneId &&
            other.locationType == locationType &&
            other.parentStation == parentStation &&
            other.platformCode == platformCode &&
            other.wheelchairBoarding == wheelchairBoarding &&
            listEquals(other.operators, operators) &&
            listEquals(other.lines, lines) &&
            other.address == address &&
            listEquals(other.amenities, amenities) &&
            mapEquals(other.metadata, metadata) &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        code,
        coordinates,
        city,
        country,
        countryCode,
        timezone,
        zoneId,
        locationType,
        parentStation,
        platformCode,
        wheelchairBoarding,
        Object.hashAll(operators),
        Object.hashAll(lines),
        address,
        Object.hashAll(amenities),
        _mapHash(metadata),
        createdAt,
        updatedAt,
      );

  static int _mapHash(Map<String, dynamic>? m) =>
      m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
