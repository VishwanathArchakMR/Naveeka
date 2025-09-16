// lib/models/address.dart

/// Postal address model with tolerant parsing and single-line formatting. [web:1036]
class Address {
  final String? street;
  final String? landmark;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;

  const Address({
    this.street,
    this.landmark,
    this.city,
    this.state,
    this.country,
    this.postalCode,
  });

  /// Tolerant parser supports: postalCode | zip | pincode. [web:1036]
  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'] as String?,
      landmark: json['landmark'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      postalCode: (json['postalCode'] ?? json['zip'] ?? json['pincode']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'street': street,
        'landmark': landmark,
        'city': city,
        'state': state,
        'country': country,
        'postalCode': postalCode,
      };

  Address copyWith({
    String? street,
    String? landmark,
    String? city,
    String? state,
    String? country,
    String? postalCode,
  }) {
    return Address(
      street: street ?? this.street,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
    );
  }

  /// Returns a concise, human-readable single line for UI. [web:1036]
  @override
  String toString() {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (landmark != null && landmark!.isNotEmpty) parts.add(landmark!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    if (postalCode != null && postalCode!.isNotEmpty) parts.add(postalCode!);
    return parts.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Address &&
          runtimeType == other.runtimeType &&
          street == other.street &&
          landmark == other.landmark &&
          city == other.city &&
          state == other.state &&
          country == other.country &&
          postalCode == other.postalCode;

  @override
  int get hashCode => Object.hash(street, landmark, city, state, country, postalCode);
}
