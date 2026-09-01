import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/top_notification.dart';
import 'auth_provider.dart';
import 'signup_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({
    super.key,
  });

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  bool _hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();

    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      TopNotification.show(
        context,
        message: '이메일과 비밀번호를 입력해주세요.',
        type: TopNotificationType.info,
      );

      return;
    }

    final success = await ref
        .read(
          authControllerProvider.notifier,
        )
        .login(
          email: email,
          password: password,
        );

    if (!mounted) {
      return;
    }

    if (!success) {
      TopNotification.show(
        context,
        message: '로그인에 실패했습니다.',
        type: TopNotificationType.error,
      );
      return;
    }

    context.go('/gateway');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    final loading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Couplead 로그인',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
            ),
            child: Column(
              children: [
                TextField(
                  controller: emailController,
                  enabled: !loading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                TextField(
                  controller: passwordController,
                  enabled: !loading,
                  obscureText: _hidePassword,
                  onSubmitted: (_) {
                    if (!loading) {
                      login();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _hidePassword ? '비밀번호 보기' : '비밀번호 숨기기',
                      onPressed: loading
                          ? null
                          : () {
                              setState(() {
                                _hidePassword = !_hidePassword;
                              });
                            },
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 24,
                ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '로그인',
                          ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.of(
                      context,
                    ).push(
                      MaterialPageRoute(
                        builder: (_) => const SignupPage(),
                      ),
                    );
                  },
                  child: const Text(
                    '계정이 없나요? 회원가입',
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
