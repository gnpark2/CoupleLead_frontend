import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/top_notification.dart';
import '../data/model/create_anniversary_request.dart';
import 'anniversary_provider.dart';

class AnniversaryCreatePage extends ConsumerStatefulWidget {
  const AnniversaryCreatePage({
    super.key,
  });

  @override
  ConsumerState<AnniversaryCreatePage> createState() =>
      _AnniversaryCreatePageState();
}

class _AnniversaryCreatePageState extends ConsumerState<AnniversaryCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();

  final _customTypeController = TextEditingController();

  DateTime? _selectedDate;

  String _type = 'CUSTOM';

  String _repeatType = 'NONE';

  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _customTypeController.dispose();

    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(
        1900,
      ),
      lastDate: DateTime(
        2100,
      ),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedDate = selected;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedDate == null) {
      TopNotification.show(
        context,
        message: '기념일 날짜를 선택해주세요.',
        type: TopNotificationType.info,
      );

      return;
    }

    setState(() {
      _submitting = true;
    });

    final selectedDate = _selectedDate!;

    final dateString = '${selectedDate.year.toString().padLeft(4, '0')}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';

    /*
   * 바로 여기에 넣는다.
   */
    final request = CreateAnniversaryRequest(
      title: _titleController.text.trim(),
      anniversaryDate: dateString,
      type: _type,
      repeatType: _repeatType,
      customTypeName:
          _type == 'CUSTOM' ? _customTypeController.text.trim() : null,
    );

    final success = await ref
        .read(
          anniversaryCreateProvider.notifier,
        )
        .create(
          request: request,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (!success) {
      TopNotification.show(
        context,
        message: '기념일을 추가하지 못했습니다.',
        type: TopNotificationType.error,
      );

      return;
    }

    TopNotification.show(
      context,
      message: '기념일이 추가되었습니다.',
      type: TopNotificationType.success,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '기념일 추가',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(
            20,
          ),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '기념일 이름',
                hintText: '예: 처음 만난 날',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '기념일 이름을 입력해주세요.';
                }

                return null;
              },
            ),
            const SizedBox(
              height: 16,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.calendar_month,
              ),
              title: const Text(
                '기념일 날짜',
              ),
              subtitle: Text(
                _selectedDate == null
                    ? '날짜를 선택해주세요.'
                    : _formatDate(
                        _selectedDate!,
                      ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: _selectDate,
            ),
            const Divider(),
            const SizedBox(
              height: 12,
            ),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: '기념일 종류',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'COUPLE_START',
                  child: Text('커플 시작일'),
                ),
                DropdownMenuItem(
                  value: 'BIRTHDAY',
                  child: Text('생일'),
                ),
                DropdownMenuItem(
                  value: 'FIRST_DATE',
                  child: Text('첫 데이트'),
                ),
                DropdownMenuItem(
                  value: 'TRAVEL',
                  child: Text('여행'),
                ),
                DropdownMenuItem(
                  value: 'CUSTOM',
                  child: Text('직접 지정'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _type = value;
                });
              },
            ),
            if (_type == 'CUSTOM') ...[
              const SizedBox(
                height: 16,
              ),
              TextFormField(
                controller: _customTypeController,
                decoration: const InputDecoration(
                  labelText: '직접 지정 종류',
                  hintText: '예: 약혼, 첫 콘서트, 입학식',
                  border: OutlineInputBorder(),
                ),
                maxLength: 30,
                validator: (value) {
                  if (_type == 'CUSTOM' &&
                      (value == null || value.trim().isEmpty)) {
                    return '기념일 종류를 입력해주세요.';
                  }

                  return null;
                },
              ),
            ],
            const SizedBox(
              height: 16,
            ),
            DropdownButtonFormField<String>(
              initialValue: _repeatType,
              decoration: const InputDecoration(
                labelText: '반복',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'NONE',
                  child: Text(
                    '반복 없음',
                  ),
                ),
                DropdownMenuItem(
                  value: 'YEARLY',
                  child: Text(
                    '매년',
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _repeatType = value;
                });
              },
            ),
            const SizedBox(
              height: 32,
            ),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '기념일 추가',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(
    DateTime date,
  ) {
    return '${date.year}. '
        '${date.month.toString().padLeft(2, '0')}. '
        '${date.day.toString().padLeft(2, '0')}';
  }
}
