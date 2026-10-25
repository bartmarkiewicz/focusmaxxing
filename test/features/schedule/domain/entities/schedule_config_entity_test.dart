import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';

void main() {
  group('ScheduleConfigEntity', () {
    test('defaultSchedule has valid defaults', () {
      const schedule = ScheduleConfigEntity.initial;
      expect(schedule.isEnabled, isFalse);
      expect(schedule.startHour, equals(9));
      expect(schedule.startMinute, equals(0));
      expect(schedule.endHour, equals(17));
      expect(schedule.endMinute, equals(0));
      expect(
        schedule.activeDays,
        equals([
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ]),
      );
      expect(schedule.isValid, isTrue);
      expect(schedule.formattedStartTime, equals('09:00'));
      expect(schedule.formattedEndTime, equals('17:00'));
      expect(schedule.formattedTimeRange, equals('09:00 - 17:00'));
    });

    test('isValid returns false when start time is equal to end time', () {
      const equalTime = ScheduleConfigEntity(
        startHour: 10,
        startMinute: 30,
        endHour: 10,
        endMinute: 30,
      );
      expect(equalTime.isValid, isFalse);
    });

    test('isValid returns true for overnight schedules spanning midnight', () {
      const overnightTime = ScheduleConfigEntity(
        startHour: 18,
        startMinute: 0,
        endHour: 9,
        endMinute: 0,
      );
      expect(overnightTime.isValid, isTrue);

      const nightOwlTime = ScheduleConfigEntity(
        startHour: 22,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
      );
      expect(nightOwlTime.isValid, isTrue);
    });

    test('isValid returns false for out-of-range hours or minutes or days', () {
      const invalidHour = ScheduleConfigEntity(
        startHour: 25,
        endHour: 26,
      );
      expect(invalidHour.isValid, isFalse);

      const invalidMin = ScheduleConfigEntity(
        startHour: 9,
        startMinute: 65,
        endHour: 17,
      );
      expect(invalidMin.isValid, isFalse);

      const invalidDay = ScheduleConfigEntity(
        activeDays: [8],
      );
      expect(invalidDay.isValid, isFalse);

      const emptyDays = ScheduleConfigEntity(
        activeDays: [],
      );
      expect(emptyDays.isValid, isFalse);
    });

    test('isActiveOn returns true for included weekdays', () {
      const schedule = ScheduleConfigEntity(
        activeDays: [DateTime.monday, DateTime.wednesday],
      );
      expect(schedule.isActiveOn(DateTime.monday), isTrue);
      expect(schedule.isActiveOn(DateTime.wednesday), isTrue);
      expect(schedule.isActiveOn(DateTime.tuesday), isFalse);
      expect(schedule.isActiveOn(DateTime.sunday), isFalse);
    });

    test('isWithinSchedule evaluates correctly across days and times', () {
      const schedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        activeDays: [DateTime.monday, DateTime.tuesday],
      );

      // Monday at 10:30 (inside)
      final mondayInside =
          DateTime(2026, 10, 19, 10, 30); // 2026-10-19 is Monday
      expect(schedule.isWithinSchedule(mondayInside), isTrue);

      // Monday at 08:59 (before)
      final mondayBefore = DateTime(2026, 10, 19, 8, 59);
      expect(schedule.isWithinSchedule(mondayBefore), isFalse);

      // Monday at 17:00 (at boundary/end)
      final mondayAtEnd = DateTime(2026, 10, 19, 17, 0);
      expect(schedule.isWithinSchedule(mondayAtEnd), isFalse);

      // Wednesday at 10:30 (inactive day)
      final wednesdayInside = DateTime(2026, 10, 21, 10, 30);
      expect(schedule.isWithinSchedule(wednesdayInside), isFalse);

      // Disabled schedule returns false even during active window
      final disabled = schedule.copyWith(isEnabled: false);
      expect(disabled.isWithinSchedule(mondayInside), isFalse);
    });

    test('isWithinSchedule handles overnight schedules spanning midnight', () {
      const overnightSchedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 22,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
        activeDays: [DateTime.monday],
      );

      // Monday at 21:59 (before start)
      final mondayBefore = DateTime(2026, 10, 19, 21, 59);
      expect(overnightSchedule.isWithinSchedule(mondayBefore), isFalse);

      // Monday at 22:00 (start boundary)
      final mondayStart = DateTime(2026, 10, 19, 22, 0);
      expect(overnightSchedule.isWithinSchedule(mondayStart), isTrue);

      // Monday at 23:45 (late evening inside)
      final mondayLate = DateTime(2026, 10, 19, 23, 45);
      expect(overnightSchedule.isWithinSchedule(mondayLate), isTrue);

      // Tuesday at 02:30 (early morning past midnight belonging to Monday's schedule)
      final tuesdayEarly = DateTime(2026, 10, 20, 2, 30);
      expect(overnightSchedule.isWithinSchedule(tuesdayEarly), isTrue);

      // Tuesday at 05:59 (just before end)
      final tuesdayBeforeEnd = DateTime(2026, 10, 20, 5, 59);
      expect(overnightSchedule.isWithinSchedule(tuesdayBeforeEnd), isTrue);

      // Tuesday at 06:00 (at end boundary - exclusive)
      final tuesdayAtEnd = DateTime(2026, 10, 20, 6, 0);
      expect(overnightSchedule.isWithinSchedule(tuesdayAtEnd), isFalse);

      // Monday at 02:30 (belongs to Sunday night which is inactive)
      final mondayEarly = DateTime(2026, 10, 19, 2, 30);
      expect(overnightSchedule.isWithinSchedule(mondayEarly), isFalse);

      // Monday at 12:00 (noon outside)
      final mondayNoon = DateTime(2026, 10, 19, 12, 0);
      expect(overnightSchedule.isWithinSchedule(mondayNoon), isFalse);

      // Sunday at 23:00 (inactive day)
      final sundayLate = DateTime(2026, 10, 18, 23, 0);
      expect(overnightSchedule.isWithinSchedule(sundayLate), isFalse);

      // When Sunday is active, Monday morning at 02:30 is protected
      final withSunday = overnightSchedule.copyWith(
        activeDays: [DateTime.sunday, DateTime.monday],
      );
      expect(withSunday.isWithinSchedule(mondayEarly), isTrue);
    });

    test('copyWith updates fields correctly', () {
      const initial = ScheduleConfigEntity.initial;
      final updated = initial.copyWith(
        isEnabled: true,
        startHour: 8,
        startMinute: 30,
        endHour: 16,
        endMinute: 45,
        activeDays: [DateTime.saturday, DateTime.sunday],
      );

      expect(updated.isEnabled, isTrue);
      expect(updated.startHour, equals(8));
      expect(updated.startMinute, equals(30));
      expect(updated.endHour, equals(16));
      expect(updated.endMinute, equals(45));
      expect(updated.activeDays, equals([DateTime.saturday, DateTime.sunday]));
    });

    test('props equality holds for identical configurations', () {
      const schedule1 = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        activeDays: [1, 2, 3],
      );
      const schedule2 = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        activeDays: [1, 2, 3],
      );

      expect(schedule1, equals(schedule2));
    });
  });
}
