import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/top_notification.dart';
import '../../auth/presentation/auth_provider.dart';
import 'user_provider.dart';

Future<void> showWithdrawDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (
      dialogContext,
    ) {
      return AlertDialog(
        title: const Text(
          '회원 탈퇴',
        ),
        content: const Text(
          '회원 탈퇴를 진행하시겠습니까?\n\n'
          '계정과 관련 데이터가 삭제되며 '
          '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(false);
            },
            child: const Text(
              '취소',
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(true);
            },
            child: const Text(
              '회원 탈퇴',
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  final success = await ref
      .read(
        withdrawProvider.notifier,
      )
      .withdraw();

  if (!context.mounted) {
    return;
  }

  if (!success) {
    TopNotification.show(
      context,
      message: '회원 탈퇴에 실패했습니다.',
      type: TopNotificationType.error,
    );

    return;
  }

  /*
   * 서버 User 삭제 완료
   * → 로컬 토큰 제거
   * → LoginPage로 이동
   */
  await ref
      .read(
        authControllerProvider.notifier,
      )
      .logoutLocal();
}
