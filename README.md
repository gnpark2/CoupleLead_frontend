# Couplead · Flutter App

멀리 있어도 일상을 함께 나눌 수 있도록 만든 커플 앱입니다. 실시간 채팅, 기념일 등록, 상대방의 현지 시각·날씨, 통화, 데스크톱 오버레이를 Flutter 프로젝트로 구성했습니다.

- [백엔드 저장소](https://github.com/gnpark2/CoupleLead)
- [Flutter 앱 저장소](https://github.com/gnpark2/CoupleLead_frontend)

웹으로 시작한 프로젝트를 모바일·데스크톱 앱 중심으로 전환했습니다.

## 주요 기능

| 영역 | 구현 내용 |
| --- | --- |
| 인증 | 회원가입·로그인·세션 복원·토큰 재발급·로그아웃 |
| 사용자·커플 | 프로필·이미지·비밀번호·위치 설정, 초대 코드 연결, 커플 해제·탈퇴 |
| 채팅 | 텍스트·다중 이미지, 이미지 편집·보기, 답장·공지·수정·삭제·읽음·타이핑 |
| 전송 상태 | 낙관적 UI, 전송 중·완료·실패, 같은 `clientMessageId`를 사용하는 재전송 |
| 내역·검색 | 이전 메시지 페이지 조회, 검색·필터, 안 읽은 메시지 위치 |
| 기념일 | 등록·수정·삭제, 홈 표시 항목 선택 |
| 홈·날씨 | 커플 요약, 상대방 현지 시각·날씨, 시간대별 날씨 |
| 통화 | LiveKit 기반 음성·영상·화면 공유 UI, 초대와 응답 |
| 데스크톱 | 기념일 + 날씨 오버레이·미디어 오버레이·채팅 알림 창, 창 위치·표시 설정 |
| 모바일 알림 | FCM 등록·수신, 로컬 알림, 알림 선택 후 화면 이동 |

## 플랫폼 범위

| 플랫폼 | 코드 상태 |
| --- | --- |
| Android | 모바일 개발 예정 |
| iOS | 모바일 개발 예정 |
| Windows / macOS | 메인 창과 여러 오버레이 창 처리. 모든 기능 가능. macOS는 테스트 필요 |
| Web | 삭제 예정 |

카메라·마이크·화면 공유·알림은 대상 OS에서 별도 검증이 필요합니다.

## 기술 구성

| 기술 | 역할 |
| --- | --- |
| Flutter / Dart | 모바일·데스크톱 UI |
| Riverpod / GoRouter | 상태·의존성 관리와 인증 기반 화면 이동 |
| Dio / flutter_secure_storage | REST API·인증 인터셉터·네이티브 토큰 저장 |
| stomp_dart_client | JWT를 전달하는 STOMP over WebSocket |
| livekit_client | 미디어 룸·트랙·화면 공유 |
| desktop_multi_window / window_manager | 별도 창과 창 설정 |
| Firebase Messaging / flutter_local_notifications | 푸시·로컬 알림 |
| shared_preferences | 오버레이·알림 설정 |
| geolocator / geocoding / timezone | 위치·시간대 |

정확한 버전은 `pubspec.yaml`과 `pubspec.lock`을 기준으로 합니다.

## 프로젝트 구성

| 경로 | 역할 |
| --- | --- |
| `lib/main.dart` | 모바일 Firebase 초기화와 데스크톱 창 종류별 실행 |
| `lib/app/` | 앱 테마·라우팅·인증 진입점 |
| `lib/core/network/`, `storage/` | Dio·토큰 재발급·저장 |
| `lib/core/websocket/` | STOMP 연결·구독 |
| `lib/core/desktop/`, `notification/` | 다중 창·푸시·알림 |
| `lib/features/auth/`, `user/`, `couple/` | 사용자·커플 화면과 API |
| `lib/features/chat/` | 메시지·검색·이미지·실시간 채팅 |
| `lib/features/anniversary/`, `weather/`, `widget/` | 기념일·날씨·커플 요약 |
| `lib/features/overlay/`, `media/`, `media_overlay/` | 오버레이·통화 |

## 빌드

각 명령은 해당 플랫폼 빌드 환경에서 따로 실행합니다.

현재 확인된 테스트는 windows와 apk 두 개 입니다. macos, ios는 아직 정상 실행되는지 확인되지 않았다.

```bash
flutter build windows --release --dart-define=API_BASE_URL=https://api.couplead.app --dart-define=WS_URL=wss://api.couplead.app/ws
flutter build macos --release --dart-define=API_BASE_URL=https://api.couplead.app --dart-define=WS_URL=wss://api.couplead.app/ws
flutter build apk --release --dart-define=API_BASE_URL=https://api.couplead.app --dart-define=WS_URL=wss://api.couplead.app/ws
```

Windows 배포에는 실행 파일뿐 아니라 생성된 Release 디렉터리의 DLL·data 파일이 함께 필요합니다.
Android release는 현재 debug 서명을 사용하므로 스토어 배포 전에 실제 서명 설정으로 변경합니다.
iOS는 `Info.plist`에서 `UIMainStoryboardFile` 바로 다음에 `<string>Main</string>`이 오도록 복구하고, 위치·사진 등 기능별 권한과 서명을 확인한 후 빌드합니다.
