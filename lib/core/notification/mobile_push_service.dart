import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_visibility_service.dart';
import '../../features/device/data/device_api.dart';
import '../../features/device/presentation/device_provider.dart';
import '../navigation/app_navigator.dart';
import 'local_notification_service.dart';

class MobilePushService {
  MobilePushService._();

  static final instance = MobilePushService._();

  String? _pendingNavigationLocation;

  StreamSubscription<String>? _tokenRefreshSubscription;

  final StreamController<RemoteMessage> _foregroundMessageController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get foregroundMessages =>
      _foregroundMessageController.stream;

  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    /*
   * ==================================
   * Foreground FCM
   * ==================================
   *
   * Foreground에서는 기존 STOMP가
   * 채팅 realtime을 담당하므로
   * OS notification을 따로 만들지 않는다.
   */
    FirebaseMessaging.onMessage.listen(
      (
        message,
      ) async {
        debugPrint(
          '[FCM FOREGROUND] '
          'messageId=${message.messageId}',
        );

        debugPrint(
          '[FCM FOREGROUND] '
          'data=${message.data}',
        );

        final data = message.data;

        /*
     * 채팅 Push만 처리
     */
        if (data['type'] != 'CHAT_MESSAGE') {
          return;
        }

        final coupleId = int.tryParse(
          data['coupleId']?.toString() ?? '',
        );

        final senderId = int.tryParse(
          data['senderId']?.toString() ?? '',
        );

        if (coupleId == null || senderId == null) {
          debugPrint(
            '[FCM FOREGROUND] '
            'INVALID CHAT DATA',
          );

          return;
        }

        /*
     * ======================================
     * 현재 이 채팅방을 직접 보고 있는지 확인
     * ======================================
     */
        final currentChatCoupleId = ChatVisibilityService.currentCoupleId;

        debugPrint(
          '[FCM FOREGROUND] '
          'currentChatCoupleId='
          '$currentChatCoupleId '
          'incomingCoupleId=$coupleId',
        );

        /*
     * 현재 같은 채팅방을 보고 있다면
     * STOMP로 메시지가 바로 표시되므로
     * Android 알림은 띄우지 않는다.
     */
        if (currentChatCoupleId == coupleId) {
          debugPrint(
            '[FCM FOREGROUND] '
            'SKIP - 현재 채팅방 보는 중',
          );

          return;
        }

        /*
     * ======================================
     * FCM notification의 title / body 사용
     * ======================================
     *
     * Backend data에는 현재
     * senderNickname/message가 없으므로
     * message.notification에서 가져온다.
     */
        final nickname = message.notification?.title ?? '상대방';

        final body = message.notification?.body ?? '새 메시지가 도착했습니다.';

        /*
     * ======================================
     * Android foreground local notification
     * ======================================
     */
        await LocalNotificationService.instance.showAndroidChatNotification(
          nickname: nickname,
          message: body,
          coupleId: coupleId,
          senderId: senderId,

          /*
       * 우선 true.
       *
       * notificationSettingsProvider의
       * soundEnabled까지 연결하는 것은
       * 다음 리팩터링에서 Riverpod 계층으로
       * 옮겨서 처리할 수 있다.
       */
          soundEnabled: true,
        );

        debugPrint(
          '[FCM FOREGROUND] '
          'LOCAL NOTIFICATION SHOW '
          'coupleId=$coupleId '
          'senderId=$senderId',
        );
      },
    );

    /*
   * ==================================
   * Background → 알림 클릭
   * ==================================
   */
    FirebaseMessaging.onMessageOpenedApp.listen(
      (
        message,
      ) {
        debugPrint(
          '[FCM CLICK] '
          'BACKGROUND → APP',
        );

        _queueNavigation(
          message,
        );

        /*
       * 이미 로그인해서 앱이 살아있다면
       * 바로 이동 가능.
       */
        openPendingNavigation();
      },
    );

    /*
   * ==================================
   * Terminated → 알림 클릭
   * ==================================
   */
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      debugPrint(
        '[FCM CLICK] '
        'TERMINATED → APP',
      );

