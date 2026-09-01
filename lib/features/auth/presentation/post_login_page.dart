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
          loading: () => const CircularProgressIndicator(),
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
    final provider = coupleConnectionProvider(
      userId,
    );

    final coupleState = ref.watch(
      provider,
    );

    ref.listen(
      provider,
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
                  provider,
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
