import 'package:dio/dio.dart';

class DeviceApi {
  final Dio dio;

  DeviceApi({
    required this.dio,
  });

  Future<void> register({
    required String fid,
    required String fcmToken,
    required String platform,
  }) async {
    await dio.post(
      '/api/devices',
      data: {
        'fid': fid,
        'fcmToken': fcmToken,
        'platform': platform,
      },
    );
  }
}
