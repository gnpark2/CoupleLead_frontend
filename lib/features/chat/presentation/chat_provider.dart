import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/chat_api.dart';

final chatApiProvider =
    Provider<ChatApi>(
  (ref) {
    final dio =
        ref.watch(dioClientProvider).dio;

    return ChatApi(
      dio: dio,
    );
  },
);

// final chatMessagesProvider =
//     FutureProvider.family<
//         List<ChatMessage>,
//         int>(
//   (
//     ref,
//     coupleId,
//   ) {
//     return ref
//         .watch(chatApiProvider)
//         .getMessages(coupleId);
//   },
// );