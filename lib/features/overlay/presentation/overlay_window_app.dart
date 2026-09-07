import 'package:flutter/material.dart';

import 'overlay_page.dart';

class OverlayWindowApp extends StatelessWidget {
  const OverlayWindowApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayPage(),
    );
  }
}
