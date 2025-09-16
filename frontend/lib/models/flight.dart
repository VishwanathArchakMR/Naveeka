// lib/models/flight.dart

import 'package:flutter/foundation.dart';
import 'booking.dart' show Money;

/// Cabin classes commonly used by airlines and UIs. [Economy, Premium Economy, Business, First]
/// This aligns with widespread product naming across carriers. [6][20]
enum CabinClass { economy, premiumEconomy, business, first }

/// Operational status categories for flights used in apps and airline status pages. [7][10]
enum FlightStatus {
  scheduled,
  onTime,
  delayed,
  departed,
  arrived,
  canceled,
  diverted,
  unknown,
}

/// Baggage concepts per IATA: piece (N×limit per piece) or weight (total kg). [2][1]
@immutable
class BaggageAllowance {
  const BaggageAllowance({
    this.pieces,
    this.maxWeightPerPieceKg,
    this.totalWeightKg,
    this.carryOnKg,
    this.carryOnPieces,
    this.notes,
  });

  /// Number of checked pieces allowed when the piece concept applies. [2][4]
  final int? pieces;

  /// Max weight per checked piece in kilograms for the piece concept. [1][11]
  final double? maxWeightPerPieceKg;

  /// Total checked baggage weight allowed when the weight concept applies. [2][14]
  final double? totalWeightKg;

  /// Carry-on weight allowance if specified. [17][8]
  final double? carryOnKg;

  /// Carry-on piece count if specified. [17][8]
  final int? carryOnPieces;

  /// Free-form notes for special cases or elite tiers. [2]
  final String? notes;

  BaggageAllowance copyWith({
    int? pieces,
    double? maxWeightPerPieceKg,
    double? totalWeightKg,
    double? carryOnKg,
    int? carryOnPieces,
    String? notes,
  }) {
    return BaggageAllowance(
      pieces: pieces ?? this.pieces,
      maxWeightPerPieceKg: maxWeightPerPieceKg ?? this.maxWeightPerPieceKg,
      totalWeightKg: totalWeightKg ?? this.totalWeightKg,
      carryOnKg: carryOnKg ?? this.carryOnKg,
      carryOnPieces: carryOnPieces ?? this.carryOnPieces,
      notes: notes ?? this.notes,
    );
  }

  factory BaggageAllowance.fromJson(Map<String, dynamic> json) => BaggageAllowance(
        pieces: (json['pieces'] as num?)?.toInt(),
        maxWeightPerPieceKg: (json['maxWeightPerPieceKg'] as num?)?.toDouble(),
        totalWeightKg: (json['totalWeightKg'] as num?)?.toDouble(),
        carryOnKg: (json['carryOnKg'] as num?)?.toDouble(),
        carryOnPieces: (json['carryOnPieces'] as num?)?.toInt(),
        notes: (json['notes'] as String?)?.toString(),
      ); // [2][1]

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (pieces != null) 'pieces': pieces,
        if (maxWeightPerPieceKg != null) 'maxWeightPerPieceKg': maxWeightPerPieceKg,
        if (totalWeightKg != null) 'totalWeightKg': totalWeightKg,
        if (carryOnKg != null) 'carryOnKg': carryOnKg,
        if (carryOnPieces != null) 'carryOnPieces': carryOnPieces,
        if (notes != null) 'notes': notes,
      }; // [2][21]

  @override
  bool operator ==(Object other) =>
      other is BaggageAllowance &&
      other.pieces == pieces &&
      other.maxWeightPerPieceKg == maxWeightPerPieceKg &&
      other.totalWeightKg == totalWeightKg &&
      other.carryOnKg == carryOnKg &&
      other.carryOnPieces == carryOnPieces &&
      other.notes == notes; // [21]

  @override
  int get hashCode => Object.hash(pieces, maxWeightPerPieceKg, totalWeightKg, carryOnKg, carryOnPieces, notes); // [21]
}

