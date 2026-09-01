import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import 'model/couple_invite_response.dart';

class CoupleApi {
  final Dio dio;

  CoupleApi({
    required this.dio,
  });

  /*
   * 내 초대 코드 발급
   */
  Future<String> createInviteCode() async {
    final response = await dio.post(
      ApiConstants.coupleInvite,
    );

    final responseBody = Map<String, dynamic>.from(
      response.data as Map,
    );

    final data = Map<String, dynamic>.from(
      responseBody['data'] as Map,
    );

    return CoupleInviteResponse.fromJson(data).inviteCode;
  }

  /*
   * 상대방 초대 코드로 커플 연결
   */
  Future<void> connect({
    required String inviteCode,
  }) async {
    await dio.post(
      ApiConstants.coupleConnect,
      data: {
        'inviteCode': inviteCode,
      },
    );
  }

  Future<void> disconnect() async {
    await dio.delete(
      ApiConstants.myCouple,
    );
  }
}
