import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/model/chat_announcement.dart';
import 'chat_provider.dart';

final chatAnnouncementProvider = FutureProvider.family<ChatAnnouncement?, int>(
  (
    ref,
    coupleId,
  ) {
    return ref
        .watch(
          chatApiProvider,
        )
        .getAnnouncement(
          coupleId,
        );
  },
);
