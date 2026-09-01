import 'dart:io';

import 'package:flutter/foundation.dart';

class DesktopPlatform {
  const DesktopPlatform._();

  static bool get isDesktop {
    if (kIsWeb) {
      return false;
    }

    return Platform.isWindows || Platform.isMacOS;
  }

  static bool get isWindows {
    if (kIsWeb) {
      return false;
    }

    return Platform.isWindows;
  }

  static bool get isMacOS {
    if (kIsWeb) {
      return false;
    }

    return Platform.isMacOS;
  }
}
