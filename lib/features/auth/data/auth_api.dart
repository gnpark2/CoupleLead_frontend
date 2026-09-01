import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import 'model/login_request.dart';
import 'model/login_response.dart';
import 'model/signup_request.dart';

class AuthApi {
  final Dio dio;

  // Couple
  static const String myCouple = '/api/couples/me';

  // Widget
  static const String coupleWidget = '/api/widgets/couple';

  static const String selectWidgetAnniversary = '/api/widgets/anniversary';

  AuthApi({
    required this.dio,
  });

  Future<LoginResponse> login(
    LoginRequest request,
  ) async {
    final response = await dio.post(
      ApiConstants.login,
      data: request.toJson(),
    );

    final body = response.data as Map<String, dynamic>;

    final data = body['data'] as Map<String, dynamic>;

    return LoginResponse.fromJson(data);
  }

  /// Web에서 브라우저 새로고침 후
  /// HttpOnly Refresh Cookie를 이용해
  /// Access Token을 다시 발급받는다.
  // Future<String> reissueWeb() async {
  //   final response = await dio.post(
  //     ApiConstants.webReissue,
  //   );

  //   final body = response.data as Map<String, dynamic>;

  //   final data = body['data'] as Map<String, dynamic>;

  //   return data['accessToken'] as String;
  // }

  /// 현재 Access Token이 실제로 유효한지 확인한다.
  ///
  /// Access Token이 만료됐다면
  /// AuthInterceptor가 자동으로 refresh 후
  /// 이 요청을 다시 수행한다.
  Future<void> validateSession() async {
    await dio.get(
      ApiConstants.me,
    );
  }

  /// Web 로그아웃
  ///
  /// Refresh Token은 HttpOnly Cookie에 있으므로
  /// Flutter가 직접 토큰을 전달하지 않는다.
  /// 브라우저가 Cookie를 자동으로 전송한다.
  Future<void> logoutWeb() async {
    await dio.post(
      ApiConstants.webLogout,
    );
  }

  /// Native 로그아웃
  ///
  /// Native에서는 Refresh Token을 직접 서버에 전달한다.
  Future<void> logoutNative(
    String refreshToken,
  ) async {
    await dio.post(
      ApiConstants.logout,
      data: {
        'refreshToken': refreshToken,
      },
    );
  }

  Future<void> deleteProfileImage() async {
    await dio.delete(
      '/api/users/me/profile-image',
    );
  }

  ////////////////////////////////////////////
  ///
  /// sign

  Future<void> signup({
    required SignupRequest request,
  }) async {
    await dio.post(
      '/api/auth/signup',
      data: request.toJson(),
    );
  }
}
