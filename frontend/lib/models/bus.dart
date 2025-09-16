// lib/models/bus.dart

import 'package:flutter/foundation.dart';

/// GTFS route_type subset relevant to bus-oriented data (3 = Bus, 11 = Trolleybus). [GTFS routes.txt] 
/// This enum is carried on BusRoute for clarity and UI badges. [1]
enum BusRouteType { bus, trolleybus }

/// Realtime running status for a scheduled bus trip. Integrates well with GTFS-rt concepts. [13][16]
enum BusRealtimeStatus { scheduled, inProgress, delayed, arrived, canceled, skipped, unknown }

/// Minimal fare wrapper for a bus itinerary (minor units + ISO currency). [21]
@immutable
class BusFare {
  const BusFare({required this.currency, required this.amountMinor});

  final String currency; // ISO 4217 (e.g., INR, USD)
  final int amountMinor; // minor units (e.g., paise/cents)

  double get amount => amountMinor / 100.0;

  BusFare copyWith({String? currency, int? amountMinor}) =>
      BusFare(currency: currency ?? this.currency, amountMinor: amountMinor ?? this.amountMinor);

  factory BusFare.fromJson(Map<String, dynamic> json) => BusFare(
        currency: (json['currency'] ?? '').toString(),
        amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'currency': currency,
        'amountMinor': amountMinor,
      };

  @override
  bool operator ==(Object other) => other is BusFare && other.currency == currency && other.amountMinor == amountMinor;

  @override
  int get hashCode => Object.hash(currency, amountMinor);
}

/// GTFS-like Route subset used for bus UI: short/long name + colors for chips and maps. [1][6]
@immutable
class BusRoute {
  const BusRoute({
    required this.id, // route_id
    this.agencyId, // agency_id
    this.shortName, // route_short_name (e.g., 32)
    this.longName, // route_long_name (e.g., Downtown – Airport)
    this.desc, // route_desc
    this.type = BusRouteType.bus, // route_type (3 or 11)
    this.url, // route_url
    this.color, // route_color hex (e.g., 00A65A)
    this.textColor, // route_text_color
    this.sortOrder, // route_sort_order
  });

  final String id;
  final String? agencyId;
  final String? shortName;
  final String? longName;
  final String? desc;
  final BusRouteType type;
  final String? url;
  final String? color;
  final String? textColor;
  final int? sortOrder;

  /// Prefer shortName if present, else longName, else id — for chips and list rows. [6]
  String get displayName {
    final s = (shortName ?? '').trim();
    if (s.isNotEmpty) return s;
    final l = (longName ?? '').trim();
    if (l.isNotEmpty) return l;
    return id;
  }

