// lib/models/train.dart

import 'package:flutter/foundation.dart';
import 'booking.dart' show Money;

/// Operational status categories for trains used in schedule and realtime overlays. 
enum TrainStatus { scheduled, onTime, delayed, departed, arrived, canceled, diverted, unknown }

/// A simple coach/class taxonomy for display and fare rules.
enum CoachClass { first, second, sleeper, acFirst, acSecond, acThird, chair, executive, general, reserved }

/// GTFS-like Route subset for trains: line/number and branding info. 
@immutable
class TrainRoute {
  const TrainRoute({
    required this.id,         // route_id
    this.operatorId,          // agency_id or operator code
    this.shortName,           // route_short_name (e.g., "12034")
    this.longName,            // route_long_name (e.g., "New Delhi - Kanpur Shatabdi")
    this.desc,                // route_desc
    this.color,               // route_color hex
    this.textColor,           // route_text_color hex
    this.sortOrder,           // route_sort_order
  });

  final String id;
  final String? operatorId;
  final String? shortName;
  final String? longName;
  final String? desc;
  final String? color;
  final String? textColor;
  final int? sortOrder;

  String get displayName {
    final s = (shortName ?? '').trim();
    if (s.isNotEmpty) return s;
    final l = (longName ?? '').trim();
    if (l.isNotEmpty) return l;
    return id;
  }

