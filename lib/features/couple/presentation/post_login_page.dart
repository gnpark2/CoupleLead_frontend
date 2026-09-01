import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../anniversary/presentation/anniversary_provider.dart';
import '../../couple/presentation/couple_provider.dart';
import '../../user/presentation/user_provider.dart';
import '../../widget/presentation/widget_provider.dart';

class PostLoginPage extends ConsumerWidget {
  const PostLoginPage({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final meAsync = ref.watch(
      meProvider,
    );

    return Scaffold(
      body: Center(
        child: meAsync.when(
          /*
           * 현재 로그인 사용자 확인 중
           */
          loading: () => const CircularProgressIndicator(),

          /*
           * 사용자 조회 실패
           */
          error: (
            error,
            stackTrace,
          ) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '사용자 정보를 확인하지 못했습니다.',
                ),
                const SizedBox(
                  height: 16,
                ),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(
                      meProvider,
                    );
                  },
                  child: const Text(
                    '다시 시도',
                  ),
                ),
              ],
            );
          },

          /*
           * 현재 사용자 확인 완료
           */
          data: (me) {
            return _CoupleCheckView(
              userId: me.id,
            );
          },
        ),
      ),
    );
  }
}

class _CoupleCheckView extends ConsumerWidget {
  final int userId;

  const _CoupleCheckView({
    required this.userId,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final coupleState = ref.watch(
      coupleConnectionProvider(
        userId,
      ),
    );

    ref.listen(
      coupleConnectionProvider(
        userId,
      ),
      (
        previous,
        next,
      ) {
        next.whenData(
          (connected) {
            if (!context.mounted) {
              return;
            }

            if (connected) {
              /*
               * Home 데이터는
               * 실제로 Home에 들어가기 직전에 갱신
               */
              ref.invalidate(
                coupleWidgetProvider,
              );

              ref.invalidate(
                anniversaryListProvider,
              );

              ref.invalidate(
                homeAnniversaryProvider,
              );

              context.go(
                '/home',
              );

              return;
            }

            /*
             * 실제로 커플이 없는 사용자만
             * 연결 페이지로 이동
             */
            context.go(
              '/couple/connect',
            );
          },
        );
      },
    );

    return coupleState.when(
      loading: () => const CircularProgressIndicator(),
      data: (_) => const CircularProgressIndicator(),
      error: (
        error,
        stackTrace,
      ) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '커플 정보를 확인하지 못했습니다.',
            ),
            const SizedBox(
              height: 16,
            ),
            FilledButton(
              onPressed: () {
                ref.invalidate(
                  coupleConnectionProvider(
                    userId,
                  ),
                );
              },
              child: const Text(
                '다시 시도',
              ),
            ),
          ],
        );
      },
    );
  }
}
