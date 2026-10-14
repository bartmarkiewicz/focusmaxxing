abstract final class AppDateUtils {
  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static int calendarDaysBetween(DateTime from, DateTime to) {
    final utcFrom = DateTime.utc(from.year, from.month, from.day);
    final utcTo = DateTime.utc(to.year, to.month, to.day);
    return utcTo.difference(utcFrom).inDays;
  }

  static bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }
}
