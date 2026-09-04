import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_provider.dart';
import 'stomp_service.dart';

final stompServiceProvider = Provider<StompService>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);

  return StompService(
    tokenStorage: tokenStorage,
  );
});
