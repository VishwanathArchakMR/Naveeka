// lib/models/cab.dart

import 'package:flutter/foundation.dart';
import 'booking.dart' show Money;

/// High-level booking status for ride-hailing flows (request -> completion). [12]
enum CabStatus {
  requested,
  accepted,
  arriving,
  onTrip,
  completed,
  canceled,
  failed,
  unknown,
}

/// Product category for cab quotes (maps to provider products). [12]
enum CabProductKind { economy, premium, suv, xl, pooling, auto, moto, other }

/// Provider tag for analytics or UI; keep string-based id alongside display name. [12]
@immutable
class CabProvider {
  const CabProvider({required this.id, required this.name, this.logoUrl});

  final String id; // e.g., 'ola', 'uber', 'lyft', 'indrive'
  final String name; // display label
  final String? logoUrl;

  CabProvider copyWith({String? id, String? name, String? logoUrl}) =>
      CabProvider(id: id ?? this.id, name: name ?? this.name, logoUrl: logoUrl ?? this.logoUrl);

  factory CabProvider.fromJson(Map<String, dynamic> json) => CabProvider(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        logoUrl: (json['logoUrl'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (logoUrl != null) 'logoUrl': logoUrl,
      };

  @override
  bool operator ==(Object other) => other is CabProvider && other.id == id && other.name == name && other.logoUrl == logoUrl;

  @override
  int get hashCode => Object.hash(id, name, logoUrl);
}

/// Simple geographic point with optional address for pickup/dropoff. [1]
@immutable
class CabPoint {
  const CabPoint({
    required this.lat,
    required this.lng,
    this.address,
    this.placeId,
  });

  final double lat;
  final double lng;
  final String? address;
  final String? placeId;

  CabPoint copyWith({double? lat, double? lng, String? address, String? placeId}) => CabPoint(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        address: address ?? this.address,
        placeId: placeId ?? this.placeId,
      );

  factory CabPoint.fromJson(Map<String, dynamic> json) => CabPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        address: (json['address'] as String?)?.toString(),
        placeId: (json['placeId'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lat': lat,
        'lng': lng,
        if (address != null) 'address': address,
        if (placeId != null) 'placeId': placeId,
      };

  @override
  bool operator ==(Object other) =>
      other is CabPoint && other.lat == lat && other.lng == lng && other.address == address && other.placeId == placeId;

  @override
  int get hashCode => Object.hash(lat, lng, address, placeId);
}

/// Driver public profile fields commonly shown in-app. [1]
@immutable
class CabDriver {
  const CabDriver({
    required this.id,
    required this.name,
    this.rating,
    this.phone,
    this.avatarUrl,
    this.licenseNumber,
  });

  final String id;
  final String name;
  final double? rating;
  final String? phone;
  final String? avatarUrl;
  final String? licenseNumber;

  CabDriver copyWith({
    String? id,
    String? name,
    double? rating,
    String? phone,
    String? avatarUrl,
    String? licenseNumber,
  }) {
    return CabDriver(
      id: id ?? this.id,
      name: name ?? this.name,
      rating: rating ?? this.rating,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      licenseNumber: licenseNumber ?? this.licenseNumber,
    );
  }

  factory CabDriver.fromJson(Map<String, dynamic> json) => CabDriver(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        rating: (json['rating'] as num?)?.toDouble(),
        phone: (json['phone'] as String?)?.toString(),
        avatarUrl: (json['avatarUrl'] as String?)?.toString(),
        licenseNumber: (json['licenseNumber'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (rating != null) 'rating': rating,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (licenseNumber != null) 'licenseNumber': licenseNumber,
      };

  @override
  bool operator ==(Object other) =>
      other is CabDriver &&
      other.id == id &&
      other.name == name &&
      other.rating == rating &&
      other.phone == phone &&
      other.avatarUrl == avatarUrl &&
      other.licenseNumber == licenseNumber;

  @override
  int get hashCode => Object.hash(id, name, rating, phone, avatarUrl, licenseNumber);
}

/// Vehicle info shown before pickup and in-trip. [1]
@immutable
class CabVehicle {
  const CabVehicle({
    required this.make,
    required this.model,
    this.color,
    this.plate,
    this.category,
  });

  final String make; // e.g., Toyota
  final String model; // e.g., Etios
  final String? color; // e.g., White
  final String? plate; // e.g., KA-01-AB-1234
  final String? category; // e.g., Sedan/SUV/Hatchback

  CabVehicle copyWith({String? make, String? model, String? color, String? plate, String? category}) => CabVehicle(
        make: make ?? this.make,
        model: model ?? this.model,
        color: color ?? this.color,
        plate: plate ?? this.plate,
        category: category ?? this.category,
      );

  factory CabVehicle.fromJson(Map<String, dynamic> json) => CabVehicle(
        make: (json['make'] ?? '').toString(),
        model: (json['model'] ?? '').toString(),
        color: (json['color'] as String?)?.toString(),
        plate: (json['plate'] as String?)?.toString(),
        category: (json['category'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'make': make,
        'model': model,
        if (color != null) 'color': color,
        if (plate != null) 'plate': plate,
        if (category != null) 'category': category,
      };

  @override
  bool operator ==(Object other) =>
      other is CabVehicle && other.make == make && other.model == model && other.color == color && other.plate == plate && other.category == category;

  @override
  int get hashCode => Object.hash(make, model, color, plate, category);
}

/// Quoted/estimated fare and ETA info before booking, or the billed total after completion. [1]
@immutable
class CabQuote {
  const CabQuote({
    required this.productKind,
    this.productId,
    this.productName,
    this.estimatedFare,
    this.estimatedDistanceMeters,
    this.estimatedDurationSeconds,
    this.surgeMultiplier,
    this.currency, // fallback when Money is absent
  });

  final CabProductKind productKind;
  final String? productId; // provider-specific
  final String? productName; // provider label (e.g., UberGo)
  final Money? estimatedFare;
  final int? estimatedDistanceMeters;
  final int? estimatedDurationSeconds;
  final double? surgeMultiplier;
  final String? currency;

  CabQuote copyWith({
    CabProductKind? productKind,
    String? productId,
    String? productName,
    Money? estimatedFare,
    int? estimatedDistanceMeters,
    int? estimatedDurationSeconds,
    double? surgeMultiplier,
    String? currency,
  }) {
    return CabQuote(
      productKind: productKind ?? this.productKind,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      estimatedDistanceMeters: estimatedDistanceMeters ?? this.estimatedDistanceMeters,
      estimatedDurationSeconds: estimatedDurationSeconds ?? this.estimatedDurationSeconds,
      surgeMultiplier: surgeMultiplier ?? this.surgeMultiplier,
      currency: currency ?? this.currency,
    );
  }

  factory CabQuote.fromJson(Map<String, dynamic> json) {
    CabProductKind kind;
    final k = (json['productKind'] ?? 'other').toString();
    try {
      kind = CabProductKind.values.byName(k);
    } catch (_) {
      kind = CabProductKind.other;
    }
    return CabQuote(
      productKind: kind,
      productId: (json['productId'] as String?)?.toString(),
      productName: (json['productName'] as String?)?.toString(),
      estimatedFare: json['estimatedFare'] != null ? Money.fromJson((json['estimatedFare'] as Map).cast<String, dynamic>()) : null,
      estimatedDistanceMeters: (json['estimatedDistanceMeters'] as num?)?.toInt(),
      estimatedDurationSeconds: (json['estimatedDurationSeconds'] as num?)?.toInt(),
      surgeMultiplier: (json['surgeMultiplier'] as num?)?.toDouble(),
      currency: (json['currency'] as String?)?.toUpperCase(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'productKind': productKind.name,
        if (productId != null) 'productId': productId,
        if (productName != null) 'productName': productName,
        if (estimatedFare != null) 'estimatedFare': estimatedFare!.toJson(),
        if (estimatedDistanceMeters != null) 'estimatedDistanceMeters': estimatedDistanceMeters,
        if (estimatedDurationSeconds != null) 'estimatedDurationSeconds': estimatedDurationSeconds,
        if (surgeMultiplier != null) 'surgeMultiplier': surgeMultiplier,
        if (currency != null) 'currency': currency,
      };

  @override
  bool operator ==(Object other) =>
      other is CabQuote &&
      other.productKind == productKind &&
      other.productId == productId &&
      other.productName == productName &&
      other.estimatedFare == estimatedFare &&
      other.estimatedDistanceMeters == estimatedDistanceMeters &&
      other.estimatedDurationSeconds == estimatedDurationSeconds &&
      other.surgeMultiplier == surgeMultiplier &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(
        productKind,
        productId,
        productName,
        estimatedFare,
        estimatedDistanceMeters,
        estimatedDurationSeconds,
        surgeMultiplier,
        currency,
      );
}

/// Root Cab ride record for request/track/complete flows. [1]
@immutable
class Cab {
  const Cab({
    required this.id,
    required this.provider,
    required this.status,
    required this.requestedAt,
    required this.pickup,
    required this.dropoff,
    this.quote,
    this.driver,
    this.vehicle,
    this.acceptedAt,
    this.arrivingAt,
    this.startedAt,
    this.completedAt,
    this.canceledAt,
    this.cancellationReason,
    this.updatedAt,
    this.metadata,
  });

  final String id;
  final CabProvider provider;
  final CabStatus status;

  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? arrivingAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? canceledAt;
  final String? cancellationReason;

  final CabPoint pickup;
  final CabPoint dropoff;

  final CabQuote? quote;
  final CabDriver? driver;
  final CabVehicle? vehicle;

  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  bool get isActive =>
      status == CabStatus.requested || status == CabStatus.accepted || status == CabStatus.arriving || status == CabStatus.onTrip;

  Cab copyWith({
    String? id,
    CabProvider? provider,
    CabStatus? status,
    DateTime? requestedAt,
    DateTime? acceptedAt,
    DateTime? arrivingAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? canceledAt,
    String? cancellationReason,
    CabPoint? pickup,
    CabPoint? dropoff,
    CabQuote? quote,
    CabDriver? driver,
    CabVehicle? vehicle,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Cab(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      arrivingAt: arrivingAt ?? this.arrivingAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      canceledAt: canceledAt ?? this.canceledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      quote: quote ?? this.quote,
      driver: driver ?? this.driver,
      vehicle: vehicle ?? this.vehicle,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  factory Cab.fromJson(Map<String, dynamic> json) {
    CabStatus parseStatus(Object? s) {
      final v = (s ?? 'unknown').toString();
      try {
        return CabStatus.values.byName(v);
      } catch (_) {
        switch (v.toLowerCase()) {
          case 'accepted':
            return CabStatus.accepted;
          case 'arriving':
            return CabStatus.arriving;
          case 'on_trip':
          case 'ontrip':
            return CabStatus.onTrip;
          case 'completed':
            return CabStatus.completed;
          case 'canceled':
          case 'cancelled':
            return CabStatus.canceled;
          case 'requested':
            return CabStatus.requested;
          case 'failed':
            return CabStatus.failed;
          default:
            return CabStatus.unknown;
        }
      }
    }

    return Cab(
      id: (json['id'] ?? '').toString(),
      provider: CabProvider.fromJson((json['provider'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
      status: parseStatus(json['status']),
      requestedAt: DateTime.parse(json['requestedAt'].toString()),
      acceptedAt: json['acceptedAt'] != null ? DateTime.tryParse(json['acceptedAt'].toString()) : null,
      arrivingAt: json['arrivingAt'] != null ? DateTime.tryParse(json['arrivingAt'].toString()) : null,
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'].toString()) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'].toString()) : null,
      canceledAt: json['canceledAt'] != null ? DateTime.tryParse(json['canceledAt'].toString()) : null,
      cancellationReason: (json['cancellationReason'] as String?)?.toString(),
      pickup: CabPoint.fromJson((json['pickup'] as Map).cast<String, dynamic>()),
      dropoff: CabPoint.fromJson((json['dropoff'] as Map).cast<String, dynamic>()),
      quote: json['quote'] != null ? CabQuote.fromJson((json['quote'] as Map).cast<String, dynamic>()) : null,
      driver: json['driver'] != null ? CabDriver.fromJson((json['driver'] as Map).cast<String, dynamic>()) : null,
      vehicle: json['vehicle'] != null ? CabVehicle.fromJson((json['vehicle'] as Map).cast<String, dynamic>()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'provider': provider.toJson(),
        'status': status.name,
        'requestedAt': requestedAt.toUtc().toIso8601String(),
        if (acceptedAt != null) 'acceptedAt': acceptedAt!.toUtc().toIso8601String(),
        if (arrivingAt != null) 'arrivingAt': arrivingAt!.toUtc().toIso8601String(),
        if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toUtc().toIso8601String(),
        if (canceledAt != null) 'canceledAt': canceledAt!.toUtc().toIso8601String(),
        if (cancellationReason != null) 'cancellationReason': cancellationReason,
        'pickup': pickup.toJson(),
        'dropoff': dropoff.toJson(),
        if (quote != null) 'quote': quote!.toJson(),
        if (driver != null) 'driver': driver!.toJson(),
        if (vehicle != null) 'vehicle': vehicle!.toJson(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is Cab &&
      other.id == id &&
      other.provider == provider &&
      other.status == status &&
      other.requestedAt == requestedAt &&
      other.acceptedAt == acceptedAt &&
      other.arrivingAt == arrivingAt &&
      other.startedAt == startedAt &&
      other.completedAt == completedAt &&
      other.canceledAt == canceledAt &&
      other.cancellationReason == cancellationReason &&
      other.pickup == pickup &&
      other.dropoff == dropoff &&
      other.quote == quote &&
      other.driver == driver &&
      other.vehicle == vehicle &&
      other.updatedAt == updatedAt &&
      mapEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(
        id,
        provider,
        status,
        requestedAt,
        acceptedAt,
        arrivingAt,
        startedAt,
        completedAt,
        canceledAt,
        cancellationReason,
        pickup,
        dropoff,
        quote,
        driver,
        vehicle,
        updatedAt,
        _mapHash(metadata),
      );

  int _mapHash(Map<String, dynamic>? m) => m == null ? 0 : Object.hashAllUnordered(m.entries.map((e) => Object.hash(e.key, e.value)));
}
