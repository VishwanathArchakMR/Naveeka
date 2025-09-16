// lib/models/bus_stop.dart

import 'package:flutter/foundation.dart';

/// GTFS location_type values for stops.txt. [0 Stop/Platform, 1 Station, 2 Entrance/Exit, 3 Generic Node, 4 Boarding Area] [3]
enum StopLocationType {
  stop, // 0 or empty
  station, // 1
  entranceExit, // 2
  genericNode, // 3
  boardingArea, // 4
}

/// GTFS wheelchair_boarding semantics for stops/stations/entrances; values mirror GTFS numeric meanings 0/1/2. [3]
enum WheelchairBoarding {
  unknownOrInherit, // 0 or empty
  accessible, // 1
  notAccessible, // 2
}

@immutable
class BusStop {
  const BusStop({
    required this.id, // stop_id
    required this.name, // stop_name
    this.code, // stop_code
    this.desc, // stop_desc
    this.lat, // stop_lat
    this.lon, // stop_lon
    this.zoneId, // zone_id
    this.url, // stop_url
    this.locationType = StopLocationType.stop, // location_type
    this.parentStation, // parent_station
    this.timezone, // stop_timezone (IANA)
    this.wheelchairBoarding = WheelchairBoarding.unknownOrInherit, // wheelchair_boarding
    this.levelId, // level_id
    this.platformCode, // platform_code
    this.metadata, // extra data
  });

  /// stop_id (unique) [3]
  final String id;

  /// stop_name (rider-facing) [3]
  final String name;

  /// stop_code (short rider-facing code, often printed on signage) [3]
  final String? code;

  /// stop_desc (optional extra description) [3]
  final String? desc;

  /// stop_lat (latitude) [3]
  final double? lat;

  /// stop_lon (longitude) [3]
  final double? lon;

  /// zone_id (fare zone) [3]
  final String? zoneId;

  /// stop_url (web page for the location) [3]
  final String? url;

  /// location_type (0 stop/platform, 1 station, 2 entrance/exit, 3 node, 4 boarding area) [3]
  final StopLocationType locationType;

  /// parent_station (hierarchy link) [3]
  final String? parentStation;

  /// stop_timezone (IANA TZ like "Asia/Kolkata") [3]
  final String? timezone;

  /// wheelchair_boarding (0 unknown/inherit, 1 accessible, 2 not accessible) [3]
  final WheelchairBoarding wheelchairBoarding;

  /// level_id (for multi-level stations) [3]
  final String? levelId;

  /// platform_code (platform identifier like "3" or "G") [3]
  final String? platformCode;

  /// Free-form extra attributes from server/feeds.
  final Map<String, dynamic>? metadata;

  // ---------- Derived helpers ----------

  /// Preferred display code: stop_code if present, else stop_id. [3]
  String get displayCode => (code != null && code!.trim().isNotEmpty) ? code!.trim() : id; // [3]

  /// "CODE — Name" for compact list items. [3]
  String get codeTitle => '$displayCode — $name'; // [3]

  bool get hasCoordinates => lat != null && lon != null; // [3]

  // ---------- Copy ----------

  BusStop copyWith({
    String? id,
    String? name,
    String? code,
    String? desc,
    double? lat,
    double? lon,
    String? zoneId,
    String? url,
    StopLocationType? locationType,
    String? parentStation,
    String? timezone,
    WheelchairBoarding? wheelchairBoarding,
    String? levelId,
    String? platformCode,
    Map<String, dynamic>? metadata,
  }) {
    return BusStop(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      desc: desc ?? this.desc,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      zoneId: zoneId ?? this.zoneId,
      url: url ?? this.url,
      locationType: locationType ?? this.locationType,
      parentStation: parentStation ?? this.parentStation,
      timezone: timezone ?? this.timezone,
      wheelchairBoarding: wheelchairBoarding ?? this.wheelchairBoarding,
      levelId: levelId ?? this.levelId,
      platformCode: platformCode ?? this.platformCode,
      metadata: metadata ?? this.metadata,
    );
  }

  // ---------- JSON ----------

  static double? _toD(Object? x) {
    if (x == null) return null;
    if (x is num) return x.toDouble();
    final s = x.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  } // [9]

