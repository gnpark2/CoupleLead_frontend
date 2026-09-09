import 'package:flutter/material.dart';

import 'media_overlay_page.dart';

class MediaOverlayWindowApp extends StatelessWidget {
  final String mainWindowId;

  const MediaOverlayWindowApp({
    super.key,
    required this.mainWindowId,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaOverlayPage(
        mainWindowId: mainWindowId,
      ),
    );
  }
}
