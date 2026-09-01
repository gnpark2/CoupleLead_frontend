class WebTokenStorage {
  String? _accessToken;

  String? get accessToken =>
      _accessToken;

  void saveAccessToken(
    String accessToken,
  ) {
    _accessToken = accessToken;
  }

  void clear() {
    _accessToken = null;
  }
}