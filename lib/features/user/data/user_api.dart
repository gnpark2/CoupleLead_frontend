import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import 'model/user_me.dart';

class UserApi {
  final Dio dio;

  UserApi({
    required this.dio,
  });

  Future<UserMe> getMe() async {
    final response = await dio.get(
      ApiConstants.me,
    );

    final body = response.data as Map<String, dynamic>;

    final data = body['data'] as Map<String, dynamic>;

    return UserMe.fromJson(data);
  }

  Future<void> updateProfile({
    required String nickname,
    String? country,
    String? city,
    String? timezone,
    double? latitude,
    double? longitude,
  }) async {
    await dio.patch(
      '/api/users/me/profile',
      data: {
        'nickname': nickname,
        'country': country,
        'city': city,
        'timezone': timezone,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  Future<void> withdraw() async {
    await dio.delete(
      ApiConstants.me,
    );
  }

  Future<void> updateProfileImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
      ),
    });

    await dio.post(
      '/api/users/me/profile-image',
      data: formData,
    );
  }

  Future<void> deleteProfileImage() async {
    await dio.delete(
      '/api/users/me/profile-image',
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await dio.patch(
      ApiConstants.changePassword,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }
}
