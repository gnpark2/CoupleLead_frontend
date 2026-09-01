import 'dart:typed_data';

import 'package:couplead_flutter/features/user/data/user_api.dart';

class UserRepository {
  final UserApi userApi;

  UserRepository({
    required this.userApi,
  });

  Future<void> updateProfile({
    required String nickname,
  }) {
    return userApi.updateProfile(
      nickname: nickname,
    );
  }

  Future<void> updateProfileImage({
    required Uint8List bytes,
    required String filename,
  }) {
    return userApi.updateProfileImage(
      bytes: bytes,
      filename: filename,
    );
  }
}