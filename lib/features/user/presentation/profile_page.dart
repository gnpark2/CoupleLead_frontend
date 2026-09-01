import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../core/constants/api_constants.dart';
import '../../../core/ui/top_notification.dart';
import '../../couple/presentation/couple_provider.dart';
import '../../settings/presentation/notification_settings_provider.dart';
import '../data/model/user_me.dart';
import '../domain/city_search_result.dart';
import '../domain/user_location.dart';
import 'city_search_dialog.dart';
import 'profile_image_crop_page.dart';
import 'user_provider.dart';
import 'withdraw_dialog.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({
    super.key,
  });

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final TextEditingController _nicknameController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool _initialized = false;

  bool _savingNickname = false;
  bool _uploadingImage = false;

  UserLocation? _selectedLocation;

  bool _detectingLocation = false;

  @override
  void dispose() {
    _nicknameController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final meAsync = ref.watch(meProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '프로필 수정',
        ),
      ),
      body: meAsync.when(
        data: (me) {
          if (!_initialized) {
            _initialized = true;

            _nicknameController.text = me.nickname;

            if (me.country != null &&
                me.city != null &&
                me.timezone != null &&
                me.latitude != null &&
                me.longitude != null) {
              _selectedLocation = UserLocation(
                country: me.country!,
                city: me.city!,
                timezone: me.timezone!,
                latitude: me.latitude!,
                longitude: me.longitude!,
              );
            }
          }

          final profileImage = me.profileImage;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                /*
                 * 현재 프로필 이미지
                 */
                _ProfileImage(
                  profileImage: profileImage,
                  nickname: me.nickname,
                ),
                const SizedBox(
                  height: 16,
                ),

                /*
                 * 프로필 이미지 변경
                 */
                OutlinedButton.icon(
                  onPressed: _uploadingImage ? null : _pickProfileImage,
                  icon: _uploadingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera,
                        ),
                  label: Text(
                    _uploadingImage ? '업로드 중...' : '프로필 이미지 변경',
                  ),
                ),
                if (me.profileImage != null && me.profileImage!.isNotEmpty)
                  TextButton.icon(
                    onPressed: _uploadingImage ? null : _deleteProfileImage,
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                    label: const Text(
                      '프로필 이미지 삭제',
                    ),
                  ),
                const SizedBox(
                  height: 32,
                ),

                /*
                * 계정 및 보안 항목
                */
                const SizedBox(
                  height: 32,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '계정 및 보안',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                /*
                 * 이메일
                 */
                TextField(
                  controller: TextEditingController(
                    text: me.email,
                  ),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),

                /*
                * 비밀번호
                */
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.lock_outline,
                  ),
                  title: const Text(
                    '비밀번호 변경',
                  ),
                  subtitle: const Text(
                    '현재 비밀번호를 확인한 후 변경합니다.',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () {
                    context.push(
                      '/settings/password',
                    );
                  },
                ),
                /*
                * 프로필 수정
                */
                const SizedBox(
                  height: 16,
                ),
                const Divider(),
                const SizedBox(
                  height: 24,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '내 프로필',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                TextField(
                  controller: _nicknameController,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    hintText: '닉네임을 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                if (_selectedLocation != null) ...[
                  const SizedBox(
                    height: 12,
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '국가: '
                            '${_selectedLocation!.country}',
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            '도시: '
                            '${_selectedLocation!.city}',
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            '시간대: '
                            '${_selectedLocation!.timezone}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                ],
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '위치 및 시간대',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                OutlinedButton.icon(
                  onPressed: _detectingLocation ? null : _detectCurrentLocation,
                  icon: _detectingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.my_location,
                        ),
                  label: Text(
                    _detectingLocation ? '현재 위치 확인 중...' : '현재 위치 사용',
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                OutlinedButton.icon(
                  onPressed: _detectingLocation ? null : _selectOtherCity,
                  icon: const Icon(
                    Icons.travel_explore,
                  ),
                  label: const Text(
                    '다른 도시 선택',
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      _saveProfile(me);
                    },
                    child: const Text(
                      '프로필 저장',
                    ),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                const Divider(),
                const SizedBox(
                  height: 24,
                ),

                /*
                * 알림 설정
                */
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '알림 설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Consumer(
                  builder: (
                    context,
                    ref,
                    child,
                  ) {
                    final notificationSettingsAsync = ref.watch(
                      notificationSettingsProvider,
                    );

                    return notificationSettingsAsync.when(
                      data: (
                        settings,
                      ) {
                        return Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              secondary: const Icon(
                                Icons.notifications_outlined,
                              ),
                              title: const Text(
                                '채팅 알림',
                              ),
                              subtitle: const Text(
                                '채팅방을 보고 있지 않을 때 '
                                '새 메시지 알림을 표시합니다.',
                              ),
                              value: settings.chatNotificationEnabled,
                              onChanged: (
                                value,
                              ) async {
                                await ref
                                    .read(
                                      notificationSettingsProvider.notifier,
                                    )
                                    .setChatNotificationEnabled(
                                      value,
                                    );
                              },
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              secondary: const Icon(
                                Icons.volume_up_outlined,
                              ),
                              title: const Text(
                                '알림 소리',
                              ),
                              subtitle: const Text(
                                '채팅 알림이 표시될 때 '
                                '알림음을 재생합니다.',
                              ),
                              value: settings.soundEnabled,
                              onChanged: settings.chatNotificationEnabled
                                  ? (
                                      value,
                                    ) async {
                                      await ref
                                          .read(
                                            notificationSettingsProvider
                                                .notifier,
                                          )
                                          .setSoundEnabled(
                                            value,
                                          );
                                    }
                                  : null,
                            ),
                          ],
                        );
                      },
                      loading: () {
                        return const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          child: CircularProgressIndicator(),
                        );
                      },
                      error: (
                        error,
                        stackTrace,
                      ) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          child: Text(
                            '알림 설정을 불러오지 못했습니다.',
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(
                  height: 16,
                ),
                const Divider(),
                const SizedBox(
                  height: 24,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '커플 해제 및 탈퇴',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.link_off,
                  ),
                  title: const Text(
                    '커플 연결 해제',
                  ),
                  subtitle: const Text(
                    '현재 커플과의 연결을 해제합니다.',
                  ),
                  onTap: _confirmDisconnect,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.person_remove_outlined,
                  ),
                  title: const Text(
                    '회원 탈퇴',
                  ),
                  subtitle: const Text(
                    '계정과 관련 데이터를 삭제합니다.',
                  ),
                  onTap: _confirmWithdraw,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (
          error,
          stackTrace,
        ) =>
            Center(
          child: Text(
            '프로필 조회 실패\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            '커플 연결 해제',
          ),
          content: const Text(
            '현재 커플과의 연결을 해제하시겠습니까?\n\n'
            '연결을 해제하면 두 사용자 모두 '
            '커플 연결 화면으로 이동합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                '취소',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                '연결 해제',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await ref
        .read(
          coupleDisconnectProvider.notifier,
        )
        .disconnect();

    if (!mounted) {
      return;
    }

    if (!success) {
      TopNotification.show(
        context,
        message: '커플 연결 해제에 실패했습니다.',
        type: TopNotificationType.error,
      );

      return;
    }

    TopNotification.show(
      context,
      message: '커플 연결이 해제되었습니다.',
      type: TopNotificationType.success,
    );

    /*
   * 여기서 직접 route 이동하지 않는다.
   *
   * 서버의 COUPLE_DISCONNECTED
   * WebSocket 이벤트를 Home에서 받아
   * 양쪽 사용자 모두 이동시킬 예정이다.
   */
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    if (pickedFile == null) {
      return;
    }

    final bytes = await pickedFile.readAsBytes();

    if (!mounted) {
      return;
    }

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ProfileImageCropPage(
          imageBytes: bytes,
        ),
      ),
    );

    if (croppedBytes == null) {
      return;
    }

    await _uploadProfileImage(
      croppedBytes,
    );
  }

  Future<void> _confirmWithdraw() async {
    await showWithdrawDialog(
      context: context,
      ref: ref,
    );
  }

  Future<void> _saveProfile(
    UserMe me,
  ) async {
    final nickname = _nicknameController.text.trim();

    if (nickname.isEmpty) {
      return;
    }

    final location = _selectedLocation;

    try {
      await ref
          .read(
            userApiProvider,
          )
          .updateProfile(
            nickname: nickname,
            country: location?.country ?? me.country,
            city: location?.city ?? me.city,
            timezone: location?.timezone ?? me.timezone,
            latitude: location?.latitude ?? me.latitude,
            longitude: location?.longitude ?? me.longitude,
          );

      ref.invalidate(
        meProvider,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '프로필이 수정되었습니다.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '프로필 수정에 실패했습니다.',
          ),
        ),
      );
    }
  }

  Future<void> _detectCurrentLocation() async {
    if (_detectingLocation) {
      return;
    }

    setState(() {
      _detectingLocation = true;
    });

    try {
      final location = await ref
          .read(
            locationServiceProvider,
          )
          .getCurrentLocation();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLocation = location;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '현재 위치를 확인했습니다: '
            '${location.city}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _detectingLocation = false;
        });
      }
    }
  }

  Future<void> _selectOtherCity() async {
    final city = await showDialog<CitySearchResult>(
      context: context,
      builder: (
        context,
      ) {
        return const CitySearchDialog();
      },
    );

    if (city == null || !mounted) {
      return;
    }

    setState(() {
      _selectedLocation = city.toUserLocation();
    });
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }

  Future<void> _uploadProfileImage(
    Uint8List bytes,
  ) async {
    setState(() {
      _uploadingImage = true;
    });

    try {
      await ref
          .read(
            userApiProvider,
          )
          .updateProfileImage(
            bytes: bytes,
            filename: 'profile.png',
          );

      await ref.refresh(
        meProvider.future,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            '프로필 이미지가 변경되었습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '프로필 이미지 변경 실패: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  Future<void> _deleteProfileImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (
        context,
      ) {
        return AlertDialog(
          title: const Text(
            '프로필 이미지 삭제',
          ),
          content: const Text(
            '현재 프로필 이미지를 삭제하고 '
            '기본 이미지로 변경할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  false,
                );
              },
              child: const Text(
                '취소',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(
                  true,
                );
              },
              child: const Text(
                '삭제',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _uploadingImage = true;
    });

    try {
      await ref
          .read(
            userApiProvider,
          )
          .deleteProfileImage();

      await ref.refresh(
        meProvider.future,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            '프로필 이미지가 삭제되었습니다.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            '프로필 이미지 삭제 실패: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }
}

class _ProfileImage extends StatelessWidget {
  final String? profileImage;
  final String nickname;

  const _ProfileImage({
    required this.profileImage,
    required this.nickname,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final hasImage = profileImage != null && profileImage!.trim().isNotEmpty;

    if (!hasImage) {
      return CircleAvatar(
        radius: 60,
        child: Text(
          nickname.isNotEmpty ? nickname[0] : '?',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium,
        ),
      );
    }

    final url = _resolveProfileImage(
      profileImage!,
    );

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          url,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            debugPrint(
              'PROFILE IMAGE ERROR: '
              '$error',
            );

            return Center(
              child: Text(
                nickname.isNotEmpty ? nickname[0] : '?',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium,
              ),
            );
          },
        ),
      ),
    );
  }
}

String _resolveProfileImage(
  String image,
) {
  if (image.startsWith('http://') || image.startsWith('https://')) {
    return image;
  }

  final baseUrl = ApiConstants.baseUrl.replaceFirst(
    RegExp(r'/$'),
    '',
  );

  if (image.startsWith('/')) {
    return '$baseUrl$image';
  }

  return '$baseUrl/$image';
}
