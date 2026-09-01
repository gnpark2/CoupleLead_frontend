import 'dart:async';

import 'package:flutter/material.dart';

class InAppNotificationService {
  InAppNotificationService._();

  static final instance = InAppNotificationService._();

  OverlayEntry? _currentEntry;
  Timer? _timer;

  void show({
    required BuildContext context,
    required String nickname,
    required String message,
    VoidCallback? onTap,
  }) {
    _timer?.cancel();

    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  hide();
                  onTap?.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(
                    14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 12,
                        offset: Offset(0, 4),
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        child: Icon(
                          Icons.chat_bubble,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              nickname,
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    _currentEntry = entry;

    _timer = Timer(
      const Duration(
        seconds: 4,
      ),
      hide,
    );
  }

  void hide() {
    _timer?.cancel();
    _timer = null;

    _currentEntry?.remove();
    _currentEntry = null;
  }
}