  static StopLocationType _locFrom(Object? x) {
    final raw = (x ?? '').toString().trim();
    // GTFS allows empty or 0 for stop/platform
    if (raw.isEmpty || raw == '0') return StopLocationType.stop;
    switch (raw) {
      case '1':
        return StopLocationType.station;
      case '2':
        return StopLocationType.entranceExit;
      case '3':
        return StopLocationType.genericNode;
      case '4':
        return StopLocationType.boardingArea;
      default:
        // also support enum byName if servers send strings
        try {
          return StopLocationType.values.byName(raw);
        } catch (_) {
          return StopLocationType.stop;
        }
    }
  } // [3]

  static String _locTo(StopLocationType t) {
    switch (t) {
      case StopLocationType.stop:
        return '0';
      case StopLocationType.station:
        return '1';
      case StopLocationType.entranceExit:
        return '2';
      case StopLocationType.genericNode:
        return '3';
      case StopLocationType.boardingArea:
        return '4';
    }
  } // [3]

  static WheelchairBoarding _wcFrom(Object? x) {
    final raw = (x ?? '').toString().trim();
    if (raw.isEmpty || raw == '0') return WheelchairBoarding.unknownOrInherit;
    if (raw == '1') return WheelchairBoarding.accessible;
    if (raw == '2') return WheelchairBoarding.notAccessible;
    // also permit enum byName if strings provided
    try {
      return WheelchairBoarding.values.byName(raw);
    } catch (_) {
      return WheelchairBoarding.unknownOrInherit;
    }
  } // [3][7]

  static String _wcTo(WheelchairBoarding w) {
    switch (w) {
      case WheelchairBoarding.unknownOrInherit:
        return '0';
      case WheelchairBoarding.accessible:
        return '1';
      case WheelchairBoarding.notAccessible:
        return '2';
    }
  } // [3]

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: (json['stop_id'] ?? json['id'] ?? '').toString(),
      name: (json['stop_name'] ?? json['name'] ?? '').toString(),
      code: (json['stop_code'] ?? json['code'] as String?)?.toString(),
      desc: (json['stop_desc'] ?? json['desc'] as String?)?.toString(),
      lat: _toD(json['stop_lat'] ?? json['lat']),
      lon: _toD(json['stop_lon'] ?? json['lon']),
      zoneId: (json['zone_id'] as String?)?.toString(),
      url: (json['stop_url'] as String?)?.toString(),
      locationType: _locFrom(json['location_type']),
      parentStation: (json['parent_station'] as String?)?.toString(),
      timezone: (json['stop_timezone'] as String?)?.toString(),
      wheelchairBoarding: _wcFrom(json['wheelchair_boarding']),
      levelId: (json['level_id'] as String?)?.toString(),
      platformCode: (json['platform_code'] as String?)?.toString(),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  } // [3][9]

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'stop_id': id,
      'stop_name': name,
      if (code != null) 'stop_code': code,
      if (desc != null) 'stop_desc': desc,
      if (lat != null) 'stop_lat': lat,
      if (lon != null) 'stop_lon': lon,
      if (zoneId != null) 'zone_id': zoneId,
      if (url != null) 'stop_url': url,
      'location_type': _locTo(locationType),
      if (parentStation != null) 'parent_station': parentStation,
      if (timezone != null) 'stop_timezone': timezone,
      'wheelchair_boarding': _wcTo(wheelchairBoarding),
      if (levelId != null) 'level_id': levelId,
      if (platformCode != null) 'platform_code': platformCode,
      if (metadata != null) 'metadata': metadata,
    };
  } // [3][9]

  // ---------- Equality / hash / debug ----------

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is BusStop &&
            other.id == id &&
            other.name == name &&
            other.code == code &&
            other.desc == desc &&
            other.lat == lat &&
            other.lon == lon &&
            other.zoneId == zoneId &&
            other.url == url &&
            other.locationType == locationType &&
            other.parentStation == parentStation &&
            other.timezone == timezone &&
            other.wheelchairBoarding == wheelchairBoarding &&
            other.levelId == levelId &&
            other.platformCode == platformCode &&
            mapEquals(other.metadata, metadata));
  } // [9]

  @override
  int get hashCode => Object.hash(
        id,
        name,
        code,
        desc,
        lat,
        lon,
        zoneId,
        url,
        locationType,
        parentStation,
        timezone,
        wheelchairBoarding,
        levelId,
        platformCode,
        _mapHash(metadata),
      ); // [9]

  int _mapHash(Map<String, dynamic>? m) {
    if (m == null) return 0;
    return Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
  } // [9]

  @override
  String toString() => 'BusStop($codeTitle @ $lat,$lon)'; // [3]
}
