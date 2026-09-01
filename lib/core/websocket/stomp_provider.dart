import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stomp_service.dart';

final stompServiceProvider =
    Provider<StompService>(
  (ref) {
    final service =
        StompService();

    ref.onDispose(
      service.disconnect,
    );

    return service;
  },
);