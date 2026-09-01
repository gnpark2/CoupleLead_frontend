import 'user_location.dart';

class CitySearchResult {
  final int id;

  final String name;

  final String countryCode;

  final String country;

  final String timezone;

  final double latitude;

  final double longitude;

  final String? admin1;

  const CitySearchResult({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.country,
    required this.timezone,
    required this.latitude,
    required this.longitude,
    this.admin1,
  });

  factory CitySearchResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return CitySearchResult(
      id: json['id'] as int,
      name: json['name'] as String,
      countryCode: json['country_code'] as String,
      country: json['country'] as String,
      timezone: json['timezone'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      admin1: json['admin1'] as String?,
    );
  }

  String get displayName {
    if (admin1 != null && admin1!.trim().isNotEmpty && admin1 != name) {
      return '$name, $admin1, $country';
    }

    return '$name, $country';
  }

  UserLocation toUserLocation() {
    return UserLocation(
      country: countryCode,
      city: name,
      timezone: timezone,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
