import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'overlay_anniversary_validator.dart';
import '../../anniversary/data/model/anniversary.dart';
import '../../anniversary/presentation/anniversary_provider.dart';
import 'overlay_provider.dart';

class OverlaySettingsPage extends ConsumerWidget {
  const OverlaySettingsPage({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final settingsAsync = ref.watch(
      overlaySettingsProvider,
    );

    final controller = ref.read(
      overlaySettingsProvider.notifier,
    );

    final anniversariesAsync = ref.watch(
      anniversaryListProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '오버레이 설정',
        ),
      ),
      body: settingsAsync.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            children: [
              const _SectionTitle(
                title: '기념일',
              ),
              SwitchListTile(
                title: const Text(
                  '기념일 표시',
                ),
                subtitle: const Text(
                  '선택한 기념일 하나를 오버레이에 표시합니다.',
                ),
                value: settings.showAnniversary,
                onChanged: (value) {
                  controller.setShowAnniversary(
                    value,
                  );
                },
              ),
              anniversariesAsync.when(
                data: (anniversaries) {
                  Anniversary? selectedAnniversary;

                  if (settings.anniversaryId != null) {
                    for (final anniversary in anniversaries) {
                      if (anniversary.id == settings.anniversaryId) {
                        selectedAnniversary = anniversary;

                        break;
                      }
                    }
                  }

                  return ListTile(
                    enabled: settings.showAnniversary,
                    leading: const Icon(
                      Icons.favorite_outline,
                    ),
                    title: const Text(
                      '표시할 기념일',
                    ),
                    subtitle: Text(
                      selectedAnniversary?.title ?? '기념일을 선택하세요',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: !settings.showAnniversary
                        ? null
                        : () {
                            _showAnniversaryPicker(
                              context: context,
                              anniversaries: anniversaries,
                              selectedId: settings.anniversaryId,
                              onSelected: (
                                anniversaryId,
                              ) {
                                controller.setAnniversary(
                                  anniversaryId,
                                );
                              },
                            );
                          },
                  );
                },
                loading: () => const ListTile(
                  leading: Icon(
                    Icons.favorite_outline,
                  ),
                  title: Text(
                    '표시할 기념일',
                  ),
                  subtitle: Text(
                    '기념일을 불러오는 중...',
                  ),
                ),
                error: (
                  error,
                  stackTrace,
                ) =>
                    const ListTile(
                  leading: Icon(
                    Icons.error_outline,
                  ),
                  title: Text(
                    '표시할 기념일',
                  ),
                  subtitle: Text(
                    '기념일을 불러오지 못했습니다.',
                  ),
                ),
              ),
              const Divider(),
              const _SectionTitle(
                title: '지역 시간',
              ),
              SwitchListTile(
                secondary: const Icon(
                  Icons.schedule,
                ),
                title: const Text(
                  '내 지역 시간',
                ),
                subtitle: const Text(
                  '내가 설정한 지역의 현재 시간을 표시합니다.',
                ),
                value: settings.showMyTime,
                onChanged: (value) {
                  controller.setShowMyTime(
                    value,
                  );
                },
              ),
              SwitchListTile(
                secondary: const Icon(
                  Icons.schedule_outlined,
                ),
                title: const Text(
                  '상대방 지역 시간',
                ),
                subtitle: const Text(
                  '상대방이 설정한 지역의 현재 시간을 표시합니다.',
                ),
                value: settings.showPartnerTime,
                onChanged: (value) {
                  controller.setShowPartnerTime(
                    value,
                  );
                },
              ),
              const Divider(),
              const _SectionTitle(
                title: '날씨',
              ),
              SwitchListTile(
                secondary: const Icon(
                  Icons.wb_sunny_outlined,
                ),
                title: const Text(
                  '내 날씨',
                ),
                subtitle: const Text(
                  '내 지역의 현재 날씨를 표시합니다.',
                ),
                value: settings.showMyWeather,
                onChanged: (value) {
                  controller.setShowMyWeather(
                    value,
                  );
                },
              ),
              SwitchListTile(
                secondary: const Icon(
                  Icons.cloud_outlined,
                ),
                title: const Text(
                  '상대방 날씨',
                ),
                subtitle: const Text(
                  '상대방 지역의 현재 날씨를 표시합니다.',
                ),
                value: settings.showPartnerWeather,
                onChanged: (value) {
                  controller.setShowPartnerWeather(
                    value,
                  );
                },
              ),
              const SizedBox(
                height: 24,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: Text(
                  '오버레이 설정은 현재 실행 중인 앱에서 즉시 반영됩니다.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (
          error,
          stackTrace,
        ) {
          return Center(
            child: Text(
              '오버레이 설정을 불러오지 못했습니다.\n$error',
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  void _showAnniversaryPicker({
    required BuildContext context,
    required List<Anniversary> anniversaries,
    required int? selectedId,
    required void Function(int) onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (
        bottomSheetContext,
      ) {
        return SafeArea(
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(
                    16,
                  ),
                  child: Text(
                    '표시할 기념일 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                ),
                Expanded(
                  child: anniversaries.isEmpty
                      ? const Center(
                          child: Text(
                            '등록된 기념일이 없습니다.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: anniversaries.length,
                          itemBuilder: (
                            context,
                            index,
                          ) {
                            final anniversary = anniversaries[index];

                            final selected = anniversary.id == selectedId;

                            return ListTile(
                              leading: Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              title: Text(
                                anniversary.title,
                              ),
                              subtitle: Text(
                                anniversary.anniversaryDate,
                              ),
                              trailing: selected
                                  ? const Icon(
                                      Icons.check,
                                    )
                                  : null,
                              onTap: () {
                                onSelected(
                                  anniversary.id,
                                );

                                Navigator.of(
                                  bottomSheetContext,
                                ).pop();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        6,
      ),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
