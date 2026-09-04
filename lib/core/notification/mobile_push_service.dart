import 'dart:async';
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
        final data = message.data;

        if (data['type'] != 'CHAT_MESSAGE') {
          return;
        }

        final coupleId = int.tryParse(
          data['coupleId']?.toString() ?? '',
        );

        if (coupleId == null) {
          return;
        }

        /*
     * 현재 이 채팅방을 직접 보고 있다면
     * 알림을 표시하지 않는다.
     */
        final currentChatCoupleId =
            ChatVisibilityService.currentCoupleId;

        debugPrint(
          '[FCM FOREGROUND] '
          'currentChatCoupleId=$currentChatCoupleId '
          'incomingCoupleId=$coupleId',
        );

        if (currentChatCoupleId == coupleId) {
          return;
        }

        final nickname = data['senderNickname']?.toString() ?? '상대방';

        final body = data['message']?.toString() ?? '새 메시지가 도착했습니다.';

        await LocalNotificationService.instance.showChatNotification(
          nickname: nickname,
          message: body,
          coupleId: coupleId,
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

  void handleLocalNotificationPayload(
    String? payload,
  ) {
    if (payload == null || payload.isEmpty) {
      return;
    }

    final parts = payload.split(':');

    if (parts.length != 3 || parts[0] != 'chat') {
      return;
    }

    final coupleId = int.tryParse(
      parts[1],
    );

    final partnerId = int.tryParse(
      parts[2],
    );

    if (coupleId == null || partnerId == null) {
      return;
    }

    _pendingNavigationLocation = '/chat/$coupleId'
        '?partnerId=$partnerId';

    debugPrint(
      '[LOCAL NOTIFICATION CLICK] '
      'PENDING='
      '$_pendingNavigationLocation',
    );

    openPendingNavigation();
  }
}
