import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_provider.dart';
import 'user_provider.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({
    super.key,
  });

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();

  final _newPasswordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();

  bool _currentPasswordVisible = false;

  bool _newPasswordVisible = false;

  bool _confirmPasswordVisible = false;

  bool _loading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();

    _newPasswordController.dispose();

    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_loading) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final currentPassword = _currentPasswordController.text.trim();

    final newPassword = _newPasswordController.text.trim();

    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '새 비밀번호가 일치하지 않습니다.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      /*
       * 서버 비밀번호 변경
       */
      await ref
          .read(
            userApiProvider,
          )
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );

      /*
       * 서버에서는 Refresh Token이
       * 이미 삭제된 상태.
       *
       * Flutter의 로컬 인증 정보도 제거한다.
       */
      await ref
          .read(
            authControllerProvider.notifier,
          )
          .logoutLocal();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '비밀번호가 변경되었습니다. 다시 로그인해주세요.',
          ),
        ),
      );

      context.go(
        '/login',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _resolveErrorMessage(
              error,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _resolveErrorMessage(
    Object error,
  ) {
    /*
     * 우선 기본 처리.
     *
     * DioException을 공통 예외로
     * 변환하는 코드가 이미 있다면
     * 그 방식을 사용하면 된다.
     */
    final message = error.toString();

    if (message.contains(
      'INVALID_PASSWORD',
    )) {
      return '현재 비밀번호가 일치하지 않습니다.';
    }

    if (message.contains(
      'SAME_PASSWORD',
    )) {
      return '새 비밀번호는 기존 비밀번호와 달라야 합니다.';
    }

    return '비밀번호 변경에 실패했습니다.';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '비밀번호 변경',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(
            24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /*
                 * 현재 비밀번호
                 */
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: !_currentPasswordVisible,
                  autofillHints: const [
                    AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: '현재 비밀번호',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _currentPasswordVisible = !_currentPasswordVisible;
                        });
                      },
                      icon: Icon(
                        _currentPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (
                    value,
                  ) {
                    if (value == null || value.trim().isEmpty) {
                      return '현재 비밀번호를 입력해주세요.';
                    }

                    return null;
                  },
                ),
                const SizedBox(
                  height: 16,
                ),

                /*
                 * 새 비밀번호
                 */
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_newPasswordVisible,
                  autofillHints: const [
                    AutofillHints.newPassword,
                  ],
                  decoration: InputDecoration(
                    labelText: '새 비밀번호',
                    prefixIcon: const Icon(
                      Icons.lock_reset_outlined,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _newPasswordVisible = !_newPasswordVisible;
                        });
                      },
                      icon: Icon(
                        _newPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (
                    value,
                  ) {
                    if (value == null || value.trim().isEmpty) {
                      return '새 비밀번호를 입력해주세요.';
                    }

                    if (value.trim().length < 8) {
                      return '비밀번호는 8자 이상 입력해주세요.';
                    }

                    return null;
                  },
                ),
                const SizedBox(
                  height: 16,
                ),

                /*
                 * 새 비밀번호 확인
                 */
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_confirmPasswordVisible,
                  autofillHints: const [
                    AutofillHints.newPassword,
                  ],
                  decoration: InputDecoration(
                    labelText: '새 비밀번호 확인',
                    prefixIcon: const Icon(
                      Icons.lock_reset_outlined,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _confirmPasswordVisible = !_confirmPasswordVisible;
                        });
                      },
                      icon: Icon(
                        _confirmPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (
                    value,
                  ) {
                    if (value == null || value.trim().isEmpty) {
                      return '새 비밀번호를 한 번 더 입력해주세요.';
                    }

                    if (value.trim() != _newPasswordController.text.trim()) {
                      return '새 비밀번호가 일치하지 않습니다.';
                    }

                    return null;
                  },
                ),
                const SizedBox(
                  height: 32,
                ),
                FilledButton(
                  onPressed: _loading ? null : _changePassword,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '비밀번호 변경',
                          ),
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
