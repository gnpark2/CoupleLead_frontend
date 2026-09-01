import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/user_location.dart';

class LocationService {
  Future<UserLocation> getCurrentLocation() async {
    /*
     * 1. 위치 서비스 활성화 확인
     */
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        '기기의 위치 서비스가 꺼져 있습니다.',
      );
    }

    /*
     * 2. 위치 권한 확인
     */
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        '위치 권한이 거부되었습니다.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        '위치 권한이 영구적으로 거부되었습니다.',
      );
    }

    /*
     * 3. 현재 좌표
     */
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    /*
     * 4. 좌표 → 국가/도시
     */
    final geocoding = Geocoding();
    final placemarks = await geocoding.placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) {
      throw Exception(
        '현재 위치의 지역 정보를 찾을 수 없습니다.',
      );
    }

    final placemark = placemarks.first;

    /*
     * 5. 기기의 IANA timezone
     */
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();

    /*
     * countryCode 예:
     * KR
     *
     * locality 예:
     * Seoul
     */
    final country = placemark.isoCountryCode ?? placemark.country ?? '';

    final city = _resolveCity(
      placemark,
    );

    if (country.isEmpty || city.isEmpty) {
      throw Exception(
        '국가 또는 도시 정보를 확인할 수 없습니다.',
      );
    }

    return UserLocation(
      country: country,
      city: city,
      timezone: timezoneInfo.identifier,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  String _resolveCity(
    Placemark placemark,
  ) {
    /*
     * 지역마다 locality가 비어있는 경우가 있어서
     * 순차적으로 fallback한다.
     */
    final candidates = [
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.administrativeArea,
    ];

    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }
}
