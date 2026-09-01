import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/couple_api.dart';
import '../../auth/presentation/auth_provider.dart';

final coupleApiProvider =
    Provider<CoupleApi>(
  (ref) {
    final dio =
        ref.watch(dioClientProvider).dio;

    return CoupleApi(
      dio: dio,
    );
  },
);

final myCoupleProvider =
    FutureProvider<Map<String, dynamic>>(
  (ref) {
    return ref
        .watch(coupleApiProvider)
        .getMyCouple();
  },
);