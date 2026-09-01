import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/app_navigator.dart';
import '../core/session/authenticated_session_listener.dart';
import '../features/auth/domain/auth_status.dart';
import '../features/auth/presentation/auth_provider.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/post_login_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/couple/presentation/couple_connect_page.dart';
import '../features/media/presentation/media_room_page.dart';
import '../features/user/presentation/change_password_page.dart';
import '../features/user/presentation/home_page.dart';

final routerProvider = Provider<GoRouter>(
  (ref) {
    final authState = ref.watch(authControllerProvider);

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (
            context,
            state,
          ) {
            return const SplashPage();
          },
        ),
        GoRoute(
          path: '/login',
          builder: (
            context,
            state,
          ) {
            return const LoginPage();
          },
        ),
        ShellRoute(
          builder: (
            context,
            state,
            child,
          ) {
            return AuthenticatedSessionListener(
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/gateway',
              builder: (
                context,
                state,
              ) {
                return const PostLoginPage();
              },
            ),
            GoRoute(
              path: '/home',
              builder: (
                context,
                state,
              ) {
                return const HomePage();
              },
            ),
            GoRoute(
              path: '/couple/connect',
              builder: (
                context,
                state,
              ) {
                return const CoupleConnectPage();
              },
            ),
            GoRoute(
              path: '/media',
              builder: (
                context,
                state,
              ) {
                return const MediaRoomPage();
              },
            ),
            GoRoute(
              path: '/settings/password',
              builder: (
                context,
                state,
              ) {
                return const ChangePasswordPage();
              },
            ),
          ],
        ),
      ],
      redirect: (
        context,
        routerState,
      ) {
        if (authState.isLoading) {
          if (routerState.matchedLocation != '/') {
            return '/';
          }

          return null;
        }

        if (authState.hasError) {
          return '/login';
        }

        final status = authState.value;

        final location = routerState.matchedLocation;

        final isLogin = location == '/login';

        final isSplash = location == '/';

        /*
   * 비로그인
   */
        if (status == AuthStatus.unauthenticated) {
          if (!isLogin) {
            return '/login';
          }

          return null;
        }

        /*
   * 로그인
   */
        if (status == AuthStatus.authenticated) {
          /*
     * 로그인/스플래시에서만
     * gateway로 이동
     */
          if (isLogin || isSplash) {
            return '/gateway';
          }

          return null;
        }

        return null;
      },
    );
  },
);
