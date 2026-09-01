import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

class ChatNotificationWindow extends StatefulWidget {
  final WindowController controller;

  final String mainWindowId;

  const ChatNotificationWindow({
    super.key,
    required this.controller,
    required this.mainWindowId,
  });

  @override
  State<ChatNotificationWindow> createState() => _ChatNotificationWindowState();
}

class _ChatNotificationWindowState extends State<ChatNotificationWindow> {
  static const _windowSize = Size(
    380,
    116,
  );

  Timer? _hideTimer;

  String _nickname = 'Couplead';

  String _message = '새 메시지가 도착했습니다.';

  String? _profileImage;

  bool _soundEnabled = true;

  int? _coupleId;

  int? _partnerId;

  bool _notificationVisible = false;

  bool _windowVisible = false;

  int _messageCount = 1;

  int? _previousCoupleId;

  final AudioPlayer _audioPlayer = AudioPlayer();

  final TokenStorage _tokenStorage = TokenStorage();

  String? _accessToken;

  @override
  void initState() {
    super.initState();

    _loadAccessToken();

    widget.controller.setWindowMethodHandler(
      (call) async {
        if (call.method != 'showChatNotification') {
          return null;
        }

        final arguments = Map<String, dynamic>.from(
          call.arguments as Map,
        );

        if (!mounted) {
          return null;
        }

        final newCoupleId = (arguments['coupleId'] as num?)?.toInt();

        setState(
          () {
            /*
     * 같은 채팅방에서 알림창이 떠 있는 동안
     * 메시지가 또 오면 개수 증가
     */
            if (_windowVisible && _previousCoupleId == newCoupleId) {
              _messageCount++;
            } else {
              _messageCount = 1;
            }

            _coupleId = newCoupleId;

            _previousCoupleId = newCoupleId;

            _partnerId = (arguments['partnerId'] as num?)?.toInt();

            _nickname = arguments['nickname']?.toString() ?? 'Couplead';

            _message = arguments['message']?.toString() ?? '새 메시지가 도착했습니다.';

            _profileImage = arguments['profileImage']?.toString();

            _soundEnabled = arguments['soundEnabled'] as bool? ?? true;
          },
        );

        await _showNotification();

        return null;
      },
    );
  }

  Future<void> _loadAccessToken() async {
    final token = await _tokenStorage.getAccessToken();

    if (!mounted) {
      return;
    }

    setState(
      () {
        _accessToken = token;
      },
    );
  }

  Future<void> _showNotification() async {
    _hideTimer?.cancel();

    /*
   * 처음 표시될 때만
   * Window 크기/위치/show 처리
   */
    if (!_windowVisible) {
      final basePosition = await calcWindowPosition(
        _windowSize,
        Alignment.bottomRight,
      );

      final position = Offset(
        basePosition.dx - 20,
        basePosition.dy - 20,
      );

      await windowManager.setSize(
        _windowSize,
      );

      await windowManager.setPosition(
        position,
      );

      await windowManager.setAlwaysOnTop(
        true,
      );

      await windowManager.setSkipTaskbar(
        true,
      );

      await windowManager.show();

      await windowManager.focus();

      _windowVisible = true;

      /*
     * Window가 먼저 나타난 다음
     * 카드 애니메이션 시작
     */
      if (mounted) {
        setState(
          () {
            _notificationVisible = false;
          },
        );
      }

      await Future<void>.delayed(
        const Duration(
          milliseconds: 20,
        ),
      );

      if (mounted) {
        setState(
          () {
            _notificationVisible = true;
          },
        );
      }
    }

    /*
   * 소리
   */
    if (_soundEnabled) {
      try {
        await _audioPlayer.stop();

        await _audioPlayer.play(
          AssetSource(
            'sounds/couplead_message.wav',
          ),
        );
      } catch (e) {
        debugPrint(
          '[CHAT NOTIFICATION SOUND ERROR] '
          '$e',
        );
      }
    }

    /*
   * 새로운 메시지가 올 때마다
   * 다시 5초부터 시작
   */
    _hideTimer = Timer(
      const Duration(
        seconds: 5,
      ),
      () {
        _hide();
      },
    );
  }

