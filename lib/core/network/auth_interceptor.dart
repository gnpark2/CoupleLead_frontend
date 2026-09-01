import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'platform_http_adapter.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorage tokenStorage;

  bool _isRefreshing = false;

  AuthInterceptor({
    required this.dio,
    required this.tokenStorage,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    debugPrint(
      'AUTH INTERCEPTOR REQUEST '
      '${options.method} '
      '${options.path}',
    );
    final accessToken = await tokenStorage.getAccessToken();

    if (accessToken != null && !_isPublicAuthPath(options.path)) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    if (_isAuthPath(
      err.requestOptions.path,
    )) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      handler.next(err);
      return;
    }

    _isRefreshing = true;

    try {
        final newAccessToken = await _refreshNative();
          //kIsWeb ? await _refreshWeb() : await _refreshNative();

      if (newAccessToken == null) {
        await tokenStorage.clear();

        handler.next(err);
        return;
      }

      final requestOptions = err.requestOptions;

      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

      final response = await dio.fetch(
        requestOptions,
      );

      handler.resolve(response);
    } catch (_) {
      await tokenStorage.clear();

      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

//   Future<String?> _refreshWeb() async {
//     final refreshDio = Dio(
//       BaseOptions(
//         baseUrl: dio.options.baseUrl,
//         headers: {
//           'Content-Type': 'application/json',
//         },
//       ),
//     );

// // HttpOnly refreshToken Cookie 전송

//     configurePlatformHttpAdapter(
//       refreshDio,
//     );

//     final response = await refreshDio.post(
//       ApiConstants.webReissue,
//     );

//     final body = response.data as Map<String, dynamic>;

//     final data = body['data'] as Map<String, dynamic>;

//     final accessToken = data['accessToken'] as String;

//     await tokenStorage.saveAccessToken(
//       accessToken,
//     );

//     return accessToken;
//   }

  Future<String?> _refreshNative() async {
    final refreshToken = await tokenStorage.getRefreshToken();

    if (refreshToken == null) {
      return null;
    }

    final refreshDio = Dio(
      BaseOptions(
        baseUrl: dio.options.baseUrl,
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    final response = await refreshDio.post(
      ApiConstants.reissue,
      data: {
        'refreshToken': refreshToken,
      },
    );

    final body = response.data as Map<String, dynamic>;

    final data = body['data'] as Map<String, dynamic>;

    final accessToken = data['accessToken'] as String;

    final newRefreshToken = data['refreshToken'] as String?;

    await tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: newRefreshToken ?? refreshToken,
    );

    return accessToken;
  }

  bool _isPublicAuthPath(
    String path,
  ) {
    return path == ApiConstants.login ||
        path == ApiConstants.signup ||
        path == ApiConstants.reissue;
        // path == ApiConstants.webLogin ||
        // path == ApiConstants.webReissue;
  }

  bool _isAuthPath(
    String path,
  ) {
    return path.startsWith(
      '/api/auth/',
    );
  }
}
