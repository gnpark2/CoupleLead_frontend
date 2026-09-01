import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class ChatImageEditorPage extends StatefulWidget {
  final Uint8List imageBytes;

  const ChatImageEditorPage({
    super.key,
    required this.imageBytes,
  });

  @override
  State<ChatImageEditorPage> createState() => _ChatImageEditorPageState();
}

class _ChatImageEditorPageState extends State<ChatImageEditorPage> {
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.memory(
      widget.imageBytes,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (
          Uint8List editedBytes,
        ) async {
          _completed = true;

          if (!mounted) {
            return;
          }

          Navigator.of(context).pop(
            editedBytes,
          );
        },
        onCloseEditor: (
          editorMode,
        ) {
          if (_completed) {
            return;
          }

          if (!mounted) {
            return;
          }

          Navigator.of(context).pop();
        },
      ),
    );
  }
}
