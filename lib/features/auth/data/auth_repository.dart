import 'package:flutter/foundation.dart';

import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';
import 'model/login_request.dart';

class AuthRepository {
  final AuthApi authApi;
  final TokenStorage tokenStorage;

  AuthRepository({
    required this.authApi,
    required this.tokenStorage,
  });

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await authApi.login(
      LoginRequest(
        email: email,
        password: password,
      ),
    );

    await tokenStorage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
  }

  Future<bool> restoreSession() async {
    try {
      if (kIsWeb) {
        // /*
        //  * Web에서는 Access Token이 메모리에만 있으므로
        //  * 페이지 새로고침 시 반드시 HttpOnly Cookie를
        //  * 이용해 다시 발급받는다.
        //  */
        // final accessToken = await authApi.reissueWeb();

        // await tokenStorage.saveAccessToken(
        //   accessToken,
        // );
      } else {
        /*
         * Native에서는 Secure Storage에
         * Access Token이 남아있는지 먼저 확인한다.
         */
        final accessToken = await tokenStorage.getAccessToken();

        if (accessToken == null) {
          return false;
        }
      }

      /*
       * 실제 서버 요청으로 세션 검증.
       *
       * Native Access Token이 만료됐다면
       * AuthInterceptor가 자동으로 재발급한다.
       */
      await authApi.validateSession();

      return true;
    } catch (_) {
      await tokenStorage.clear();

      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (kIsWeb) {
        /*
       * Web:
       * Refresh Token은 HttpOnly Cookie에 있으므로
       * 서버에 별도로 전달하지 않는다.
       */
        await authApi.logoutWeb();
      } else {
        /*
       * Native:
       * Secure Storage에서 Refresh Token을 가져와
       * 서버 logout API에 전달한다.
       */
        final refreshToken = await tokenStorage.getRefreshToken();

        if (refreshToken != null) {
          await authApi.logoutNative(
            refreshToken,
          );
        }
      }
    } finally {
      /*
     * 서버 logout 성공 여부와 관계없이
     * 로컬 토큰은 반드시 삭제
     */
      await tokenStorage.clear();
    }
  }

  Future<void> clearLocalSession() async {
    await tokenStorage.clear();
  }
}
