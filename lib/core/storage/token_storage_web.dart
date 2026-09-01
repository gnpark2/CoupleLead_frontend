class TokenStorage {
  String? _accessToken;

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    /*
     * Web에서는 refreshToken을
     * 절대 저장하지 않는다.
     */

    _accessToken = accessToken;
  }

  Future<void> saveAccessToken(
    String accessToken,
  ) async {
    _accessToken = accessToken;
  }

  Future<String?> getAccessToken() async {
    return _accessToken;
  }

  Future<String?> getRefreshToken() async {
    /*
     * Web Refresh Token은
     * HttpOnly Cookie이므로
     * Dart에서 접근하지 않는다.
     */

    return null;
  }

  Future<void> clear() async {
    _accessToken = null;
  }
}
