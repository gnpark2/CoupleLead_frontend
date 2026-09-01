import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../widget/presentation/widget_provider.dart';
import '../data/anniversary_api.dart';
import '../data/model/anniversary.dart';
import '../data/model/create_anniversary_request.dart';
import '../data/model/update_anniversary_request.dart';
import '../../overlay/presentation/overlay_provider.dart';

final anniversaryApiProvider = Provider<AnniversaryApi>(
  (ref) {
    final dio = ref
        .watch(
          dioClientProvider,
        )
        .dio;

    return AnniversaryApi(
      dio: dio,
    );
  },
);

final anniversaryListProvider = FutureProvider<List<Anniversary>>(
  (ref) async {
    final api = ref.watch(
      anniversaryApiProvider,
    );

    return api.getAll();
  },
);

final anniversaryCreateProvider =
    AsyncNotifierProvider<AnniversaryCreateController, void>(
  AnniversaryCreateController.new,
);

final homeAnniversaryProvider = FutureProvider<List<Anniversary>>(
  (ref) async {
    final api = ref.watch(
      anniversaryApiProvider,
    );

    return api.getHomeAnniversaries();
  },
);

final homeAnniversarySelectionProvider =
    AsyncNotifierProvider<HomeAnniversarySelectionController, void>(
  HomeAnniversarySelectionController.new,
);

final anniversaryManageProvider =
    AsyncNotifierProvider<AnniversaryManageController, void>(
  AnniversaryManageController.new,
);

class HomeAnniversarySelectionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> save({
    required List<int> anniversaryIds,
  }) async {
    state = const AsyncLoading();

    try {
      final api = ref.read(
        anniversaryApiProvider,
      );

      await api.updateHomeAnniversaries(
        anniversaryIds: anniversaryIds,
      );

      ref.invalidate(
        homeAnniversaryProvider,
      );

      state = const AsyncData(null);

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }
}

class AnniversaryCreateController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> create({
    required CreateAnniversaryRequest request,
  }) async {
    state = const AsyncLoading();

    try {
      final api = ref.read(
        anniversaryApiProvider,
      );

      await api.create(
        request: request,
      );

      /*
       * 기념일 목록 다시 조회
       */
      ref.invalidate(
        anniversaryListProvider,
      );

      /*
       * Home 위젯 데이터도 갱신
       */
      ref.invalidate(
        coupleWidgetProvider,
      );

      state = const AsyncData(
        null,
      );

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }
}

class AnniversaryManageController
    extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> updateAnniversary({
    required int anniversaryId,
    required UpdateAnniversaryRequest request,
  }) async {
    state = const AsyncLoading();

    try {
      final api = ref.read(
        anniversaryApiProvider,
      );

      await api.update(
        anniversaryId: anniversaryId,
        request: request,
      );

      ref.invalidate(
        anniversaryListProvider,
      );

      ref.invalidate(
        homeAnniversaryProvider,
      );

      ref.invalidate(
        coupleWidgetProvider,
      );

      state = const AsyncData(null);

      return true;
    } catch (
      error,
      stackTrace
    ) {
      state = AsyncError(
        error,
        stackTrace,
      );

      return false;
    }
  }

  Future<bool> deleteAnniversary({
  required int anniversaryId,
}) async {
  state = const AsyncLoading();

  try {
    final api = ref.read(
      anniversaryApiProvider,
    );

    /*
     * 서버 기념일 삭제
     */
    await api.delete(
      anniversaryId:
          anniversaryId,
    );

    /*
     * 삭제한 기념일이
     * 현재 Overlay에 선택되어 있다면
     * 선택 해제
     */
    final overlaySettings = ref
        .read(
          overlaySettingsProvider,
        )
        .valueOrNull;

    if (overlaySettings
            ?.anniversaryId ==
        anniversaryId) {
      await ref
          .read(
            overlaySettingsProvider
                .notifier,
          )
          .setAnniversary(null);
    }

    /*
     * 전체 기념일 목록 갱신
     */
    ref.invalidate(
      anniversaryListProvider,
    );

    /*
     * Home 기념일 갱신
     */
    ref.invalidate(
      homeAnniversaryProvider,
    );

    /*
     * 기존 커플 위젯도 갱신
     */
    ref.invalidate(
      coupleWidgetProvider,
    );

    state =
        const AsyncData(null);

    return true;
  } catch (
    error,
    stackTrace
  ) {
    state = AsyncError(
      error,
      stackTrace,
    );

    return false;
  }
}
}