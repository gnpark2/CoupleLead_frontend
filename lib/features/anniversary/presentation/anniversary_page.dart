import 'package:couplead_flutter/features/anniversary/data/model/anniversary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../anniversary/presentation/anniversary_ui_helper.dart';
import '../../../core/ui/top_notification.dart';
import 'anniversary_create_page.dart';
import 'anniversary_edit_page.dart';
import 'anniversary_provider.dart';
import 'home_anniversary_selection_page.dart';

class AnniversaryPage extends ConsumerWidget {
  const AnniversaryPage({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final anniversariesAsync = ref.watch(
      anniversaryListProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '기념일',
        ),
        actions: [
          IconButton(
            tooltip: 'Home 표시 설정',
            icon: const Icon(
              Icons.home_outlined,
            ),
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(
                MaterialPageRoute(
                  builder: (_) => const HomeAnniversarySelectionPage(),
                ),
              );

              /*
         * 설정 화면에서 돌아왔을 때
         * Home 기념일 상태도 갱신
         */
              ref.invalidate(
                homeAnniversaryProvider,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          '기념일 추가',
        ),
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(
            MaterialPageRoute(
              builder: (_) => const AnniversaryCreatePage(),
            ),
          );
        },
      ),
      body: anniversariesAsync.when(
        data: (anniversaries) {
          if (anniversaries.isEmpty) {
            return const Center(
              child: Text(
                '등록된 기념일이 없습니다.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(
              16,
            ),
            itemCount: anniversaries.length,
            separatorBuilder: (
              context,
              index,
            ) =>
                const SizedBox(
              height: 8,
            ),
            itemBuilder: (
              context,
              index,
            ) {
              final anniversary = anniversaries[index];

              return _AnniversaryListCard(
                anniversary: anniversary,
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (
          error,
          stackTrace,
        ) =>
            Center(
          child: Text(
            '기념일을 불러오지 못했습니다.\n$error',
          ),
        ),
      ),
    );
  }
}

class _AnniversaryListCard extends ConsumerWidget {
  final Anniversary anniversary;

  const _AnniversaryListCard({
    required this.anniversary,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(
          anniversaryIcon(
            anniversary.type,
          ),
        ),
        title: Text(
          anniversary.title,
        ),
        subtitle: Text(
          '${anniversaryTypeLabel(anniversary)}'
          ' · '
          '${anniversary.anniversaryDate}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'edit':
                await Navigator.of(
                  context,
                ).push(
                  MaterialPageRoute(
                    builder: (_) => AnniversaryEditPage(
                      anniversary: anniversary,
                    ),
                  ),
                );

                break;

              case 'delete':
                await _deleteAnniversary(
                  context,
                  ref,
                );

                break;
            }
          },
          itemBuilder: (
            context,
          ) =>
              const [
            PopupMenuItem(
              value: 'edit',
              child: Text(
                '수정',
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                '삭제',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAnniversary(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            '기념일 삭제',
          ),
          content: Text(
            '"${anniversary.title}" 기념일을 삭제할까요?',
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
                '삭제',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final success = await ref
        .read(
          anniversaryManageProvider.notifier,
        )
        .deleteAnniversary(
          anniversaryId: anniversary.id,
        );

    if (!context.mounted) {
      return;
    }

    if (!success) {
      TopNotification.show(
        context,
        message: '기념일을 삭제하지 못했습니다.',
        type: TopNotificationType.error,
      );

      return;
    }

    TopNotification.show(
      context,
      message: '기념일이 삭제되었습니다.',
      type: TopNotificationType.success,
    );
  }
}

String _anniversaryTypeLabel(
  Anniversary anniversary,
) {
  switch (anniversary.type) {
    case 'COUPLE_START':
      return '커플 시작일';

    case 'BIRTHDAY':
      return '생일';

    case 'FIRST_DATE':
      return '첫 데이트';

    case 'TRAVEL':
      return '여행';

    case 'CUSTOM':
      final custom = anniversary.customTypeName;

      if (custom == null || custom.trim().isEmpty) {
        return '직접 지정';
      }

      return custom;

    default:
      return '기념일';
  }
}