  BusRoute copyWith({
    String? id,
    String? agencyId,
    String? shortName,
    String? longName,
    String? desc,
    BusRouteType? type,
    String? url,
    String? color,
    String? textColor,
    int? sortOrder,
  }) {
    return BusRoute(
      id: id ?? this.id,
      agencyId: agencyId ?? this.agencyId,
      shortName: shortName ?? this.shortName,
      longName: longName ?? this.longName,
      desc: desc ?? this.desc,
      type: type ?? this.type,
      url: url ?? this.url,
      color: color ?? this.color,
      textColor: textColor ?? this.textColor,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    final tRaw = (json['type'] ?? json['route_type'] ?? 'bus').toString();
    BusRouteType t;
    switch (tRaw) {
      case '3':
      case 'bus':
        t = BusRouteType.bus;
        break;
      case '11':
      case 'trolleybus':
        t = BusRouteType.trolleybus;
        break;
      default:
        t = BusRouteType.bus;
    }

    return BusRoute(
      id: (json['id'] ?? json['route_id'] ?? '').toString(),
      agencyId: (json['agencyId'] ?? json['agency_id'] as String?)?.toString(),
      shortName: (json['shortName'] ?? json['route_short_name'] as String?)?.toString(),
      longName: (json['longName'] ?? json['route_long_name'] as String?)?.toString(),
      desc: (json['desc'] ?? json['route_desc'] as String?)?.toString(),
      type: t,
      url: (json['url'] ?? json['route_url'] as String?)?.toString(),
      color: (json['color'] ?? json['route_color'] as String?)?.toString(),
      textColor: (json['textColor'] ?? json['route_text_color'] as String?)?.toString(),
      sortOrder: (json['sortOrder'] ?? json['route_sort_order'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        if (agencyId != null) 'agencyId': agencyId,
        if (shortName != null) 'shortName': shortName,
        if (longName != null) 'longName': longName,
        if (desc != null) 'desc': desc,
        'type': type == BusRouteType.bus ? 'bus' : 'trolleybus',
        if (url != null) 'url': url,
        if (color != null) 'color': color,
        if (textColor != null) 'textColor': textColor,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

  @override
  bool operator ==(Object other) =>
      other is BusRoute &&
      other.id == id &&
      other.agencyId == agencyId &&
      other.shortName == shortName &&
      other.longName == longName &&
      other.desc == desc &&
      other.type == type &&
      other.url == url &&
      other.color == color &&
      other.textColor == textColor &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, agencyId, shortName, longName, desc, type, url, color, textColor, sortOrder);
}

/// A single scheduled stop event of a trip (from stop_times.txt semantics). [4]
@immutable
class BusStopTime {
  const BusStopTime({
    required this.stopId, // stop_id
    required this.sequence, // stop_sequence
    this.arrivalTime, // 'HH:MM:SS' local string (GTFS-style)
    this.departureTime, // 'HH:MM:SS' local string (GTFS-style)
    this.headsignOverride, // stop_headsign
    this.pickupType, // pickup_type (0..3 string)
    this.dropOffType, // drop_off_type (0..3 string)
    this.shapeDistTraveled, // shape_dist_traveled
  });

  final String stopId;
  final int sequence;
  final String? arrivalTime;
  final String? departureTime;
  final String? headsignOverride;
  final String? pickupType;
  final String? dropOffType;
  final double? shapeDistTraveled;

  BusStopTime copyWith({
    String? stopId,
    int? sequence,
    String? arrivalTime,
    String? departureTime,
    String? headsignOverride,
    String? pickupType,
    String? dropOffType,
    double? shapeDistTraveled,
  }) {
    return BusStopTime(
      stopId: stopId ?? this.stopId,
      sequence: sequence ?? this.sequence,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureTime: departureTime ?? this.departureTime,
      headsignOverride: headsignOverride ?? this.headsignOverride,
      pickupType: pickupType ?? this.pickupType,
      dropOffType: dropOffType ?? this.dropOffType,
      shapeDistTraveled: shapeDistTraveled ?? this.shapeDistTraveled,
    );
  }

  factory BusStopTime.fromJson(Map<String, dynamic> json) => BusStopTime(
        stopId: (json['stopId'] ?? json['stop_id'] ?? '').toString(),
        sequence: (json['sequence'] ?? json['stop_sequence'] as num).toInt(),
        arrivalTime: (json['arrivalTime'] ?? json['arrival_time'] as String?)?.toString(),
        departureTime: (json['departureTime'] ?? json['departure_time'] as String?)?.toString(),
        headsignOverride: (json['headsignOverride'] ?? json['stop_headsign'] as String?)?.toString(),
        pickupType: (json['pickupType'] ?? json['pickup_type'] as String?)?.toString(),
        dropOffType: (json['dropOffType'] ?? json['drop_off_type'] as String?)?.toString(),
        shapeDistTraveled: (json['shapeDistTraveled'] ?? json['shape_dist_traveled'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'stopId': stopId,
        'sequence': sequence,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        if (departureTime != null) 'departureTime': departureTime,
        if (headsignOverride != null) 'headsignOverride': headsignOverride,
        if (pickupType != null) 'pickupType': pickupType,
        if (dropOffType != null) 'dropOffType': dropOffType,
        if (shapeDistTraveled != null) 'shapeDistTraveled': shapeDistTraveled,
      };

  @override
  bool operator ==(Object other) =>
      other is BusStopTime &&
      other.stopId == stopId &&
      other.sequence == sequence &&
      other.arrivalTime == arrivalTime &&
      other.departureTime == departureTime &&
      other.headsignOverride == headsignOverride &&
      other.pickupType == pickupType &&
      other.dropOffType == dropOffType &&
      other.shapeDistTraveled == shapeDistTraveled;

  @override
  int get hashCode => Object.hash(stopId, sequence, arrivalTime, departureTime, headsignOverride, pickupType, dropOffType, shapeDistTraveled);
}

/// Trip-level fields (from trips.txt semantics, plus a few convenience properties for UI). [1][3]
@immutable
class BusTrip {
  const BusTrip({
    required this.id, // trip_id
    required this.routeId, // route_id
    this.serviceDate, // service day (yyyy-MM-dd local)
    this.headsign, // trip_headsign
    this.directionId, // 0/1 if used
    this.blockId, // block_id
    this.shapeId, // shape_id
    this.stopTimes = const <BusStopTime>[], // ordered stops
  });

  final String id;
  final String routeId;
  final String? serviceDate;
  final String? headsign;
  final int? directionId;
  final String? blockId;
  final String? shapeId;
  final List<BusStopTime> stopTimes;

  /// First and last stop convenience for cards.
  String? get firstStopId => stopTimes.isEmpty ? null : stopTimes.first.stopId;
  String? get lastStopId => stopTimes.isEmpty ? null : stopTimes.last.stopId;

  BusTrip copyWith({
    String? id,
    String? routeId,
    String? serviceDate,
    String? headsign,
    int? directionId,
    String? blockId,
    String? shapeId,
    List<BusStopTime>? stopTimes,
  }) {
    return BusTrip(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      serviceDate: serviceDate ?? this.serviceDate,
      headsign: headsign ?? this.headsign,
      directionId: directionId ?? this.directionId,
      blockId: blockId ?? this.blockId,
      shapeId: shapeId ?? this.shapeId,
      stopTimes: stopTimes ?? this.stopTimes,
    );
  }

  factory BusTrip.fromJson(Map<String, dynamic> json) {
    final rawStops = (json['stopTimes'] ?? json['stop_times'] as List?) ?? const <dynamic>[];
    return BusTrip(
      id: (json['id'] ?? json['trip_id'] ?? '').toString(),
      routeId: (json['routeId'] ?? json['route_id'] ?? '').toString(),
      serviceDate: (json['serviceDate'] as String?)?.toString(),
      headsign: (json['headsign'] ?? json['trip_headsign'] as String?)?.toString(),
      directionId: (json['directionId'] ?? json['direction_id'] as num?)?.toInt(),
      blockId: (json['blockId'] ?? json['block_id'] as String?)?.toString(),
      shapeId: (json['shapeId'] ?? json['shape_id'] as String?)?.toString(),
      stopTimes: rawStops.whereType<Map<String, dynamic>>().map(BusStopTime.fromJson).toList(growable: false),
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
        'stopTimes': stopTimes.map((e) => e.toJson()).toList(growable: false),
      };

  @override
  bool operator ==(Object other) =>
      other is BusTrip &&
      other.id == id &&
      other.routeId == routeId &&
      other.serviceDate == serviceDate &&
      other.headsign == headsign &&
      other.directionId == directionId &&
      other.blockId == blockId &&
      other.shapeId == shapeId &&
      listEquals(other.stopTimes, stopTimes);

  @override
  int get hashCode => Object.hash(id, routeId, serviceDate, headsign, directionId, blockId, shapeId, Object.hashAll(stopTimes));
}

/// Vehicle metadata that can appear in realtime feeds or assignments. [13]
@immutable
class BusVehicle {
  const BusVehicle({
    required this.id, // vehicle_id or assignment id
    this.label, // user-visible label or fleet number
    this.licensePlate,
    this.capacity, // pax capacity if known
    this.wheelchairAccessible, // vehicle-level accessibility
  });

  final String id;
  final String? label;
  final String? licensePlate;
  final int? capacity;
  final bool? wheelchairAccessible;

  BusVehicle copyWith({
    String? id,
    String? label,
    String? licensePlate,
    int? capacity,
    bool? wheelchairAccessible,
  }) {
    return BusVehicle(
      id: id ?? this.id,
      label: label ?? this.label,
      licensePlate: licensePlate ?? this.licensePlate,
      capacity: capacity ?? this.capacity,
      wheelchairAccessible: wheelchairAccessible ?? this.wheelchairAccessible,
    );
  }

  factory BusVehicle.fromJson(Map<String, dynamic> json) => BusVehicle(
        id: (json['id'] ?? '').toString(),
        label: (json['label'] as String?)?.toString(),
        licensePlate: (json['licensePlate'] as String?)?.toString(),
        capacity: (json['capacity'] as num?)?.toInt(),
        wheelchairAccessible: (json['wheelchairAccessible'] as bool?),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        if (label != null) 'label': label,
        if (licensePlate != null) 'licensePlate': licensePlate,
        if (capacity != null) 'capacity': capacity,
        if (wheelchairAccessible != null) 'wheelchairAccessible': wheelchairAccessible,
      };

  @override
  bool operator ==(Object other) =>
      other is BusVehicle &&
      other.id == id &&
      other.label == label &&
      other.licensePlate == licensePlate &&
      other.capacity == capacity &&
      other.wheelchairAccessible == wheelchairAccessible;

  @override
  int get hashCode => Object.hash(id, label, licensePlate, capacity, wheelchairAccessible);
}

/// Root Bus record composing route + trip + optional realtime/vehicle/fare fields for listings and detail views. [3][13]
@immutable
class Bus {
  const Bus({
    required this.id, // stable ID for this trip instance (trip_id or trip_id+serviceDate)
    required this.route,
    required this.trip,
    this.operatorName, // agency brand if needed for UI
    this.status = BusRealtimeStatus.scheduled,
    this.updatedAt, // realtime timestamp
    this.vehicle,
    this.fare,
    this.metadata,
  });

  final String id;
  final BusRoute route;
  final BusTrip trip;

  final String? operatorName;
  final BusRealtimeStatus status;
  final DateTime? updatedAt;

  final BusVehicle? vehicle;
  final BusFare? fare;

  final Map<String, dynamic>? metadata;

  /// Quick display: "<Route displayName> • <Headsign or last stop>"
  String get title {
    final head = (trip.headsign ?? '').trim();
    if (head.isNotEmpty) return '${route.displayName} • $head';
    final last = trip.lastStopId ?? '';
    if (last.isNotEmpty) return '${route.displayName} • $last';
    return route.displayName;
  }

  Bus copyWith({
    String? id,
    BusRoute? route,
    BusTrip? trip,
    String? operatorName,
    BusRealtimeStatus? status,
    DateTime? updatedAt,
    BusVehicle? vehicle,
    BusFare? fare,
    Map<String, dynamic>? metadata,
  }) {
    return Bus(
      id: id ?? this.id,
      route: route ?? this.route,
      trip: trip ?? this.trip,
      operatorName: operatorName ?? this.operatorName,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      vehicle: vehicle ?? this.vehicle,
      fare: fare ?? this.fare,
      metadata: metadata ?? this.metadata,
    );
  }

  factory Bus.fromJson(Map<String, dynamic> json) {
    BusRealtimeStatus parseStatus(Object? v) {
      final s = (v ?? 'scheduled').toString();
      try {
        return BusRealtimeStatus.values.byName(s);
      } catch (_) {
        switch (s.toLowerCase()) {
          case 'in_progress':
          case 'inprogress':
            return BusRealtimeStatus.inProgress;
          case 'delayed':
            return BusRealtimeStatus.delayed;
          case 'arrived':
            return BusRealtimeStatus.arrived;
          case 'canceled':
          case 'cancelled':
            return BusRealtimeStatus.canceled;
          case 'skipped':
            return BusRealtimeStatus.skipped;
          default:
            return BusRealtimeStatus.scheduled;
        }
      }
    }

    return Bus(
      id: (json['id'] ?? '').toString(),
      route: BusRoute.fromJson((json['route'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      trip: BusTrip.fromJson((json['trip'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      operatorName: (json['operatorName'] as String?)?.toString(),
      status: parseStatus(json['status']),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      vehicle: json['vehicle'] != null ? BusVehicle.fromJson((json['vehicle'] as Map).cast<String, dynamic>()) : null,
      fare: json['fare'] != null ? BusFare.fromJson((json['fare'] as Map).cast<String, dynamic>()) : null,
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
        if (vehicle != null) 'vehicle': vehicle!.toJson(),
        if (fare != null) 'fare': fare!.toJson(),
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is Bus &&
      other.id == id &&
      other.route == route &&
      other.trip == trip &&
      other.operatorName == operatorName &&
      other.status == status &&
      other.updatedAt == updatedAt &&
      other.vehicle == vehicle &&
      other.fare == fare &&
      mapEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(id, route, trip, operatorName, status, updatedAt, vehicle, fare, _mapHash(metadata));

  int _mapHash(Map<String, dynamic>? m) => m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
