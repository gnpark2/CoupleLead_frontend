import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/device_api.dart';

final deviceApiProvider = Provider<DeviceApi>(
  (ref) {
    final dio = ref
        .watch(
          dioClientProvider,
        )
        .dio;

    return DeviceApi(
      dio: dio,
    );
  },
);
