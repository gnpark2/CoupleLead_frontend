import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/top_notification.dart';
import '../../anniversary/presentation/anniversary_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../user/presentation/user_provider.dart';
import '../../user/presentation/withdraw_dialog.dart';
import '../../widget/presentation/widget_provider.dart';
import 'couple_provider.dart';
import 'couple_realtime_provider.dart';

class CoupleConnectPage extends ConsumerStatefulWidget {
  const CoupleConnectPage({
    super.key,
  });

  @override
  ConsumerState<CoupleConnectPage> createState() => _CoupleConnectPageState();
}

class _CoupleConnectPageState extends ConsumerState<CoupleConnectPage> {
  final _partnerCodeController = TextEditingController();

  bool _connecting = false;

  bool _navigating = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _partnerCodeController.dispose();

    super.dispose();
  }

  //////////////////////////////////////////////////////////////////////

  Future<void> _connect() async {
    final inviteCode = _partnerCodeController.text.trim();

    if (inviteCode.isEmpty) {
      TopNotification.show(
        context,
        message: '상대방의 초대 코드를 입력해주세요.',
        type: TopNotificationType.info,
      );

      return;
    }

    if (_connecting || _navigating) {
      return;
    }

    setState(() {
      _connecting = true;
    });

    final success = await ref
        .read(
          coupleConnectProvider.notifier,
        )
        .connect(
          inviteCode: inviteCode,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _connecting = false;
    });

    if (!success) {
      TopNotification.show(
        context,
        message: '커플 연결에 실패했습니다.',
        type: TopNotificationType.error,
      );

      return;
    }

    TopNotification.show(
      context,
      message: '커플 연결이 완료되었습니다.',
      type: TopNotificationType.success,
    );

    /*
   * 여기에서 화면 이동하지 않는다.
   *
   * Backend의 COUPLE_CONNECTED
   * WebSocket 이벤트를 받은 뒤
   * _onCoupleConnected()가 이동시킨다.
   */
  }

  //////////////////////////////////////////////////////////////////////

  @override
  Widget build(
    BuildContext context,
  ) {
    final inviteCodeAsync = ref.watch(
      coupleInviteCodeProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '커플 연결',
        ),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(
              Icons.logout,
            ),
            onPressed: () async {
              await ref
                  .read(
                    authControllerProvider.notifier,
                  )
                  .logout();
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(
            24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 440,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.favorite_border,
                  size: 60,
                ),
                const SizedBox(
                  height: 16,
                ),
                Text(
                  '커플을 연결해주세요',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  '초대 코드를 공유하거나 '
                  '상대방의 초대 코드를 입력해 연결할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium,
                ),
                const SizedBox(
                  height: 32,
                ),

                /*
                 * 내 초대 코드
                 */
                Text(
                  '내 초대 코드',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium,
                ),
                const SizedBox(
                  height: 8,
                ),
                inviteCodeAsync.when(
                  data: (inviteCode) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              inviteCode,
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: '초대 코드 복사',
                            icon: const Icon(
                              Icons.copy,
                            ),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: inviteCode,
                                ),
                              );

                              if (!context.mounted) {
                                return;
                              }

                              TopNotification.show(
                                context,
                                message: '초대 코드를 복사했습니다.',
                                type: TopNotificationType.success,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (
                    error,
                    stackTrace,
                  ) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '초대 코드를 불러오지 못했습니다.',
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        OutlinedButton(
                          onPressed: () {
                            ref.invalidate(
                              coupleInviteCodeProvider,
                            );
                          },
                          child: const Text(
                            '다시 시도',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(
                  height: 28,
                ),
                const Divider(),
                const SizedBox(
                  height: 28,
                ),

                /*
                 * 상대방 초대 코드
                 */
                Text(
                  '상대방 초대 코드',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium,
                ),
                const SizedBox(
                  height: 8,
                ),
                TextField(
                  controller: _partnerCodeController,
                  enabled: !_connecting,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: '상대방의 초대 코드를 입력해주세요.',
                    prefixIcon: Icon(
                      Icons.link,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    if (!_connecting) {
                      _connect();
                    }
                  },
                ),
                const SizedBox(
                  height: 24,
                ),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _connecting ? null : _connect,
                    icon: _connecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.favorite,
                          ),
                    label: const Text(
                      '커플 연결하기',
                    ),
                  ),
                ),
                const SizedBox(
                  height: 24,
                ),
                const Divider(),
                const SizedBox(
                  height: 12,
                ),
                TextButton.icon(
                  onPressed: () async {
                    await showWithdrawDialog(
                      context: context,
                      ref: ref,
                    );
                  },
                  icon: const Icon(
                    Icons.person_remove_outlined,
                  ),
                  label: const Text(
                    '회원 탈퇴',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
