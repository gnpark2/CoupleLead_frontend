import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final widgetRefreshTickerProvider = StreamProvider<int>(
  (
    ref,
  ) {
    return Stream.periodic(
      const Duration(
        minutes: 10,
      ),
      (
        count,
      ) =>
          count,
    );
  },
);
