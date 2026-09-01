import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

class CoupleApi {
  final Dio dio;

  CoupleApi({
    required this.dio,
  });

  Future<Map<String, dynamic>> getMyCouple() async {
    final response = await dio.get(
      ApiConstants.myCouple,
    );

    final body =
        response.data as Map<String, dynamic>;

    return body['data']
        as Map<String, dynamic>;
  }
}