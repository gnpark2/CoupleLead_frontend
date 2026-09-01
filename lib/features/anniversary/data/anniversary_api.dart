import 'package:dio/dio.dart';

import 'model/anniversary.dart';
import 'model/create_anniversary_request.dart';
import 'model/update_anniversary_request.dart';

class AnniversaryApi {
  final Dio dio;

  AnniversaryApi({
    required this.dio,
  });

  Future<List<Anniversary>> getAll() async {
    final response = await dio.get(
      '/api/anniversaries',
    );

    final responseBody = Map<String, dynamic>.from(
      response.data as Map,
    );

    final data = responseBody['data'] as List<dynamic>;

    return data
        .map(
          (item) => Anniversary.fromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
        .toList();
  }

  Future<Anniversary> create({
    required CreateAnniversaryRequest request,
  }) async {
    final response = await dio.post(
      '/api/anniversaries',
      data: request.toJson(),
    );

    final responseBody = Map<String, dynamic>.from(
      response.data as Map,
    );

    final data = Map<String, dynamic>.from(
      responseBody['data'] as Map,
    );

    return Anniversary.fromJson(
      data,
    );
  }

  Future<List<Anniversary>> getHomeAnniversaries() async {
    final response = await dio.get(
      '/api/anniversaries/home',
    );

    final responseBody = Map<String, dynamic>.from(
      response.data as Map,
    );

    final data = responseBody['data'] as List<dynamic>;

    return data
        .map(
          (item) => Anniversary.fromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
        .toList();
  }

  Future<List<Anniversary>> updateHomeAnniversaries({
    required List<int> anniversaryIds,
  }) async {
    final response = await dio.put(
      '/api/anniversaries/home',
      data: {
        'anniversaryIds': anniversaryIds,
      },
    );

    final responseBody = Map<String, dynamic>.from(
      response.data as Map,
    );

    final data = responseBody['data'] as List<dynamic>;

    return data
        .map(
          (item) => Anniversary.fromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
        .toList();
  }

  Future<Anniversary> update({
    required int anniversaryId,
    required UpdateAnniversaryRequest request,
  }) async {
    final response = await dio.patch(
      '/api/anniversaries/$anniversaryId',
      data: request.toJson(),
    );

    final responseBody = Map<String, dynamic>.from(
      response.data as Map,
    );

    return Anniversary.fromJson(
      Map<String, dynamic>.from(
        responseBody['data'] as Map,
      ),
    );
  }

  Future<void> delete({
    required int anniversaryId,
  }) async {
    await dio.delete(
      '/api/anniversaries/$anniversaryId',
    );
  }
}
