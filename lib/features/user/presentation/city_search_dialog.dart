import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/city_search_result.dart';
import 'user_provider.dart';

class CitySearchDialog extends ConsumerStatefulWidget {
  const CitySearchDialog({
    super.key,
  });

  @override
  ConsumerState<CitySearchDialog> createState() => _CitySearchDialogState();
}

class _CitySearchDialogState extends ConsumerState<CitySearchDialog> {
  final _controller = TextEditingController();

  String _query = '';

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();

    _controller.dispose();

    super.dispose();
  }

  void _onChanged(
    String value,
  ) {
    _debounce?.cancel();

    /*
     * 글자 입력마다 API를 호출하지 않고
     * 400ms 동안 입력이 멈췄을 때 검색한다.
     */
    _debounce = Timer(
      const Duration(
        milliseconds: 400,
      ),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          _query = value.trim();
        });
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final searchAsync = ref.watch(
      citySearchProvider(
        _query,
      ),
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 650,
        ),
        child: Padding(
          padding: const EdgeInsets.all(
            20,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '다른 도시 선택',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    icon: const Icon(
                      Icons.close,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 16,
              ),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  hintText: '도시 검색 (예: Tokyo, New York, London)',
                  prefixIcon: Icon(
                    Icons.search,
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              Expanded(
                child: _buildResults(
                  searchAsync,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(
    AsyncValue<List<CitySearchResult>> searchAsync,
  ) {
    if (_query.length < 2) {
      return const Center(
        child: Text(
          '도시 이름을 입력해주세요.',
        ),
      );
    }

    return searchAsync.when(
      loading: () {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
      error: (
        error,
        stackTrace,
      ) {
        return const Center(
          child: Text(
            '도시 검색에 실패했습니다.',
          ),
        );
      },
      data: (
        results,
      ) {
        if (results.isEmpty) {
          return const Center(
            child: Text(
              '검색 결과가 없습니다.',
            ),
          );
        }

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (
            context,
            index,
          ) {
            return const Divider(
              height: 1,
            );
          },
          itemBuilder: (
            context,
            index,
          ) {
            final city = results[index];

            return ListTile(
              leading: const Icon(
                Icons.location_city,
              ),
              title: Text(
                city.name,
              ),
              subtitle: Text(
                '${city.displayName}\n'
                '${city.timezone}',
              ),
              isThreeLine: true,
              onTap: () {
                Navigator.of(
                  context,
                ).pop(
                  city,
                );
              },
            );
          },
        );
      },
    );
  }
}
