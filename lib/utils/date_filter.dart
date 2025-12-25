enum DateFilter {
  today,
  thisWeek,
  thisMonth,
  allTime,
}

extension DateFilterExtension on DateFilter {
  String get label {
    switch (this) {
      case DateFilter.today:
        return 'วันนี้';
      case DateFilter.thisWeek:
        return 'สัปดาห์นี้';
      case DateFilter.thisMonth:
        return 'เดือนนี้';
      case DateFilter.allTime:
        return 'ทั้งหมด';
    }
  }

  DateTime? get startDate {
    final now = DateTime.now();
    switch (this) {
      case DateFilter.today:
        return DateTime(now.year, now.month, now.day);
      case DateFilter.thisWeek:
        final weekday = now.weekday;
        return DateTime(now.year, now.month, now.day - (weekday - 1));
      case DateFilter.thisMonth:
        return DateTime(now.year, now.month, 1);
      case DateFilter.allTime:
        return null;
    }
  }

  DateTime? get endDate {
    final now = DateTime.now();
    switch (this) {
      case DateFilter.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DateFilter.thisWeek:
        final weekday = now.weekday;
        final startOfWeek = DateTime(now.year, now.month, now.day - (weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 6, 23, 59, 59);
      case DateFilter.thisMonth:
        final lastDay = DateTime(now.year, now.month + 1, 0);
        return DateTime(now.year, now.month, lastDay.day, 23, 59, 59);
      case DateFilter.allTime:
        return null;
    }
  }
}
