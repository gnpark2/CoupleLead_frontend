import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../couple/data/couple_api.dart';
import '../../auth/presentation/auth_provider.dart';

final coupleApiProvider = Provider<CoupleApi>(
  (ref) {
    final dio = ref
        .watch(
          dioClientProvider,
        )
        .dio;

    return CoupleApi(
      dio: dio,
    );
  },
);

final coupleInviteCodeProvider = FutureProvider<String>(
  (ref) async {
    final api = ref.watch(
      coupleApiProvider,
    );

    return api.createInviteCode();
  },
);

final coupleConnectProvider =
    AsyncNotifierProvider<CoupleConnectController, void>(
  CoupleConnectController.new,
);

class CoupleConnectController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> connect({
    required String inviteCode,
  }) async {
    state = const AsyncLoading();

    try {
      final api = ref.read(
        coupleApiProvider,
      );

      await api.connect(
        inviteCode: inviteCode,
      );

      state = const AsyncData(null);

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }
}

final coupleConnectionProvider = FutureProvider.autoDispose.family<bool, int>(
  (
    ref,
    userId,
  ) async {
    final dio = ref
        .watch(
          dioClientProvider,
        )
        .dio;

    try {
      final response = await dio.get(
        ApiConstants.myCouple,
      );

      final body = Map<String, dynamic>.from(
        response.data as Map,
      );

      return body['data'] != null;
    } on DioException catch (e) {
      /*
       * 로그인은 되어 있지만
       * 아직 커플이 없는 사용자
       */
      if (e.response?.statusCode == 404) {
        return false;
      }

      rethrow;
    }
  },
);

final coupleDisconnectProvider =
    AsyncNotifierProvider<CoupleDisconnectController, void>(
  CoupleDisconnectController.new,
);

class CoupleDisconnectController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> disconnect() async {
    state = const AsyncLoading();

    try {
      final api = ref.read(
        coupleApiProvider,
      );

      await api.disconnect();

      state = const AsyncData(null);

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }
}
