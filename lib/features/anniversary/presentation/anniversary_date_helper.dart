int calculateAnniversaryDDay({
  required String anniversaryDate,
  required String repeatType,
}) {
  final originalDate = DateTime.parse(
    anniversaryDate,
  );

  final now = DateTime.now();

  final today = DateTime(
    now.year,
    now.month,
    now.day,
  );

  DateTime targetDate;

  if (repeatType == 'YEARLY') {
    targetDate = _createSafeDate(
      today.year,
      originalDate.month,
      originalDate.day,
    );

    if (targetDate.isBefore(today)) {
      targetDate = _createSafeDate(
        today.year + 1,
        originalDate.month,
        originalDate.day,
      );
    }
  } else {
    targetDate = DateTime(
      originalDate.year,
      originalDate.month,
      originalDate.day,
    );
  }

  return targetDate.difference(today).inDays;
}

DateTime _createSafeDate(
  int year,
  int month,
  int day,
) {
  /*
   * Dart DateTime은 잘못된 날짜를 자동 보정하므로
   * 2월 29일을 직접 처리한다.
   */
  if (month == 2 && day == 29) {
    final leapYear = _isLeapYear(year);

    if (!leapYear) {
      return DateTime(
        year,
        2,
        28,
      );
    }
  }

  return DateTime(
    year,
    month,
    day,
  );
}

bool _isLeapYear(
  int year,
) {
  return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}

String formatAnniversaryDDay(
  int value,
) {
  if (value == 0) {
    return 'D-Day';
  }

  if (value > 0) {
    return 'D-$value';
  }

  return 'D+${value.abs()}';
}
