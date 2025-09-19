// lib/models/booking.dart

import 'package:flutter/foundation.dart';

/// High-level product category for a booking. [2]
enum BookingType { flight, hotel, car, activity, package }

/// Lifecycle state for a booking record. [2]
enum BookingStatus { pending, confirmed, onHold, completed, canceled, refunded, failed }

/// Traveler passenger type for price rules and manifests. [2]
enum TravelerType { adult, child, infant }

/// Payment method classification stored with the booking. [2]
enum PaymentMethod { card, upi, wallet, cash, bank, other }

/// Currency amount as minor units (e.g., cents/paise) plus ISO code. [1]
@immutable
class Money {
  const Money({required this.currency, required this.amountMinor});

  final String currency; // ISO 4217 like "USD", "INR"
  final int amountMinor; // e.g., cents/paise

  double get amount => amountMinor / 100.0;

  Money copyWith({String? currency, int? amountMinor}) =>
      Money(currency: currency ?? this.currency, amountMinor: amountMinor ?? this.amountMinor);

  factory Money.fromJson(Map<String, dynamic> json) => Money(
        currency: (json['currency'] ?? '').toString(),
        amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'currency': currency,
        'amountMinor': amountMinor,
      };

  @override
  bool operator ==(Object other) => other is Money && other.currency == currency && other.amountMinor == amountMinor;

  @override
  int get hashCode => Object.hash(currency, amountMinor);

  @override
  String toString() => '$currency $amountMinor(minor)';
}

/// Traveler information for manifests and check-in. [1]
@immutable
class Traveler {
  const Traveler({
    required this.id,
    required this.type,
    required this.firstName,
    required this.lastName,
    this.title,
    this.email,
    this.phone,
  });

  final String id;
  final TravelerType type;
  final String firstName;
  final String lastName;
  final String? title; // e.g., Mr/Ms
  final String? email;
  final String? phone;

  String get fullName => [title, firstName, lastName].where((e) => (e ?? '').trim().isNotEmpty).join(' ');

  Traveler copyWith({
    String? id,
    TravelerType? type,
    String? firstName,
    String? lastName,
    String? title,
    String? email,
    String? phone,
  }) {
    return Traveler(
      id: id ?? this.id,
      type: type ?? this.type,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      title: title ?? this.title,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  factory Traveler.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? 'adult').toString();
    TravelerType t;
    try {
      t = TravelerType.values.byName(typeStr);
    } catch (_) {
      t = TravelerType.adult;
    }
    return Traveler(
      id: (json['id'] ?? '').toString(),
      type: t,
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      title: (json['title'] as String?)?.toString(),
      email: (json['email'] as String?)?.toString(),
      phone: (json['phone'] as String?)?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'firstName': firstName,
        'lastName': lastName,
        if (title != null) 'title': title,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
      };

  @override
  bool operator ==(Object other) =>
      other is Traveler &&
      other.id == id &&
      other.type == type &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.title == title &&
      other.email == email &&
      other.phone == phone;

  @override
  int get hashCode => Object.hash(id, type, firstName, lastName, title, email, phone);
}

/// Payment receipt details captured on successful charge. [1]
@immutable
class PaymentInfo {
  const PaymentInfo({
    this.method,
    this.brand,
    this.last4,
    this.transactionId,
    this.paidAt,
  });

  final PaymentMethod? method;
  final String? brand; // e.g., VISA/MASTERCARD/UPI provider
  final String? last4; // masked account
  final String? transactionId;
  final DateTime? paidAt;

