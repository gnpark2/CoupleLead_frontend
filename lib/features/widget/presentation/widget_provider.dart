import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/model/couple_widget.dart';
import '../data/widget_api.dart';

final widgetApiProvider =
    Provider<WidgetApi>(
  (ref) {
    final dio =
        ref.watch(dioClientProvider).dio;

    return WidgetApi(
      dio: dio,
    );
  },
);

final coupleWidgetProvider =
    FutureProvider<CoupleWidget>(
  (ref) {
    return ref
        .watch(widgetApiProvider)
        .getCoupleWidget();
  },
);