  Future<void> _hide() async {
    _hideTimer?.cancel();
    _hideTimer = null;

    if (!_windowVisible) {
      return;
    }

    if (mounted) {
      setState(
        () {
          _notificationVisible = false;
        },
      );
    }

    /*
   * 퇴장 애니메이션 대기
   */
    await Future<void>.delayed(
      const Duration(
        milliseconds: 220,
      ),
    );

    await windowManager.hide();

    _windowVisible = false;

    if (mounted) {
      setState(
        () {
          _messageCount = 1;
        },
      );
    }
  }

  Future<void> _openChat() async {
    final coupleId = _coupleId;

    final partnerId = _partnerId;

    if (coupleId == null || partnerId == null) {
      return;
    }

    /*
   * 먼저 Notification Window 숨김
   */
    await _hide();

    try {
      /*
     * 메인 Couplead Window 가져오기
     */
      final mainWindow = WindowController.fromWindowId(
        widget.mainWindowId,
      );

      /*
     * 메인 Window에
     * 채팅 열기 요청
     */
      await mainWindow.invokeMethod(
        'openChatFromNotification',
        {
          'coupleId': coupleId,
          'partnerId': partnerId,
          'partnerNickname': _nickname,
          'partnerProfileImage': _profileImage,
        },
      );
    } catch (e) {
      debugPrint(
        '[CHAT NOTIFICATION CLICK ERROR] '
        '$e',
      );
    }
  }

  String? _resolveProfileImageUrl(
    String? image,
  ) {
    if (image == null || image.isEmpty) {
      return null;
    }

    if (image.startsWith(
          'http://',
        ) ||
        image.startsWith(
          'https://',
        )) {
      return image;
    }

    final baseUrl = ApiConstants.baseUrl.replaceFirst(
      RegExp(r'/$'),
      '',
    );

    if (image.startsWith('/')) {
      return '$baseUrl$image';
    }

    return '$baseUrl/$image';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();

    _audioPlayer.dispose();

    widget.controller.setWindowMethodHandler(
      null,
    );

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(
            8,
          ),
          child: AnimatedSlide(
            offset: _notificationVisible
                ? Offset.zero
                : const Offset(
                    0.15,
                    0,
                  ),
            duration: const Duration(
              milliseconds: 220,
            ),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _notificationVisible ? 1 : 0,
              duration: const Duration(
                milliseconds: 180,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openChat,
                  borderRadius: BorderRadius.circular(
                    18,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(
                        18,
                      ),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 18,
                          offset: Offset(
                            0,
                            6,
                          ),
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      14,
                      12,
                      8,
                      12,
                    ),
                    child: Row(
                      children: [
                        _Profile(
                          profileImage: _resolveProfileImageUrl(
                            _profileImage,
                          ),
                          nickname: _nickname,
                          accessToken: _accessToken,
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  Text(
                                    'Couplead',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                  if (_messageCount > 1) ...[
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(
                                          10,
                                        ),
                                      ),
                                      child: Text(
                                        '$_messageCount',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                _nickname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(
                                height: 2,
                              ),
                              Text(
                                _message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '알림 닫기',
                          onPressed: _hide,
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  final String? profileImage;

  final String nickname;

  final String? accessToken;

  const _Profile({
    required this.profileImage,
    required this.nickname,
    required this.accessToken,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final imageUrl = profileImage;

    /*
     * 이미지가 없으면
     * 닉네임 첫 글자 표시
     */
    if (imageUrl == null || imageUrl.isEmpty) {
      return _FallbackProfile(
        nickname: nickname,
      );
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        headers: accessToken == null
            ? null
            : {
                'Authorization': 'Bearer $accessToken',
              },

        /*
         * 이미지 로딩 중
         */
        loadingBuilder: (
          context,
          child,
          loadingProgress,
        ) {
          if (loadingProgress == null) {
            return child;
          }

          return SizedBox(
            width: 46,
            height: 46,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        },

        /*
         * 401 / 404 등 실패하면
         * 닉네임 fallback
         */
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          debugPrint(
            '[CHAT NOTIFICATION PROFILE ERROR] '
            '$error',
          );

          return _FallbackProfile(
            nickname: nickname,
          );
        },
      ),
    );
  }
}

class _FallbackProfile extends StatelessWidget {
  final String nickname;

  const _FallbackProfile({
    required this.nickname,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return CircleAvatar(
      radius: 23,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primaryContainer,
      child: Text(
        nickname.isEmpty ? '?' : nickname[0].toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(
                context,
              ).colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }
}
