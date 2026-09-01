import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/top_notification.dart';
import '../data/model/signup_request.dart';
import 'auth_provider.dart';

class SignupPage
    extends ConsumerStatefulWidget {
  const SignupPage({
    super.key,
  });

  @override
  ConsumerState<SignupPage>
      createState() =>
          _SignupPageState();
}

class _SignupPageState
    extends ConsumerState<SignupPage> {
  final _formKey =
      GlobalKey<FormState>();

  final _emailController =
      TextEditingController();

  final _nicknameController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  final _passwordConfirmController =
      TextEditingController();

  bool _submitting = false;

  bool _hidePassword = true;

  bool _hidePasswordConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    final valid =
        _formKey.currentState
                ?.validate() ??
            false;

    if (!valid) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final request =
        SignupRequest(
      email:
          _emailController.text
              .trim(),
      nickname:
          _nicknameController.text
              .trim(),
      password:
          _passwordController.text,
    );

    final success = await ref
        .read(
          signupProvider.notifier,
        )
        .signup(
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
        message:
            '회원가입에 실패했습니다.',
        type:
            TopNotificationType.error,
      );

      return;
    }

    TopNotification.show(
      context,
      message:
          '회원가입이 완료되었습니다.',
      type:
          TopNotificationType.success,
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
          '회원가입',
        ),
      ),

      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(
            24,
          ),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 420,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  const Icon(
                    Icons.favorite,
                    size: 56,
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Text(
                    'Couplead',
                    textAlign:
                        TextAlign.center,
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    '새 계정을 만들어보세요.',
                    textAlign:
                        TextAlign.center,
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .bodyMedium,
                  ),

                  const SizedBox(
                    height: 32,
                  ),

                  /*
                   * 이메일
                   */
                  TextFormField(
                    controller:
                        _emailController,
                    keyboardType:
                        TextInputType
                            .emailAddress,
                    autofillHints:
                        const [
                      AutofillHints.email,
                    ],
                    decoration:
                        const InputDecoration(
                      labelText: '이메일',
                      prefixIcon:
                          Icon(
                        Icons.email_outlined,
                      ),
                      border:
                          OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text =
                          value?.trim() ??
                              '';

                      if (text.isEmpty) {
                        return '이메일을 입력해주세요.';
                      }

                      final emailRegex =
                          RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      );

                      if (!emailRegex
                          .hasMatch(
                        text,
                      )) {
                        return '올바른 이메일 형식을 입력해주세요.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  /*
                   * 닉네임
                   */
                  TextFormField(
                    controller:
                        _nicknameController,
                    decoration:
                        const InputDecoration(
                      labelText: '닉네임',
                      prefixIcon:
                          Icon(
                        Icons.person_outline,
                      ),
                      border:
                          OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text =
                          value?.trim() ??
                              '';

                      if (text.isEmpty) {
                        return '닉네임을 입력해주세요.';
                      }

                      if (text.length < 2) {
                        return '닉네임은 2자 이상 입력해주세요.';
                      }

                      if (text.length > 20) {
                        return '닉네임은 20자 이하로 입력해주세요.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  /*
                   * 비밀번호
                   */
                  TextFormField(
                    controller:
                        _passwordController,
                    obscureText:
                        _hidePassword,
                    autofillHints:
                        const [
                      AutofillHints
                          .newPassword,
                    ],
                    decoration:
                        InputDecoration(
                      labelText: '비밀번호',
                      prefixIcon:
                          const Icon(
                        Icons.lock_outline,
                      ),
                      border:
                          const OutlineInputBorder(),
                      suffixIcon:
                          IconButton(
                        onPressed: () {
                          setState(() {
                            _hidePassword =
                                !_hidePassword;
                          });
                        },
                        icon: Icon(
                          _hidePassword
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return '비밀번호를 입력해주세요.';
                      }

                      if (value.length < 8) {
                        return '비밀번호는 8자 이상 입력해주세요.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  /*
                   * 비밀번호 확인
                   */
                  TextFormField(
                    controller:
                        _passwordConfirmController,
                    obscureText:
                        _hidePasswordConfirm,
                    decoration:
                        InputDecoration(
                      labelText:
                          '비밀번호 확인',
                      prefixIcon:
                          const Icon(
                        Icons.lock_outline,
                      ),
                      border:
                          const OutlineInputBorder(),
                      suffixIcon:
                          IconButton(
                        onPressed: () {
                          setState(() {
                            _hidePasswordConfirm =
                                !_hidePasswordConfirm;
                          });
                        },
                        icon: Icon(
                          _hidePasswordConfirm
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return '비밀번호를 다시 입력해주세요.';
                      }

                      if (value !=
                          _passwordController
                              .text) {
                        return '비밀번호가 일치하지 않습니다.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  FilledButton(
                    onPressed:
                        _submitting
                            ? null
                            : _submit,
                    child:
                        _submitting
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
                                '회원가입',
                              ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  TextButton(
                    onPressed:
                        _submitting
                            ? null
                            : () {
                                Navigator.of(
                                  context,
                                ).pop();
                              },
                    child: const Text(
                      '이미 계정이 있나요? 로그인',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}