// lib/models/share_location_request.dart

class ShareLocationRequest {
  final double latitude;
  final double longitude;
  final String? address;
  final String? description;
  final DateTime timestamp;

  const ShareLocationRequest({
    required this.latitude,
    required this.longitude,
    this.address,
    this.description,
    required this.timestamp,
  });

  factory ShareLocationRequest.fromJson(Map<String, dynamic> json) {
    return ShareLocationRequest(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      address: json['address'],
      description: json['description'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShareLocationRequest &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.address == address &&
        other.description == description &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      latitude,
      longitude,
      address,
      description,
      timestamp,
    );
  }

  @override
  String toString() {
    return 'ShareLocationRequest(lat: $latitude, lng: $longitude, address: $address, description: $description, timestamp: $timestamp)';
  }
}

