import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import 'model/couple_widget.dart';

class WidgetApi {
  final Dio dio;

  WidgetApi({
    required this.dio,
  });

  Future<CoupleWidget> getCoupleWidget() async {
    final response = await dio.get(
      ApiConstants.coupleWidget,
    );

    final body =
        response.data as Map<String, dynamic>;

    final data =
        body['data'] as Map<String, dynamic>;

    return CoupleWidget.fromJson(data);
  }

  Future<void> selectAnniversary(
    int anniversaryId,
  ) async {
    await dio.patch(
      ApiConstants.selectWidgetAnniversary,
      data: {
        'anniversaryId': anniversaryId,
      },
    );
  }
}