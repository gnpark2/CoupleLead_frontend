import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../user/presentation/user_provider.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';
import '../data/model/signup_request.dart';
import '../domain/auth_status.dart';
import '../../../core/websocket/stomp_provider.dart';

final accessTokenProvider = FutureProvider<String?>(
  (ref) async {
    final storage = ref.watch(
      tokenStorageProvider,
    );

    return storage.getAccessToken();
  },
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) {
    return TokenStorage();
  },
);

final dioClientProvider = Provider<DioClient>(
  (ref) {
    final tokenStorage = ref.watch(tokenStorageProvider);

    return DioClient(
      tokenStorage: tokenStorage,
    );
  },
);

final authApiProvider = Provider<AuthApi>(
  (ref) {
    final dio = ref.watch(dioClientProvider).dio;

    return AuthApi(
      dio: dio,
    );
  },
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) {
    return AuthRepository(
      authApi: ref.watch(authApiProvider),
      tokenStorage: ref.watch(tokenStorageProvider),
    );
  },
);

final signupProvider = AsyncNotifierProvider<SignupController, void>(
  SignupController.new,
);

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthStatus>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthStatus> {
  @override
  Future<AuthStatus> build() async {
    final repository = ref.read(authRepositoryProvider);

    final restored = await repository.restoreSession();

    if (restored) {
      return AuthStatus.authenticated;
    }

    return AuthStatus.unauthenticated;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    try {
      await ref
          .read(
            authRepositoryProvider,
          )
          .login(
            email: email,
            password: password,
          );

      /*
     * 새 로그인 사용자를 다시 조회
     */
      ref.invalidate(
        meProvider,
      );

      state = const AsyncData(
        AuthStatus.authenticated,
      );

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }

  Future<void> logoutLocal() async {
    ref
        .read(
          stompServiceProvider,
        )
        .disconnect();

    await ref
        .read(
          authRepositoryProvider,
        )
        .clearLocalSession();

    state = const AsyncData(
      AuthStatus.unauthenticated,
    );
  }

  Future<void> logout() async {
    ref
        .read(
          stompServiceProvider,
        )
        .disconnect();

    try {
      await ref
          .read(
            authRepositoryProvider,
          )
          .logout();
    } catch (e) {
      debugPrint(
        'LOGOUT ERROR: $e',
      );
    }

    /*
   * 1. 먼저 화면을 Login으로 전환
   *
   * HomePage가 제거되면서
   * coupleWidgetProvider 등의 listener가 사라진다.
   */
    state = const AsyncData(
      AuthStatus.unauthenticated,
    );
  }
}

class SignupController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signup({
    required SignupRequest request,
  }) async {
    state = const AsyncLoading();

    try {
      final api = ref.read(
        authApiProvider,
      );

      await api.signup(
        request: request,
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
