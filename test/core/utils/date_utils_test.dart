import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/utils/date_utils.dart';

void main() {
  group('AppDateUtils', () {
    test('getStartOfDay returns midnight with 00:00:00.000', () {
      final date = DateTime(2026, 10, 14, 15, 30, 45, 123);
      final start = AppDateUtils.getStartOfDay(date);

      expect(start.year, 2026);
      expect(start.month, 10);
      expect(start.day, 14);
      expect(start.hour, 0);
      expect(start.minute, 0);
      expect(start.second, 0);
      expect(start.millisecond, 0);
    });

    test('getEndOfDay returns end of calendar day with 23:59:59.999', () {
      final date = DateTime(2026, 10, 14, 8, 0, 0);
      final end = AppDateUtils.getEndOfDay(date);

      expect(end.year, 2026);
      expect(end.month, 10);
      expect(end.day, 14);
      expect(end.hour, 23);
      expect(end.minute, 59);
      expect(end.second, 59);
      expect(end.millisecond, 999);
    });

    test('isSameDay correctly identifies matching calendar dates', () {
      final a = DateTime(2026, 10, 14, 2, 0);
      final b = DateTime(2026, 10, 14, 23, 59);
      final c = DateTime(2026, 10, 15, 0, 1);

      expect(AppDateUtils.isSameDay(a, b), isTrue);
      expect(AppDateUtils.isSameDay(a, c), isFalse);
    });

    test('calendarDaysBetween calculates full days between dates', () {
      final from = DateTime(2026, 10, 10, 23, 0);
      final to = DateTime(2026, 10, 14, 1, 0);

      expect(AppDateUtils.calendarDaysBetween(from, to), 4);
    });

    test('isWeekend returns true for Saturday and Sunday, false for weekdays', () {
      // 2026-10-14 is Wednesday
      final wednesday = DateTime(2026, 10, 14);
      // 2026-10-17 is Saturday
      final saturday = DateTime(2026, 10, 17);
      // 2026-10-18 is Sunday
      final sunday = DateTime(2026, 10, 18);

      expect(AppDateUtils.isWeekend(wednesday), isFalse);
      expect(AppDateUtils.isWeekend(saturday), isTrue);
      expect(AppDateUtils.isWeekend(sunday), isTrue);
    });
  });
}
