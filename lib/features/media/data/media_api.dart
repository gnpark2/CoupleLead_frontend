import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import 'model/media_token_response.dart';

class MediaApi {
  final Dio dio;

  MediaApi({
    required this.dio,
  });

  Future<MediaTokenResponse> createToken() async {
    final response = await dio.post(
      ApiConstants.mediaToken,
    );

    final body = Map<String, dynamic>.from(
      response.data as Map,
    );

    final data = Map<String, dynamic>.from(
      body['data'] as Map,
    );

    return MediaTokenResponse.fromJson(
      data,
    );
  }

  Future<String> invite() async {
    final response = await dio.post(
      ApiConstants.mediaInvite,
    );

    final body = Map<String, dynamic>.from(
      response.data as Map,
    );

    final data = Map<String, dynamic>.from(
      body['data'] as Map,
    );

    return data['callId'] as String;
  }

  Future<void> accept({
    required String callId,
    required int callerUserId,
  }) async {
    await dio.post(
      ApiConstants.mediaAccept,
      data: {
        'callId': callId,
        'callerUserId': callerUserId,
      },
    );
  }

  Future<void> reject({
    required String callId,
    required int callerUserId,
  }) async {
    await dio.post(
      ApiConstants.mediaReject,
      data: {
        'callId': callId,
        'callerUserId': callerUserId,
      },
    );
  }

  Future<void> leave() async {
    await dio.post(
      ApiConstants.mediaLeave,
    );
  }
}
