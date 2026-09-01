import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class ProfileImageCropPage extends StatefulWidget {
  final Uint8List imageBytes;

  const ProfileImageCropPage({
    super.key,
    required this.imageBytes,
  });

  @override
  State<ProfileImageCropPage> createState() => _ProfileImageCropPageState();
}

class _ProfileImageCropPageState extends State<ProfileImageCropPage> {
  final CropController _controller = CropController();

  bool _cropping = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '프로필 이미지 자르기',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ClipRect(
                child: Crop(
                  image: widget.imageBytes,
                  controller: _controller,

                  /*
                   * 프로필이므로 1:1
                   */
                  aspectRatio: 1,

                  /*
                   * 이미지 이동/확대가 가능한
                   * interactive 모드
                   */
                  interactive: true,

                  /*
                   * crop 영역을 고정
                   */
                  fixCropRect: true,
                  onCropped: (
                    result,
                  ) {
                    switch (result) {
                      case CropSuccess(
                          :final croppedImage,
                        ):
                        Navigator.of(
                          context,
                        ).pop(
                          croppedImage,
                        );

                      case CropFailure(
                          :final cause,
                        ):
                        setState(() {
                          _cropping = false;
                        });

                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          SnackBar(
                            content: Text(
                              '이미지 자르기 실패: $cause',
                            ),
                          ),
                        );
                    }
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              12,
              24,
              24,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _cropping
                    ? null
                    : () {
                        setState(
                          () {
                            _cropping = true;
                          },
                        );

                        _controller.crop();
                      },
                child: _cropping
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '이대로 사용',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
