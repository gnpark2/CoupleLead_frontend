import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/top_notification.dart';
import '../data/model/anniversary.dart';
import 'anniversary_provider.dart';
import 'anniversary_ui_helper.dart';

class HomeAnniversarySelectionPage
    extends ConsumerStatefulWidget {
  const HomeAnniversarySelectionPage({
    super.key,
  });

  @override
  ConsumerState<HomeAnniversarySelectionPage>
      createState() =>
          _HomeAnniversarySelectionPageState();
}

class _HomeAnniversarySelectionPageState
    extends ConsumerState<
        HomeAnniversarySelectionPage> {
  /*
   * Home에 표시되는 기념일 ID.
   *
   * List 순서 자체가 Home 표시 순서가 된다.
   */
  final List<int> _selectedIds = [];

  bool _initialized = false;

  bool _saving = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    final anniversariesAsync = ref.watch(
      anniversaryListProvider,
    );

    final homeAnniversariesAsync = ref.watch(
      homeAnniversaryProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Home 기념일 설정',
        ),
      ),
      body: anniversariesAsync.when(
        data: (anniversaries) {
          return homeAnniversariesAsync.when(
            data: (homeAnniversaries) {
              /*
               * 최초 한 번만 서버에 저장된
               * Home 기념일 순서를 가져온다.
               */
              if (!_initialized) {
                _selectedIds.clear();

                _selectedIds.addAll(
                  homeAnniversaries.map(
                    (anniversary) =>
                        anniversary.id,
                  ),
                );

                _initialized = true;
              }

              return _buildContent(
                anniversaries,
              );
            },
            loading: () =>
                const Center(
              child:
                  CircularProgressIndicator(),
            ),
            error: (
              error,
              stackTrace,
            ) {
              return Center(
                child: Text(
                  'Home 기념일 설정을 불러오지 못했습니다.\n$error',
                  textAlign:
                      TextAlign.center,
                ),
              );
            },
          );
        },
        loading: () =>
            const Center(
          child:
              CircularProgressIndicator(),
        ),
        error: (
          error,
          stackTrace,
        ) {
          return Center(
            child: Text(
              '기념일을 불러오지 못했습니다.\n$error',
              textAlign:
                  TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    List<Anniversary> anniversaries,
  ) {
    /*
     * ID → Anniversary 형태로 변환.
     *
     * 선택된 ID 순서대로 Anniversary를
     * 빠르게 찾기 위해 사용한다.
     */
    final anniversaryMap = {
      for (final anniversary
          in anniversaries)
        anniversary.id: anniversary,
    };

    /*
     * 현재 Home에 선택된 기념일.
     *
     * _selectedIds 순서를 그대로 유지한다.
     */
    final selectedAnniversaries =
        _selectedIds
            .map(
              (id) =>
                  anniversaryMap[id],
            )
            .whereType<Anniversary>()
            .toList();

    /*
     * 선택되지 않은 기념일.
     */
    final unselectedAnniversaries =
        anniversaries
            .where(
              (anniversary) =>
                  !_selectedIds.contains(
                anniversary.id,
              ),
            )
            .toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding:
                const EdgeInsets.all(
              16,
            ),
            children: [
              /*
               * 설명
               */
              Text(
                'Home에 표시할 기념일',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium,
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                '선택된 기념일을 드래그해서 '
                'Home에 표시되는 순서를 변경할 수 있습니다.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall,
              ),

              const SizedBox(
                height: 16,
              ),

              /*
               * 선택된 기념일이 없는 경우
               */
              if (selectedAnniversaries
                  .isEmpty)
                const Card(
                  child: Padding(
                    padding:
                        EdgeInsets.all(
                      20,
                    ),
                    child: Center(
                      child: Text(
                        'Home에 표시할 기념일을 선택해주세요.',
                      ),
                    ),
                  ),
                ),

              /*
               * 선택된 기념일
               *
               * ReorderableListView를 사용한다.
               */
              if (selectedAnniversaries
                  .isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles:
                      false,
                  itemCount:
                      selectedAnniversaries
                          .length,
                  onReorder: (
                    oldIndex,
                    newIndex,
                  ) {
                    setState(() {
                      if (newIndex >
                          oldIndex) {
                        newIndex -= 1;
                      }

                      final id =
                          _selectedIds
                              .removeAt(
                        oldIndex,
                      );

                      _selectedIds.insert(
                        newIndex,
                        id,
                      );
                    });
                  },
                  itemBuilder: (
                    context,
                    index,
                  ) {
                    final anniversary =
                        selectedAnniversaries[
                            index];

                    return Card(
                      key: ValueKey(
                        anniversary.id,
                      ),
                      child: ListTile(
                        /*
                         * 드래그 핸들
                         */
                        leading:
                            ReorderableDragStartListener(
                          index: index,
                          child:
                              const Padding(
                            padding:
                                EdgeInsets
                                    .all(
                              8,
                            ),
                            child: Icon(
                              Icons
                                  .drag_handle,
                            ),
                          ),
                        ),

                        title: Row(
                          children: [
                            Icon(
                              anniversaryIcon(
                                anniversary
                                    .type,
                              ),
                              size: 20,
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            Expanded(
                              child: Text(
                                anniversary
                                    .title,
                              ),
                            ),
                          ],
                        ),

                        subtitle: Text(
                          '${anniversaryTypeLabel(anniversary)}'
                          ' · '
                          '${anniversary.anniversaryDate}',
                        ),

                        /*
                         * Home 표시에서 제거
                         */
                        trailing:
                            IconButton(
                          tooltip:
                              'Home에서 제거',
                          icon:
                              const Icon(
                            Icons
                                .close,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedIds
                                  .remove(
                                anniversary
                                    .id,
                              );
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(
                height: 28,
              ),

              /*
               * 선택되지 않은 기념일 영역
               */
              Row(
                children: [
                  Text(
                    '추가 가능한 기념일',
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .titleMedium,
                  ),

                  const Spacer(),

                  Text(
                    '${unselectedAnniversaries.length}개',
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              if (unselectedAnniversaries
                  .isEmpty)
                const Padding(
                  padding:
                      EdgeInsets.symmetric(
                    vertical: 20,
                  ),
                  child: Center(
                    child: Text(
                      '모든 기념일이 Home에 표시되고 있습니다.',
                    ),
                  ),
                ),

              for (final anniversary
                  in unselectedAnniversaries)
                Card(
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

                    trailing:
                        IconButton(
                      tooltip:
                          'Home에 추가',
                      icon:
                          const Icon(
                        Icons.add,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedIds.add(
                            anniversary.id,
                          );
                        });
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),

        /*
         * 저장 버튼
         */
        SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child: SizedBox(
              width:
                  double.infinity,
              child: FilledButton(
                onPressed:
                    _saving
                        ? null
                        : _save,
                child:
                    _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Text(
                            '저장',
                          ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    /*
     * 여기서 List의 순서 그대로
     * 서버에 전달된다.
     *
     * 예:
     *
     * _selectedIds = [5, 2, 7]
     *
     * →
     *
     * {
     *   "anniversaryIds": [5, 2, 7]
     * }
     */
    final success = await ref
        .read(
          homeAnniversarySelectionProvider
              .notifier,
        )
        .save(
          anniversaryIds:
              List<int>.from(
            _selectedIds,
          ),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });

    if (!success) {
      TopNotification.show(
        context,
        message:
            'Home 기념일 설정을 저장하지 못했습니다.',
        type:
            TopNotificationType.error,
      );

      return;
    }

    TopNotification.show(
      context,
      message:
          'Home 기념일 설정이 저장되었습니다.',
      type:
          TopNotificationType.success,
    );

    Navigator.of(
      context,
    ).pop();
  }
}