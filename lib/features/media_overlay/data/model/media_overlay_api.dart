import 'package:dio/dio.dart';

class MediaOverlayToken {
  final String url;
  final String token;

  const MediaOverlayToken({
    required this.url,
    required this.token,
  });

  factory MediaOverlayToken.fromJson(
    Map<String, dynamic> json,
  ) {
    return MediaOverlayToken(
      url: json['url'].toString(),
      token: json['token'].toString(),
    );
  }
}

class MediaOverlayApi {
  final Dio dio;

  MediaOverlayApi({
    required this.dio,
  });

  Future<MediaOverlayToken> getToken() async {
    final response = await dio.post(
      '/api/media/overlay/token',
    );

    final body = response.data as Map<String, dynamic>;

    final data = body['data'] as Map<String, dynamic>;

    return MediaOverlayToken.fromJson(
      data,
    );
  }
}
