import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  final FlutterSecureStorage _storage;

  TokenStorage({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';

  static const String _refreshTokenKey = 'refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(
      key: _accessTokenKey,
      value: accessToken,
    );

    if (refreshToken != null) {
      await _storage.write(
        key: _refreshTokenKey,
        value: refreshToken,
      );
    }
  }

  Future<void> saveAccessToken(
    String accessToken,
  ) {
    return _storage.write(
      key: _accessTokenKey,
      value: accessToken,
    );
  }

  Future<String?> getAccessToken() {
    return _storage.read(
      key: _accessTokenKey,
    );
  }

  Future<String?> getRefreshToken() {
    return _storage.read(
      key: _refreshTokenKey,
    );
  }

  Future<void> clear() {
    return _storage.deleteAll();
  }
}
