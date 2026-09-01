import 'package:flutter/material.dart';

import '../data/model/anniversary.dart';

IconData anniversaryIcon(
  String type,
) {
  switch (type) {
    case 'COUPLE_START':
      return Icons.favorite;

    case 'BIRTHDAY':
      return Icons.cake_outlined;

    case 'FIRST_DATE':
      return Icons.restaurant_outlined;

    case 'TRAVEL':
      return Icons.flight_outlined;

    case 'CUSTOM':
    default:
      return Icons.event_outlined;
  }
}

String anniversaryTypeLabel(
  Anniversary anniversary,
) {
  switch (anniversary.type) {
    case 'COUPLE_START':
      return '커플 시작일';

    case 'BIRTHDAY':
      return '생일';

    case 'FIRST_DATE':
      return '첫 데이트';

    case 'TRAVEL':
      return '여행';

    case 'CUSTOM':
      final custom =
          anniversary.customTypeName;

      if (custom == null ||
          custom.trim().isEmpty) {
        return '직접 지정';
      }

      return custom;

    default:
      return '기념일';
  }
}