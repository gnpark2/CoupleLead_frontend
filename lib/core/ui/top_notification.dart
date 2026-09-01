import 'dart:async';

import 'package:flutter/material.dart';

enum TopNotificationType {
  success,
  error,
  info,
}

class TopNotification {
  const TopNotification._();

  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String message,
    TopNotificationType type = TopNotificationType.info,
    Duration duration = const Duration(
      seconds: 2,
    ),
  }) {
    /*
     * 기존 알림이 있으면 제거
     */
    _currentEntry?.remove();

    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (
        context,
      ) {
        return _TopNotificationWidget(
          message: message,
          type: type,
        );
      },
    );

    _currentEntry = entry;

    overlay.insert(entry);

    Timer(
      duration,
      () {
        if (_currentEntry == entry) {
          entry.remove();

          _currentEntry = null;
        }
      },
    );
  }
}

class _TopNotificationWidget extends StatelessWidget {
  final String message;

  final TopNotificationType type;

  const _TopNotificationWidget({
    required this.message,
    required this.type,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final (
      icon,
      backgroundColor,
    ) = switch (type) {
      TopNotificationType.success => (
          Icons.check_circle_outline,
          Colors.green.shade700,
        ),
      TopNotificationType.error => (
          Icons.error_outline,
          Colors.red.shade700,
        ),
      TopNotificationType.info => (
          Icons.info_outline,
          Colors.blueGrey.shade700,
        ),
    };

    return Positioned(
      top: 18,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              margin: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(
                  10,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.15,
                    ),
                    blurRadius: 12,
                    offset: const Offset(
                      0,
                      4,
                    ),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