/// Marketing/operating carrier info for code-share clarity and branding. [6]
@immutable
class AirlineCarrier {
  const AirlineCarrier({
    required this.code, // IATA two-letter preferred (e.g., AI)
    this.name,
    this.icao, // four-letter if available (e.g., AIC)
  });

  final String code;
  final String? name;
  final String? icao;

  AirlineCarrier copyWith({String? code, String? name, String? icao}) =>
      AirlineCarrier(code: code ?? this.code, name: name ?? this.name, icao: icao ?? this.icao); // [22][23]

  factory AirlineCarrier.fromJson(Map<String, dynamic> json) => AirlineCarrier(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] as String?)?.toString(),
        icao: (json['icao'] as String?)?.toString(),
      ); // [22][23]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        if (name != null) 'name': name,
        if (icao != null) 'icao': icao,
      }; // [21]

  @override
  bool operator ==(Object other) => other is AirlineCarrier && other.code == code && other.name == name && other.icao == icao; // [21]

  @override
  int get hashCode => Object.hash(code, name, icao); // [21]
}

/// A single flight leg/segment (akin to a row in an e-ticket or an entry in trips). [21]
@immutable
class FlightSegment {
  const FlightSegment({
    required this.marketingCarrier,
    required this.operatingCarrier,
    required this.flightNumber, // numeric string without carrier code
    required this.departureAirport, // IATA preferred (e.g., DEL) or ICAO if needed
    required this.arrivalAirport, // IATA preferred (e.g., BOM) or ICAO if needed
    required this.departureTime, // ISO date-time with TZ/offset
    required this.arrivalTime, // ISO date-time with TZ/offset
    this.departureTerminal,
    this.arrivalTerminal,
    this.departureGate,
    this.arrivalGate,
    this.cabin = CabinClass.economy,
    this.bookingClass, // e.g., Y, J
    this.equipment, // IATA equipment code (e.g., 32N)
    this.status = FlightStatus.scheduled,
    this.baggage,
    this.recordLocator,
  });

  final AirlineCarrier marketingCarrier;
  final AirlineCarrier operatingCarrier;
  final String flightNumber;

  final String departureAirport; // airport code string per upstream API
  final String arrivalAirport; // airport code string per upstream API

  final DateTime departureTime;
  final DateTime arrivalTime;

  final String? departureTerminal;
  final String? arrivalTerminal;
  final String? departureGate;
  final String? arrivalGate;

  final CabinClass cabin;
  final String? bookingClass;
  final String? equipment;
  final FlightStatus status;

  final BaggageAllowance? baggage;
  final String? recordLocator;

  int get durationMinutes => arrivalTime.difference(departureTime).inMinutes; // [21]

  FlightSegment copyWith({
    AirlineCarrier? marketingCarrier,
    AirlineCarrier? operatingCarrier,
    String? flightNumber,
    String? departureAirport,
    String? arrivalAirport,
    DateTime? departureTime,
    DateTime? arrivalTime,
    String? departureTerminal,
    String? arrivalTerminal,
    String? departureGate,
    String? arrivalGate,
    CabinClass? cabin,
    String? bookingClass,
    String? equipment,
    FlightStatus? status,
    BaggageAllowance? baggage,
    String? recordLocator,
  }) {
    return FlightSegment(
      marketingCarrier: marketingCarrier ?? this.marketingCarrier,
      operatingCarrier: operatingCarrier ?? this.operatingCarrier,
      flightNumber: flightNumber ?? this.flightNumber,
      departureAirport: departureAirport ?? this.departureAirport,
      arrivalAirport: arrivalAirport ?? this.arrivalAirport,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureTerminal: departureTerminal ?? this.departureTerminal,
      arrivalTerminal: arrivalTerminal ?? this.arrivalTerminal,
      departureGate: departureGate ?? this.departureGate,
      arrivalGate: arrivalGate ?? this.arrivalGate,
      cabin: cabin ?? this.cabin,
      bookingClass: bookingClass ?? this.bookingClass,
      equipment: equipment ?? this.equipment,
      status: status ?? this.status,
      baggage: baggage ?? this.baggage,
      recordLocator: recordLocator ?? this.recordLocator,
    );
  }

