// lib/models/itinerary_day.dart

import 'trip_map_stop.dart';

class ItineraryDay {
  final String id;
  final int dayNumber;
  final DateTime date;
  final List<TripMapStop> stops;
  final String? title;
  final String? description;
  final Map<String, dynamic>? metadata;

  const ItineraryDay({
    required this.id,
    required this.dayNumber,
    required this.date,
    required this.stops,
    this.title,
    this.description,
    this.metadata,
  });

  factory ItineraryDay.fromJson(Map<String, dynamic> json) {
    return ItineraryDay(
      id: json['id'] ?? '',
      dayNumber: json['dayNumber'] ?? 1,
      date: DateTime.parse(json['date']),
      stops: (json['stops'] as List<dynamic>?)
          ?.map((stop) => TripMapStop.fromJson(stop as Map<String, dynamic>))
          .toList() ?? [],
      title: json['title'],
      description: json['description'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dayNumber': dayNumber,
      'date': date.toIso8601String(),
      'stops': stops.map((stop) => stop.toJson()).toList(),
      'title': title,
      'description': description,
      'metadata': metadata,
    };
  }

  ItineraryDay copyWith({
    String? id,
    int? dayNumber,
    DateTime? date,
    List<TripMapStop>? stops,
    String? title,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return ItineraryDay(
      id: id ?? this.id,
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      stops: stops ?? this.stops,
      title: title ?? this.title,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItineraryDay &&
        other.id == id &&
        other.dayNumber == dayNumber &&
        other.date == date &&
        other.stops == stops &&
        other.title == title &&
        other.description == description &&
        other.metadata == metadata;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      dayNumber,
      date,
      stops,
      title,
      description,
      metadata,
    );
  }

  @override
  String toString() {
    return 'ItineraryDay(id: $id, dayNumber: $dayNumber, date: $date, stops: ${stops.length})';
  }
}