      /*
     * 여기서는 바로 Navigator를
     * 사용하지 않는다.
     *
     * 아직 Splash/Auth restore 중일 수 있음.
     */
      _queueNavigation(
        initialMessage,
      );
    }
  }

  void _queueNavigation(
    RemoteMessage message,
  ) {
    final data = message.data;

    debugPrint(
      '[FCM CLICK] '
      'data=$data',
    );

    final type = data['type']?.toString();

    if (type != 'CHAT_MESSAGE') {
      debugPrint(
        '[FCM CLICK] '
        '지원하지 않는 type=$type',
      );

      return;
    }

    final coupleId = int.tryParse(
      data['coupleId']?.toString() ?? '',
    );

    final senderId = int.tryParse(
      data['senderId']?.toString() ?? '',
    );

    final senderNickname = data['senderNickname']?.toString() ?? '상대방';

    if (coupleId == null || senderId == null) {
      debugPrint(
        '[FCM CLICK] '
        '잘못된 payload '
        'coupleId=$coupleId '
        'senderId=$senderId',
      );

      return;
    }

    final encodedNickname = Uri.encodeComponent(
      senderNickname,
    );

    _pendingNavigationLocation = '/chat/$coupleId'
        '?partnerId=$senderId'
        '&partnerNickname=$encodedNickname';

    debugPrint(
      '[FCM CLICK] '
      'PENDING '
      '$_pendingNavigationLocation',
    );
  }

  void openPendingNavigation() {
    final location = _pendingNavigationLocation;

    if (location == null) {
      return;
    }

    final context = rootNavigatorKey.currentContext;

    if (context == null) {
      debugPrint(
        '[FCM CLICK] '
        'Navigator 준비 안 됨 '
        '→ pending 유지',
      );

      return;
    }

    /*
   * 먼저 null로 만들어
   * 중복 navigation 방지
   */
    _pendingNavigationLocation = null;

    debugPrint(
      '[FCM CLICK] '
      'OPEN $location',
    );

    context.push(
      location,
    );
  }

  Future<void> registerMobileDevice(
    DeviceApi api,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    try {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint(
        '[FCM] permission='
        '${permission.authorizationStatus}',
      );

      final fid = await FirebaseInstallations.instance.getId();

      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken == null) {
        debugPrint(
          '[FCM] TOKEN IS NULL',
        );

        return;
      }

      debugPrint(
        '[FCM] REGISTER '
        'fid=$fid '
        'tokenPresent=true',
      );

      await api.register(
        fid: fid,
        fcmToken: fcmToken,
        platform: Platform.isAndroid ? 'ANDROID' : 'IOS',
      );

      debugPrint(
        '[FCM] DEVICE REGISTERED '
        'fid=$fid',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[FCM] DEVICE REGISTER FAILED: '
        '$e',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  void startTokenRefreshListener(
    DeviceApi api,
  ) {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(
      (
        newToken,
      ) async {
        try {
          debugPrint(
            '[FCM] TOKEN REFRESHED',
          );

          final fid = await FirebaseInstallations.instance.getId();

          await api.register(
            fid: fid,
            fcmToken: newToken,
            platform: Platform.isAndroid ? 'ANDROID' : 'IOS',
          );

          debugPrint(
            '[FCM] REFRESHED TOKEN '
            'REGISTERED fid=$fid',
          );
        } catch (e, stackTrace) {
          debugPrint(
            '[FCM] TOKEN REFRESH '
            'REGISTER FAILED: $e',
          );

          debugPrint(
            '$stackTrace',
          );
        }
      },
      onError: (
        Object error,
      ) {
        debugPrint(
          '[FCM] TOKEN REFRESH ERROR: '
          '$error',
        );
      },
    );
  }

  void stopTokenRefreshListener() {
    _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription = null;
  }

  void handleLocalNotificationTap(
    String? payload,
  ) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(
        payload,
      );

      if (decoded is! Map<String, dynamic>) {
        return;
      }

      if (decoded['type'] != 'CHAT_MESSAGE') {
        return;
      }

      final coupleId = (decoded['coupleId'] as num?)?.toInt();

      final senderId = (decoded['senderId'] as num?)?.toInt();

      final senderNickname = decoded['senderNickname']?.toString() ?? '상대방';

      if (coupleId == null || senderId == null) {
        return;
      }

      _pendingNavigationLocation = '/chat/$coupleId'
          '?partnerId=$senderId'
          '&partnerNickname='
          '${Uri.encodeComponent(senderNickname)}';

      debugPrint(
        '[LOCAL NOTIFICATION CLICK] '
        'PENDING '
        '$_pendingNavigationLocation',
      );

      openPendingNavigation();
    } catch (e) {
      debugPrint(
        '[LOCAL NOTIFICATION CLICK] '
        'INVALID PAYLOAD: $e',
      );
    }
  }
}
