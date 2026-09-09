import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/model/media_overlay_api.dart';

final mediaOverlayApiProvider = Provider<MediaOverlayApi>(
  (
    ref,
  ) {
    final dio = ref
        .watch(
          dioClientProvider,
        )
        .dio;

    return MediaOverlayApi(
      dio: dio,
    );
  },
);
