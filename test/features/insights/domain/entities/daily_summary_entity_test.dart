import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';

void main() {
  group('DailySummaryEntity', () {
    final date = DateTime(2026, 10, 14);
    final entity = DailySummaryEntity(
      date: date,
      totalFocusMinutes: 120,
      completedSessionsCount: 4,
      currentStreakDays: 5,
    );

    test('equality and props', () {
      final entity2 = DailySummaryEntity(
        date: date,
        totalFocusMinutes: 120,
        completedSessionsCount: 4,
        currentStreakDays: 5,
      );

      expect(entity, equals(entity2));
      expect(entity.hashCode, equals(entity2.hashCode));
    });

    test('copyWith updates specified fields', () {
      final updated = entity.copyWith(
        totalFocusMinutes: 150,
        completedSessionsCount: 5,
        currentStreakDays: 6,
      );

      expect(updated.totalFocusMinutes, 150);
      expect(updated.completedSessionsCount, 5);
      expect(updated.currentStreakDays, 6);
      expect(updated.date, date);

      final noChange = entity.copyWith();
      expect(noChange, equals(entity));
    });
  });
}
