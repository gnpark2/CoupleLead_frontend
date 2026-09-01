import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

class CoupleadApp
    extends ConsumerWidget {
  const CoupleadApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final router =
        ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Couplead',
      debugShowCheckedModeBanner:
          false,
      routerConfig: router,
    );
  }
}