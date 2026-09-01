import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/city_search_api.dart';
import '../data/location_service.dart';
import '../data/model/user_me.dart';
import '../data/user_api.dart';
import '../domain/city_search_result.dart';

final userApiProvider = Provider<UserApi>(
  (ref) {
    final dio = ref.watch(dioClientProvider).dio;

    return UserApi(
      dio: dio,
    );
  },
);

final locationServiceProvider = Provider<LocationService>(
  (ref) {
    return LocationService();
  },
);

final citySearchApiProvider = Provider<CitySearchApi>(
  (ref) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(
          seconds: 10,
        ),
        receiveTimeout: const Duration(
          seconds: 10,
        ),
      ),
    );

    return CitySearchApi(
      dio: dio,
    );
  },
);

final citySearchProvider =
    FutureProvider.autoDispose.family<List<CitySearchResult>, String>(
  (
    ref,
    query,
  ) async {
    final keyword = query.trim();

    if (keyword.length < 2) {
      return [];
    }

    return ref
        .read(
          citySearchApiProvider,
        )
        .search(
          keyword,
        );
  },
);

final meProvider = FutureProvider<UserMe>(
  (ref) {
    return ref.watch(userApiProvider).getMe();
  },
);

final withdrawProvider = AsyncNotifierProvider<WithdrawController, void>(
  WithdrawController.new,
);

class WithdrawController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> withdraw() async {
    state = const AsyncLoading();

    try {
      final api = ref.read(
        userApiProvider,
      );

      await api.withdraw();

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
