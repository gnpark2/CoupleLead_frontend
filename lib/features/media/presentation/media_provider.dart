import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/media_api.dart';

final mediaApiProvider = Provider<MediaApi>(
  (ref) {
    final dio = ref
        .watch(
          dioClientProvider,
        )
        .dio;

    return MediaApi(
      dio: dio,
    );
  },
);