  factory FlightSegment.fromJson(Map<String, dynamic> json) {
    CabinClass parseCabin(Object? v) {
      final s = (v ?? 'economy').toString();
      try {
        return CabinClass.values.byName(s);
      } catch (_) {
        return CabinClass.economy;
      }
    } // [6][24]

    FlightStatus parseStatus(Object? v) {
      final s = (v ?? 'scheduled').toString().toLowerCase();
      switch (s) {
        case 'ontime':
        case 'on_time':
        case 'on-time':
        case 'on time':
          return FlightStatus.onTime;
        case 'delayed':
          return FlightStatus.delayed;
        case 'departed':
          return FlightStatus.departed;
        case 'arrived':
          return FlightStatus.arrived;
        case 'canceled':
        case 'cancelled':
          return FlightStatus.canceled;
        case 'diverted':
          return FlightStatus.diverted;
        case 'scheduled':
          return FlightStatus.scheduled;
        default:
          return FlightStatus.unknown;
      }
    } // [7][10]

    return FlightSegment(
      marketingCarrier: AirlineCarrier.fromJson((json['marketingCarrier'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      operatingCarrier: AirlineCarrier.fromJson((json['operatingCarrier'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      flightNumber: (json['flightNumber'] ?? '').toString(),
      departureAirport: (json['departureAirport'] ?? '').toString(),
      arrivalAirport: (json['arrivalAirport'] ?? '').toString(),
      departureTime: DateTime.parse(json['departureTime'].toString()),
      arrivalTime: DateTime.parse(json['arrivalTime'].toString()),
      departureTerminal: (json['departureTerminal'] as String?)?.toString(),
      arrivalTerminal: (json['arrivalTerminal'] as String?)?.toString(),
      departureGate: (json['departureGate'] as String?)?.toString(),
      arrivalGate: (json['arrivalGate'] as String?)?.toString(),
      cabin: parseCabin(json['cabin']),
      bookingClass: (json['bookingClass'] as String?)?.toString(),
      equipment: (json['equipment'] as String?)?.toString(),
      status: parseStatus(json['status']),
      baggage: json['baggage'] != null ? BaggageAllowance.fromJson((json['baggage'] as Map).cast<String, dynamic>()) : null,
      recordLocator: (json['recordLocator'] as String?)?.toString(),
    );
  } // [21][24]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'marketingCarrier': marketingCarrier.toJson(),
        'operatingCarrier': operatingCarrier.toJson(),
        'flightNumber': flightNumber,
        'departureAirport': departureAirport,
        'arrivalAirport': arrivalAirport,
        'departureTime': departureTime.toUtc().toIso8601String(),
        'arrivalTime': arrivalTime.toUtc().toIso8601String(),
        if (departureTerminal != null) 'departureTerminal': departureTerminal,
        if (arrivalTerminal != null) 'arrivalTerminal': arrivalTerminal,
        if (departureGate != null) 'departureGate': departureGate,
        if (arrivalGate != null) 'arrivalGate': arrivalGate,
        'cabin': cabin.name,
        if (bookingClass != null) 'bookingClass': bookingClass,
        if (equipment != null) 'equipment': equipment,
        'status': status.name,
        if (baggage != null) 'baggage': baggage!.toJson(),
        if (recordLocator != null) 'recordLocator': recordLocator,
      }; // [21]
}

/// A full itinerary (one or more segments) including totals and optional pricing. [21]
@immutable
class Flight {
  const Flight({
    required this.id,
    required this.segments,
    this.fare, // base fare
    this.taxes,
    this.total,
    this.currency, // optional if Money already carries currency
    this.status = FlightStatus.scheduled,
    this.bookingReference, // PNR/code
    this.metadata,
  });

  final String id;
  final List<FlightSegment> segments;

  final Money? fare;
  final Money? taxes;
  final Money? total;
  final String? currency;

  final FlightStatus status;
  final String? bookingReference;

  final Map<String, dynamic>? metadata;

  /// Total elapsed duration from first departure to last arrival in minutes. [21]
  int get totalDurationMinutes {
    if (segments.isEmpty) return 0;
    final start = segments.first.departureTime;
    final end = segments.last.arrivalTime;
    return end.difference(start).inMinutes;
  }

  /// Number of connections (stops) between origin and final destination. [21]
  int get stops => segments.isEmpty ? 0 : (segments.length - 1);

  /// Origin airport code string (IATA preferred). [22]
  String? get origin => segments.isEmpty ? null : segments.first.departureAirport;

  /// Destination airport code string (IATA preferred). [22]
  String? get destination => segments.isEmpty ? null : segments.last.arrivalAirport;

  Flight copyWith({
    String? id,
    List<FlightSegment>? segments,
    Money? fare,
    Money? taxes,
    Money? total,
    String? currency,
    FlightStatus? status,
    String? bookingReference,
    Map<String, dynamic>? metadata,
  }) {
    return Flight(
      id: id ?? this.id,
      segments: segments ?? this.segments,
      fare: fare ?? this.fare,
      taxes: taxes ?? this.taxes,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      bookingReference: bookingReference ?? this.bookingReference,
      metadata: metadata ?? this.metadata,
    );
  }

  factory Flight.fromJson(Map<String, dynamic> json) {
    FlightStatus parseStatus(Object? v) {
      final s = (v ?? 'scheduled').toString().toLowerCase();
      switch (s) {
        case 'on time':
        case 'on_time':
        case 'on-time':
        case 'ontime':
          return FlightStatus.onTime;
        case 'delayed':
          return FlightStatus.delayed;
        case 'departed':
          return FlightStatus.departed;
        case 'arrived':
          return FlightStatus.arrived;
        case 'canceled':
        case 'cancelled':
          return FlightStatus.canceled;
        case 'diverted':
          return FlightStatus.diverted;
        case 'scheduled':
          return FlightStatus.scheduled;
        default:
          return FlightStatus.unknown;
      }
    } // [7][10]

    final segs = ((json['segments'] as List?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(FlightSegment.fromJson)
        .toList(growable: false);

    return Flight(
      id: (json['id'] ?? '').toString(),
      segments: segs,
      fare: json['fare'] != null ? Money.fromJson((json['fare'] as Map).cast<String, dynamic>()) : null,
      taxes: json['taxes'] != null ? Money.fromJson((json['taxes'] as Map).cast<String, dynamic>()) : null,
      total: json['total'] != null ? Money.fromJson((json['total'] as Map).cast<String, dynamic>()) : null,
      currency: (json['currency'] as String?)?.toUpperCase(),
      status: parseStatus(json['status']),
      bookingReference: (json['bookingReference'] as String?)?.toString(),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  } // [21]

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'segments': segments.map((s) => s.toJson()).toList(growable: false),
        if (fare != null) 'fare': fare!.toJson(),
        if (taxes != null) 'taxes': taxes!.toJson(),
        if (total != null) 'total': total!.toJson(),
        if (currency != null) 'currency': currency,
        'status': status.name,
        if (bookingReference != null) 'bookingReference': bookingReference,
        if (metadata != null) 'metadata': metadata,
      }; // [21]

  @override
  bool operator ==(Object other) =>
      other is Flight &&
      other.id == id &&
      listEquals(other.segments, segments) &&
      other.fare == fare &&
      other.taxes == taxes &&
      other.total == total &&
      other.currency == currency &&
      other.status == status &&
      other.bookingReference == bookingReference &&
      mapEquals(other.metadata, metadata); // [21]

  @override
  int get hashCode => Object.hash(
        id,
        Object.hashAll(segments),
        fare,
        taxes,
        total,
        currency,
        status,
        bookingReference,
        _mapHash(metadata),
      ); // [21]

  int _mapHash(Map<String, dynamic>? m) => m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value))); // [21]
}
