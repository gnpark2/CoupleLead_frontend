import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class ScreenSelectDialog extends StatefulWidget {
  const ScreenSelectDialog({
    super.key,
  });

  @override
  State<ScreenSelectDialog> createState() => _ScreenSelectDialogState();
}

class _ScreenSelectDialogState extends State<ScreenSelectDialog> {
  List<DesktopCapturerSource> _sources = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _loadSources();
  }

  Future<void> _loadSources() async {
    final sources = await desktopCapturer.getSources(
      types: [
        SourceType.Screen,
        SourceType.Window,
      ],
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _sources = sources;
      _loading = false;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title: const Text(
        '공유할 화면 선택',
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _sources.length,
                itemBuilder: (
                  context,
                  index,
                ) {
                  final source = _sources[index];

                  return InkWell(
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pop(
                        source,
                      );
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.desktop_windows,
                              size: 48,
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            Text(
                              source.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop();
          },
          child: const Text(
            '취소',
          ),
        ),
      ],
    );
  }
}