  PaymentInfo copyWith({
    PaymentMethod? method,
    String? brand,
    String? last4,
    String? transactionId,
    DateTime? paidAt,
  }) {
    return PaymentInfo(
      method: method ?? this.method,
      brand: brand ?? this.brand,
      last4: last4 ?? this.last4,
      transactionId: transactionId ?? this.transactionId,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    final mStr = (json['method'] ?? '').toString();
    PaymentMethod? m;
    if (mStr.isNotEmpty) {
      try {
        m = PaymentMethod.values.byName(mStr);
      } catch (_) {
        m = PaymentMethod.other;
      }
    }
    return PaymentInfo(
      method: m,
      brand: (json['brand'] as String?)?.toString(),
      last4: (json['last4'] as String?)?.toString(),
      transactionId: (json['transactionId'] as String?)?.toString(),
      paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (method != null) 'method': method!.name,
        if (brand != null) 'brand': brand,
        if (last4 != null) 'last4': last4,
        if (transactionId != null) 'transactionId': transactionId,
        if (paidAt != null) 'paidAt': paidAt!.toUtc().toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is PaymentInfo &&
      other.method == method &&
      other.brand == brand &&
      other.last4 == last4 &&
      other.transactionId == transactionId &&
      other.paidAt == paidAt;

  @override
  int get hashCode => Object.hash(method, brand, last4, transactionId, paidAt);
}

/// One flight leg/segment for a flight booking. [1]
@immutable
class FlightSegment {
  const FlightSegment({
    required this.carrierCode, // e.g., AI
    required this.flightNumber, // e.g., 176
    required this.departureAirport, // IATA or ICAO
    required this.arrivalAirport, // IATA or ICAO
    required this.departureTime, // ISO date-time with TZ
    required this.arrivalTime, // ISO date-time with TZ
    this.durationMinutes,
    this.cabin, // e.g., Economy/Premium/Business/First
    this.bookingClass, // e.g., Y, J
    this.recordLocator, // PNR if per-segment
  });

  final String carrierCode;
  final String flightNumber;
  final String departureAirport;
  final String arrivalAirport;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final int? durationMinutes;
  final String? cabin;
  final String? bookingClass;
  final String? recordLocator;

  FlightSegment copyWith({
    String? carrierCode,
    String? flightNumber,
    String? departureAirport,
    String? arrivalAirport,
    DateTime? departureTime,
    DateTime? arrivalTime,
    int? durationMinutes,
    String? cabin,
    String? bookingClass,
    String? recordLocator,
  }) {
    return FlightSegment(
      carrierCode: carrierCode ?? this.carrierCode,
      flightNumber: flightNumber ?? this.flightNumber,
      departureAirport: departureAirport ?? this.departureAirport,
      arrivalAirport: arrivalAirport ?? this.arrivalAirport,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      cabin: cabin ?? this.cabin,
      bookingClass: bookingClass ?? this.bookingClass,
      recordLocator: recordLocator ?? this.recordLocator,
    );
  }

  factory FlightSegment.fromJson(Map<String, dynamic> json) => FlightSegment(
        carrierCode: (json['carrierCode'] ?? '').toString(),
        flightNumber: (json['flightNumber'] ?? '').toString(),
        departureAirport: (json['departureAirport'] ?? '').toString(),
        arrivalAirport: (json['arrivalAirport'] ?? '').toString(),
        departureTime: DateTime.parse(json['departureTime'].toString()),
        arrivalTime: DateTime.parse(json['arrivalTime'].toString()),
        durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
        cabin: (json['cabin'] as String?)?.toString(),
        bookingClass: (json['bookingClass'] as String?)?.toString(),
        recordLocator: (json['recordLocator'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'carrierCode': carrierCode,
        'flightNumber': flightNumber,
        'departureAirport': departureAirport,
        'arrivalAirport': arrivalAirport,
        'departureTime': departureTime.toUtc().toIso8601String(),
        'arrivalTime': arrivalTime.toUtc().toIso8601String(),
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (cabin != null) 'cabin': cabin,
        if (bookingClass != null) 'bookingClass': bookingClass,
        if (recordLocator != null) 'recordLocator': recordLocator,
      };

  @override
  bool operator ==(Object other) =>
      other is FlightSegment &&
      other.carrierCode == carrierCode &&
      other.flightNumber == flightNumber &&
      other.departureAirport == departureAirport &&
      other.arrivalAirport == arrivalAirport &&
      other.departureTime == departureTime &&
      other.arrivalTime == arrivalTime &&
      other.durationMinutes == durationMinutes &&
      other.cabin == cabin &&
      other.bookingClass == bookingClass &&
      other.recordLocator == recordLocator;

  @override
  int get hashCode =>
      Object.hash(carrierCode, flightNumber, departureAirport, arrivalAirport, departureTime, arrivalTime, durationMinutes, cabin, bookingClass, recordLocator);
}

/// Hotel stay details tied to a booking. [1]
@immutable
class HotelStay {
  const HotelStay({
    required this.propertyName,
    required this.checkIn, // Local date/time in IANA TZ recommended
    required this.checkOut, // Local date/time in IANA TZ recommended
    this.addressLine,
    this.city,
    this.countryCode,
    this.roomType,
    this.ratePlan,
    this.confirmationNumber,
  });

  final String propertyName;
  final DateTime checkIn;
  final DateTime checkOut;
  final String? addressLine;
  final String? city;
  final String? countryCode;
  final String? roomType;
  final String? ratePlan;
  final String? confirmationNumber;

  HotelStay copyWith({
    String? propertyName,
    DateTime? checkIn,
    DateTime? checkOut,
    String? addressLine,
    String? city,
    String? countryCode,
    String? roomType,
    String? ratePlan,
    String? confirmationNumber,
  }) {
    return HotelStay(
      propertyName: propertyName ?? this.propertyName,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      addressLine: addressLine ?? this.addressLine,
      city: city ?? this.city,
      countryCode: countryCode ?? this.countryCode,
      roomType: roomType ?? this.roomType,
      ratePlan: ratePlan ?? this.ratePlan,
      confirmationNumber: confirmationNumber ?? this.confirmationNumber,
    );
  }

  factory HotelStay.fromJson(Map<String, dynamic> json) => HotelStay(
        propertyName: (json['propertyName'] ?? '').toString(),
        checkIn: DateTime.parse(json['checkIn'].toString()),
        checkOut: DateTime.parse(json['checkOut'].toString()),
        addressLine: (json['addressLine'] as String?)?.toString(),
        city: (json['city'] as String?)?.toString(),
        countryCode: (json['countryCode'] as String?)?.toUpperCase(),
        roomType: (json['roomType'] as String?)?.toString(),
        ratePlan: (json['ratePlan'] as String?)?.toString(),
        confirmationNumber: (json['confirmationNumber'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'propertyName': propertyName,
        'checkIn': checkIn.toUtc().toIso8601String(),
        'checkOut': checkOut.toUtc().toIso8601String(),
        if (addressLine != null) 'addressLine': addressLine,
        if (city != null) 'city': city,
        if (countryCode != null) 'countryCode': countryCode,
        if (roomType != null) 'roomType': roomType,
        if (ratePlan != null) 'ratePlan': ratePlan,
        if (confirmationNumber != null) 'confirmationNumber': confirmationNumber,
      };

  @override
  bool operator ==(Object other) =>
      other is HotelStay &&
      other.propertyName == propertyName &&
      other.checkIn == checkIn &&
      other.checkOut == checkOut &&
      other.addressLine == addressLine &&
      other.city == city &&
      other.countryCode == countryCode &&
      other.roomType == roomType &&
      other.ratePlan == ratePlan &&
      other.confirmationNumber == confirmationNumber;

  @override
  int get hashCode => Object.hash(propertyName, checkIn, checkOut, addressLine, city, countryCode, roomType, ratePlan, confirmationNumber);
}

/// Car rental details tied to a booking. [1]
@immutable
class CarRental {
  const CarRental({
    required this.vendor, // rental vendor code/name
    required this.pickupAt,
    required this.dropoffAt,
    this.pickupLocationCode,
    this.dropoffLocationCode,
    this.vehicleClass,
    this.confirmationNumber,
  });

  final String vendor;
  final DateTime pickupAt;
  final DateTime dropoffAt;
  final String? pickupLocationCode;
  final String? dropoffLocationCode;
  final String? vehicleClass;
  final String? confirmationNumber;

  CarRental copyWith({
    String? vendor,
    DateTime? pickupAt,
    DateTime? dropoffAt,
    String? pickupLocationCode,
    String? dropoffLocationCode,
    String? vehicleClass,
    String? confirmationNumber,
  }) {
    return CarRental(
      vendor: vendor ?? this.vendor,
      pickupAt: pickupAt ?? this.pickupAt,
      dropoffAt: dropoffAt ?? this.dropoffAt,
      pickupLocationCode: pickupLocationCode ?? this.pickupLocationCode,
      dropoffLocationCode: dropoffLocationCode ?? this.dropoffLocationCode,
      vehicleClass: vehicleClass ?? this.vehicleClass,
      confirmationNumber: confirmationNumber ?? this.confirmationNumber,
    );
  }

  factory CarRental.fromJson(Map<String, dynamic> json) => CarRental(
        vendor: (json['vendor'] ?? '').toString(),
        pickupAt: DateTime.parse(json['pickupAt'].toString()),
        dropoffAt: DateTime.parse(json['dropoffAt'].toString()),
        pickupLocationCode: (json['pickupLocationCode'] as String?)?.toString(),
        dropoffLocationCode: (json['dropoffLocationCode'] as String?)?.toString(),
        vehicleClass: (json['vehicleClass'] as String?)?.toString(),
        confirmationNumber: (json['confirmationNumber'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'vendor': vendor,
        'pickupAt': pickupAt.toUtc().toIso8601String(),
        'dropoffAt': dropoffAt.toUtc().toIso8601String(),
        if (pickupLocationCode != null) 'pickupLocationCode': pickupLocationCode,
        if (dropoffLocationCode != null) 'dropoffLocationCode': dropoffLocationCode,
        if (vehicleClass != null) 'vehicleClass': vehicleClass,
        if (confirmationNumber != null) 'confirmationNumber': confirmationNumber,
      };

  @override
  bool operator ==(Object other) =>
      other is CarRental &&
      other.vendor == vendor &&
      other.pickupAt == pickupAt &&
      other.dropoffAt == dropoffAt &&
      other.pickupLocationCode == pickupLocationCode &&
      other.dropoffLocationCode == dropoffLocationCode &&
      other.vehicleClass == vehicleClass &&
      other.confirmationNumber == confirmationNumber;

  @override
  int get hashCode => Object.hash(vendor, pickupAt, dropoffAt, pickupLocationCode, dropoffLocationCode, vehicleClass, confirmationNumber);
}

/// Activity/admission/reservation item for tours or events. [1]
@immutable
class ActivityItem {
  const ActivityItem({
    required this.title,
    required this.startAt,
    this.endAt,
    this.vendor,
    this.location,
    this.confirmationNumber,
  });

  final String title;
  final DateTime startAt;
  final DateTime? endAt;
  final String? vendor;
  final String? location;
  final String? confirmationNumber;

  ActivityItem copyWith({
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    String? vendor,
    String? location,
    String? confirmationNumber,
  }) {
    return ActivityItem(
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      vendor: vendor ?? this.vendor,
      location: location ?? this.location,
      confirmationNumber: confirmationNumber ?? this.confirmationNumber,
    );
  }

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        title: (json['title'] ?? '').toString(),
        startAt: DateTime.parse(json['startAt'].toString()),
        endAt: json['endAt'] != null ? DateTime.tryParse(json['endAt'].toString()) : null,
        vendor: (json['vendor'] as String?)?.toString(),
        location: (json['location'] as String?)?.toString(),
        confirmationNumber: (json['confirmationNumber'] as String?)?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'startAt': startAt.toUtc().toIso8601String(),
        if (endAt != null) 'endAt': endAt!.toUtc().toIso8601String(),
        if (vendor != null) 'vendor': vendor,
        if (location != null) 'location': location,
        if (confirmationNumber != null) 'confirmationNumber': confirmationNumber,
      };

  @override
  bool operator ==(Object other) =>
      other is ActivityItem &&
      other.title == title &&
      other.startAt == startAt &&
      other.endAt == endAt &&
      other.vendor == vendor &&
      other.location == location &&
      other.confirmationNumber == confirmationNumber;

  @override
  int get hashCode => Object.hash(title, startAt, endAt, vendor, location, confirmationNumber);
}

/// Unified booking root model covering flights, hotels, cars, and activities. [1]
@immutable
class Booking {
  const Booking({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.supplier, // provider name (e.g., OTA/carrier/vendor)
    this.confirmationCode, // supplier confirmation
    this.recordLocator, // PNR/code if applicable
    this.contactEmail,
    this.contactPhone,
    this.travelers = const <Traveler>[],
    this.baseFare,
    this.taxes,
    this.total,
    this.currency,
    this.payment,
    this.flightSegments,
    this.hotelStay,
    this.carRental,
    this.activities,
    this.notes,
    this.metadata,
  });

  final String id;
  final BookingType type;
  final BookingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  final String? supplier;
  final String? confirmationCode;
  final String? recordLocator;

  final String? contactEmail;
  final String? contactPhone;

  final List<Traveler> travelers;

  final Money? baseFare;
  final Money? taxes;
  final Money? total;
  final String? currency; // optional if Money already includes currency

  final PaymentInfo? payment;

  final List<FlightSegment>? flightSegments;
  final HotelStay? hotelStay;
  final CarRental? carRental;
  final List<ActivityItem>? activities;

  final String? notes;
  final Map<String, dynamic>? metadata;

  bool get isActive => status == BookingStatus.pending || status == BookingStatus.confirmed || status == BookingStatus.onHold;

  Booking copyWith({
    String? id,
    BookingType? type,
    BookingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplier,
    String? confirmationCode,
    String? recordLocator,
    String? contactEmail,
    String? contactPhone,
    List<Traveler>? travelers,
    Money? baseFare,
    Money? taxes,
    Money? total,
    String? currency,
    PaymentInfo? payment,
    List<FlightSegment>? flightSegments,
    HotelStay? hotelStay,
    CarRental? carRental,
    List<ActivityItem>? activities,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return Booking(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplier: supplier ?? this.supplier,
      confirmationCode: confirmationCode ?? this.confirmationCode,
      recordLocator: recordLocator ?? this.recordLocator,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      travelers: travelers ?? this.travelers,
      baseFare: baseFare ?? this.baseFare,
      taxes: taxes ?? this.taxes,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      payment: payment ?? this.payment,
      flightSegments: flightSegments ?? this.flightSegments,
      hotelStay: hotelStay ?? this.hotelStay,
      carRental: carRental ?? this.carRental,
      activities: activities ?? this.activities,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    BookingType bt;
    final tStr = (json['type'] ?? 'package').toString();
    try {
      bt = BookingType.values.byName(tStr);
    } catch (_) {
      bt = BookingType.package;
    }

    BookingStatus bs;
    final sStr = (json['status'] ?? 'pending').toString();
    try {
      bs = BookingStatus.values.byName(sStr);
    } catch (_) {
      bs = BookingStatus.pending;
    }

    List<Traveler> trav(List? raw) => (raw ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Traveler.fromJson)
        .toList(growable: false);

    List<FlightSegment>? seg(List? raw) => raw?.whereType<Map<String, dynamic>>().map(FlightSegment.fromJson).toList(growable: false);

    List<ActivityItem>? acts(List? raw) =>
        raw?.whereType<Map<String, dynamic>>().map(ActivityItem.fromJson).toList(growable: false);

    return Booking(
      id: (json['id'] ?? '').toString(),
      type: bt,
      status: bs,
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      supplier: (json['supplier'] as String?)?.toString(),
      confirmationCode: (json['confirmationCode'] as String?)?.toString(),
      recordLocator: (json['recordLocator'] as String?)?.toString(),
      contactEmail: (json['contactEmail'] as String?)?.toString(),
      contactPhone: (json['contactPhone'] as String?)?.toString(),
      travelers: trav(json['travelers'] as List?),
      baseFare: json['baseFare'] != null ? Money.fromJson(json['baseFare'] as Map<String, dynamic>) : null,
      taxes: json['taxes'] != null ? Money.fromJson(json['taxes'] as Map<String, dynamic>) : null,
      total: json['total'] != null ? Money.fromJson(json['total'] as Map<String, dynamic>) : null,
      currency: (json['currency'] as String?)?.toUpperCase(),
      payment: json['payment'] != null ? PaymentInfo.fromJson(json['payment'] as Map<String, dynamic>) : null,
      flightSegments: seg(json['flightSegments'] as List?),
      hotelStay: json['hotelStay'] != null ? HotelStay.fromJson(json['hotelStay'] as Map<String, dynamic>) : null,
      carRental: json['carRental'] != null ? CarRental.fromJson(json['carRental'] as Map<String, dynamic>) : null,
      activities: acts(json['activities'] as List?),
      notes: (json['notes'] as String?)?.toString(),
      metadata: (json['metadata'] is Map<String, dynamic>) ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'status': status.name,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (supplier != null) 'supplier': supplier,
        if (confirmationCode != null) 'confirmationCode': confirmationCode,
        if (recordLocator != null) 'recordLocator': recordLocator,
        if (contactEmail != null) 'contactEmail': contactEmail,
        if (contactPhone != null) 'contactPhone': contactPhone,
        'travelers': travelers.map((t) => t.toJson()).toList(growable: false),
        if (baseFare != null) 'baseFare': baseFare!.toJson(),
        if (taxes != null) 'taxes': taxes!.toJson(),
        if (total != null) 'total': total!.toJson(),
        if (currency != null) 'currency': currency,
        if (payment != null) 'payment': payment!.toJson(),
        if (flightSegments != null) 'flightSegments': flightSegments!.map((s) => s.toJson()).toList(growable: false),
        if (hotelStay != null) 'hotelStay': hotelStay!.toJson(),
        if (carRental != null) 'carRental': carRental!.toJson(),
        if (activities != null) 'activities': activities!.map((a) => a.toJson()).toList(growable: false),
        if (notes != null) 'notes': notes,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is Booking &&
      other.id == id &&
      other.type == type &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.supplier == supplier &&
      other.confirmationCode == confirmationCode &&
      other.recordLocator == recordLocator;

  @override
  int get hashCode => Object.hash(id, type, status, createdAt, updatedAt, supplier, confirmationCode, recordLocator);

  @override
  String toString() => 'Booking($id ${type.name} ${status.name})';
}
