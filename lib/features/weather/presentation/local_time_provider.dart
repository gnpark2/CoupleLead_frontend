import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

final localTimeProvider = StreamProvider.family<DateTime, String>(
  (
    ref,
    timezone,
  ) async* {
    final location = tz.getLocation(
      timezone,
    );

    while (true) {
      final now = tz.TZDateTime.now(
        location,
      );

      yield now;

      /*
       * 다음 분 경계까지 대기
       */
      final systemNow = DateTime.now();

      final delay = Duration(
        seconds: 60 - systemNow.second,
        milliseconds: -systemNow.millisecond,
      );

      await Future.delayed(
        delay,
      );
    }
  },
);
