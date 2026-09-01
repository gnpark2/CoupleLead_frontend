import 'package:dio/dio.dart';

import '../domain/city_search_result.dart';

class CitySearchApi {
  final Dio dio;

  CitySearchApi({
    required this.dio,
  });

  Future<List<CitySearchResult>> search(
    String query,
  ) async {
    final keyword = query.trim();

    /*
     * Open-Meteo는
     * 1글자는 결과를 반환하지 않고,
     * 3글자 이상부터 prefix 검색을 지원한다.
     */
    if (keyword.length < 2) {
      return [];
    }

    final response = await dio.get(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {
        'name': keyword,
        'count': 10,
        'language': 'en',
        'format': 'json',
      },
    );

    final body = response.data as Map<String, dynamic>;

    final rawResults = body['results'];

    if (rawResults == null) {
      return [];
    }

    return (rawResults as List)
        .map(
          (item) => CitySearchResult.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}
