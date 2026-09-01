import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/model/anniversary.dart';
import '../data/model/update_anniversary_request.dart';
import 'anniversary_provider.dart';
import '../../../core/ui/top_notification.dart';

class AnniversaryEditPage extends ConsumerStatefulWidget {
  final Anniversary anniversary;

  const AnniversaryEditPage({
    super.key,
    required this.anniversary,
  });

  @override
  ConsumerState<AnniversaryEditPage> createState() =>
      _AnniversaryEditPageState();
}

class _AnniversaryEditPageState extends ConsumerState<AnniversaryEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;

  late final TextEditingController _customTypeController;

  late DateTime _selectedDate;

  late String _type;

  late String _repeatType;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.anniversary.title,
    );

    _customTypeController = TextEditingController(
      text: widget.anniversary.customTypeName ?? '',
    );

    _selectedDate = DateTime.parse(
      widget.anniversary.anniversaryDate,
    );

    _type = widget.anniversary.type;

    _repeatType = widget.anniversary.repeatType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customTypeController.dispose();

    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
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

    setState(() {
      _submitting = true;
    });

    final dateString = '${_selectedDate.year.toString().padLeft(4, '0')}-'
        '${_selectedDate.month.toString().padLeft(2, '0')}-'
        '${_selectedDate.day.toString().padLeft(2, '0')}';

    final success = await ref
        .read(
          anniversaryManageProvider.notifier,
        )
        .updateAnniversary(
            anniversaryId: widget.anniversary.id,
            request: UpdateAnniversaryRequest(
              title: _titleController.text.trim(),
              anniversaryDate: dateString,
              type: _type,
              repeatType: _repeatType,
              customTypeName:
                  _type == 'CUSTOM' ? _customTypeController.text.trim() : null,
            ));

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (!success) {
      TopNotification.show(
        context,
        message: '기념일을 수정하지 못했습니다.',
        type: TopNotificationType.error,
      );

      return;
    }

    TopNotification.show(
      context,
      message: '기념일이 수정되었습니다.',
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
          '기념일 수정',
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
                border: OutlineInputBorder(),
              ),
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
                '${_selectedDate.year}-'
                '${_selectedDate.month.toString().padLeft(2, '0')}-'
                '${_selectedDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: _selectDate,
            ),
            const SizedBox(
              height: 16,
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
                  child: Text(
                    '커플 시작일',
                  ),
                ),
                DropdownMenuItem(
                  value: 'BIRTHDAY',
                  child: Text(
                    '생일',
                  ),
                ),
                DropdownMenuItem(
                  value: 'FIRST_DATE',
                  child: Text(
                    '첫 데이트',
                  ),
                ),
                DropdownMenuItem(
                  value: 'TRAVEL',
                  child: Text(
                    '여행',
                  ),
                ),
                DropdownMenuItem(
                  value: 'CUSTOM',
                  child: Text(
                    '직접 지정',
                  ),
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
                      '수정 완료',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