  TrainRoute copyWith({
    String? id,
    String? operatorId,
    String? shortName,
    String? longName,
    String? desc,
    String? color,
    String? textColor,
    int? sortOrder,
  }) {
    return TrainRoute(
      id: id ?? this.id,
      operatorId: operatorId ?? this.operatorId,
      shortName: shortName ?? this.shortName,
      longName: longName ?? this.longName,
      desc: desc ?? this.desc,
      color: color ?? this.color,
      textColor: textColor ?? this.textColor,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory TrainRoute.fromJson(Map<String, dynamic> json) => TrainRoute(
        id: (json['id'] ?? json['route_id'] ?? '').toString(),
        operatorId: (json['operatorId'] ?? json['agency_id'] as String?)?.toString(),
        shortName: (json['shortName'] ?? json['route_short_name'] as String?)?.toString(),
        longName: (json['longName'] ?? json['route_long_name'] as String?)?.toString(),
        desc: (json['desc'] ?? json['route_desc'] as String?)?.toString(),
        color: (json['color'] ?? json['route_color'] as String?)?.toString(),
        textColor: (json['textColor'] ?? json['route_text_color'] as String?)?.toString(),
        sortOrder: (json['sortOrder'] ?? json['route_sort_order'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        if (operatorId != null) 'operatorId': operatorId,
        if (shortName != null) 'shortName': shortName,
        if (longName != null) 'longName': longName,
        if (desc != null) 'desc': desc,
        if (color != null) 'color': color,
        if (textColor != null) 'textColor': textColor,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

  @override
  bool operator ==(Object other) =>
      other is TrainRoute &&
      other.id == id &&
      other.operatorId == operatorId &&
      other.shortName == shortName &&
      other.longName == longName &&
      other.desc == desc &&
      other.color == color &&
      other.textColor == textColor &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, operatorId, shortName, longName, desc, color, textColor, sortOrder);
}

/// A stop event on the trip timeline (from GTFS stop_times semantics with HH:MM:SS local strings).
@immutable
class TrainStopTime {
  const TrainStopTime({
    required this.stationId,   // stop_id (station/platform)
    required this.sequence,    // stop_sequence
    this.arrivalTime,          // 'HH:MM:SS' local service time
    this.departureTime,        // 'HH:MM:SS' local service time
    this.platformCode,         // platform identifier
    this.headsignOverride,     // stop_headsign if used
    this.pickupType,           // pickup_type 0..3
    this.dropOffType,          // drop_off_type 0..3
    this.shapeDistTraveled,    // shape_dist_traveled
  });

  final String stationId;
  final int sequence;
  final String? arrivalTime;
  final String? departureTime;
  final String? platformCode;
  final String? headsignOverride;
  final String? pickupType;
  final String? dropOffType;
  final double? shapeDistTraveled;

  TrainStopTime copyWith({
    String? stationId,
    int? sequence,
    String? arrivalTime,
    String? departureTime,
    String? platformCode,
    String? headsignOverride,
    String? pickupType,
    String? dropOffType,
    double? shapeDistTraveled,
  }) {
    return TrainStopTime(
      stationId: stationId ?? this.stationId,
      sequence: sequence ?? this.sequence,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureTime: departureTime ?? this.departureTime,
      platformCode: platformCode ?? this.platformCode,
      headsignOverride: headsignOverride ?? this.headsignOverride,
      pickupType: pickupType ?? this.pickupType,
      dropOffType: dropOffType ?? this.dropOffType,
      shapeDistTraveled: shapeDistTraveled ?? this.shapeDistTraveled,
    );
  }

  factory TrainStopTime.fromJson(Map<String, dynamic> json) => TrainStopTime(
        stationId: (json['stationId'] ?? json['stop_id'] ?? '').toString(),
        sequence: (json['sequence'] ?? json['stop_sequence'] as num).toInt(),
        arrivalTime: (json['arrivalTime'] ?? json['arrival_time'] as String?)?.toString(),
        departureTime: (json['departureTime'] ?? json['departure_time'] as String?)?.toString(),
        platformCode: (json['platformCode'] as String?)?.toString(),
        headsignOverride: (json['headsignOverride'] ?? json['stop_headsign'] as String?)?.toString(),
        pickupType: (json['pickupType'] ?? json['pickup_type'] as String?)?.toString(),
        dropOffType: (json['dropOffType'] ?? json['drop_off_type'] as String?)?.toString(),
        shapeDistTraveled: (json['shapeDistTraveled'] ?? json['shape_dist_traveled'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'stationId': stationId,
        'sequence': sequence,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        if (departureTime != null) 'departureTime': departureTime,
        if (platformCode != null) 'platformCode': platformCode,
        if (headsignOverride != null) 'headsignOverride': headsignOverride,
        if (pickupType != null) 'pickupType': pickupType,
        if (dropOffType != null) 'dropOffType': dropOffType,
        if (shapeDistTraveled != null) 'shapeDistTraveled': shapeDistTraveled,
      };

  @override
  bool operator ==(Object other) =>
      other is TrainStopTime &&
      other.stationId == stationId &&
      other.sequence == sequence &&
      other.arrivalTime == arrivalTime &&
      other.departureTime == departureTime &&
      other.platformCode == platformCode &&
      other.headsignOverride == headsignOverride &&
      other.pickupType == pickupType &&
      other.dropOffType == dropOffType &&
      other.shapeDistTraveled == shapeDistTraveled;

  @override
  int get hashCode => Object.hash(
        stationId,
        sequence,
        arrivalTime,
        departureTime,
        platformCode,
        headsignOverride,
        pickupType,
        dropOffType,
        shapeDistTraveled,
      );
}

/// Trip-level object (akin to GTFS trips.txt plus convenience fields). 
@immutable
class TrainTrip {
  const TrainTrip({
    required this.id,          // trip_id
    required this.routeId,     // route_id
    this.serviceDate,          // yyyy-MM-dd local service date
    this.headsign,             // trip_headsign
    this.directionId,          // 0/1 if used
    this.blockId,              // block_id
    this.shapeId,              // shape_id
    this.coachClass,           // coach/class
    this.stopTimes = const <TrainStopTime>[],
  });

  final String id;
  final String routeId;
  final String? serviceDate;
  final String? headsign;
  final int? directionId;
  final String? blockId;
  final String? shapeId;
  final CoachClass? coachClass;
  final List<TrainStopTime> stopTimes;

  String? get originStationId => stopTimes.isEmpty ? null : stopTimes.first.stationId;
  String? get destinationStationId => stopTimes.isEmpty ? null : stopTimes.last.stationId;

  TrainTrip copyWith({
    String? id,
    String? routeId,
    String? serviceDate,
    String? headsign,
    int? directionId,
    String? blockId,
    String? shapeId,
    CoachClass? coachClass,
    List<TrainStopTime>? stopTimes,
  }) {
    return TrainTrip(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      serviceDate: serviceDate ?? this.serviceDate,
      headsign: headsign ?? this.headsign,
      directionId: directionId ?? this.directionId,
      blockId: blockId ?? this.blockId,
      shapeId: shapeId ?? this.shapeId,
      coachClass: coachClass ?? this.coachClass,
      stopTimes: stopTimes ?? this.stopTimes,
    );
  }

  factory TrainTrip.fromJson(Map<String, dynamic> json) {
    CoachClass? parseClass(Object? v) {
      if (v == null) return null;
      final s = v.toString();
      try {
        return CoachClass.values.byName(s);
      } catch (_) {
        switch (s.toLowerCase()) {
          case 'ac_first':
          case 'ac1':
            return CoachClass.acFirst;
          case 'ac_second':
          case 'ac2':
            return CoachClass.acSecond;
          case 'ac_third':
          case 'ac3':
            return CoachClass.acThird;
          case 'chair':
          case 'cc':
            return CoachClass.chair;
          default:
            return null;
        }
      }
    }

    final rawStops = (json['stopTimes'] ?? json['stop_times'] as List?) ?? const <dynamic>[];
    return TrainTrip(
      id: (json['id'] ?? json['trip_id'] ?? '').toString(),
      routeId: (json['routeId'] ?? json['route_id'] ?? '').toString(),
      serviceDate: (json['serviceDate'] as String?)?.toString(),
      headsign: (json['headsign'] ?? json['trip_headsign'] as String?)?.toString(),
      directionId: (json['directionId'] ?? json['direction_id'] as num?)?.toInt(),
      blockId: (json['blockId'] ?? json['block_id'] as String?)?.toString(),
      shapeId: (json['shapeId'] ?? json['shape_id'] as String?)?.toString(),
      coachClass: parseClass(json['coachClass']),
      stopTimes: rawStops.whereType<Map<String, dynamic>>().map(TrainStopTime.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'routeId': routeId,
        if (serviceDate != null) 'serviceDate': serviceDate,
        if (headsign != null) 'headsign': headsign,
        if (directionId != null) 'directionId': directionId,
        if (blockId != null) 'blockId': blockId,
        if (shapeId != null) 'shapeId': shapeId,
        if (coachClass != null) 'coachClass': coachClass!.name,
        'stopTimes': stopTimes.map((s) => s.toJson()).toList(growable: false),
      };

  @override
  bool operator ==(Object other) =>
      other is TrainTrip &&
      other.id == id &&
      other.routeId == routeId &&
      other.serviceDate == serviceDate &&
      other.headsign == headsign &&
      other.directionId == directionId &&
      other.blockId == blockId &&
      other.shapeId == shapeId &&
      other.coachClass == coachClass &&
      listEquals(other.stopTimes, stopTimes);

  @override
  int get hashCode => Object.hash(id, routeId, serviceDate, headsign, directionId, blockId, shapeId, coachClass, Object.hashAll(stopTimes));
}

/// Root Train record composing route + trip + optional realtime/vehicle/fare fields for listings and detail views. 
@immutable
class Train {
  const Train({
    required this.id,           // stable ID for this trip instance (trip_id or trip_id+serviceDate)
    required this.route,
    required this.trip,
    this.operatorName,          // brand/operator for UI
    this.status = TrainStatus.scheduled,
    this.updatedAt,             // realtime timestamp
    this.fare,                  // optional fare summary
    this.currency,              // ISO code if fare is split elsewhere
    this.metadata,
  });

  final String id;
  final TrainRoute route;
  final TrainTrip trip;

  final String? operatorName;
  final TrainStatus status;
  final DateTime? updatedAt;

  final Money? fare;
  final String? currency;

  final Map<String, dynamic>? metadata;

  String get title {
    final head = (trip.headsign ?? '').trim();
    if (head.isNotEmpty) return '${route.displayName} • $head';
    final dest = trip.destinationStationId ?? '';
    if (dest.isNotEmpty) return '${route.displayName} • $dest';
    return route.displayName;
  }

  int get stops => trip.stopTimes.isEmpty ? 0 : (trip.stopTimes.length - 1);

  Train copyWith({
    String? id,
    TrainRoute? route,
    TrainTrip? trip,
    String? operatorName,
    TrainStatus? status,
    DateTime? updatedAt,
    Money? fare,
    String? currency,
    Map<String, dynamic>? metadata,
  }) {
    return Train(
      id: id ?? this.id,
      route: route ?? this.route,
      trip: trip ?? this.trip,
      operatorName: operatorName ?? this.operatorName,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      fare: fare ?? this.fare,
      currency: currency ?? this.currency,
      metadata: metadata ?? this.metadata,
    );
  }

  factory Train.fromJson(Map<String, dynamic> json) {
    TrainStatus parseStatus(Object? v) {
      final s = (v ?? 'scheduled').toString().toLowerCase();
      switch (s) {
        case 'on time':
        case 'on_time':
        case 'on-time':
        case 'ontime':
          return TrainStatus.onTime;
        case 'delayed':
          return TrainStatus.delayed;
        case 'departed':
          return TrainStatus.departed;
        case 'arrived':
          return TrainStatus.arrived;
        case 'canceled':
        case 'cancelled':
          return TrainStatus.canceled;
        case 'diverted':
          return TrainStatus.diverted;
        case 'scheduled':
          return TrainStatus.scheduled;
        default:
          return TrainStatus.unknown;
      }
    }

    return Train(
      id: (json['id'] ?? '').toString(),
      route: TrainRoute.fromJson((json['route'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      trip: TrainTrip.fromJson((json['trip'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      operatorName: (json['operatorName'] as String?)?.toString(),
      status: parseStatus(json['status']),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      fare: json['fare'] != null ? Money.fromJson((json['fare'] as Map).cast<String, dynamic>()) : null,
      currency: (json['currency'] as String?)?.toUpperCase(),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'route': route.toJson(),
        'trip': trip.toJson(),
        if (operatorName != null) 'operatorName': operatorName,
        'status': status.name,
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (fare != null) 'fare': fare!.toJson(),
        if (currency != null) 'currency': currency,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is Train &&
      other.id == id &&
      other.route == route &&
      other.trip == trip &&
      other.operatorName == operatorName &&
      other.status == status &&
      other.updatedAt == updatedAt &&
      other.fare == fare &&
      other.currency == currency &&
      mapEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(id, route, trip, operatorName, status, updatedAt, fare, currency, _mapHash(metadata));

  int _mapHash(Map<String, dynamic>? m) =>
      m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
