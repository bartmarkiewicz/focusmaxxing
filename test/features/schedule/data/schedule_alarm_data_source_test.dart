import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/constants/schedule_constants.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/features/schedule/data/datasources/schedule_alarm_data_source.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleAlarmDataSourceImpl', () {
    late List<int> periodicScheduledIds;
    late List<int> cancelledIds;
    late ScheduleAlarmDataSourceImpl dataSource;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      periodicScheduledIds = [];
      cancelledIds = [];

      dataSource = ScheduleAlarmDataSourceImpl(
        isTestMode: true,
        alarmPeriodicOverride: (
          Duration period,
          int id,
          Function callback, {
          DateTime? startAt,
          bool? exact,
          bool? wakeup,
          bool? rescheduleOnReboot,
        }) async {
          periodicScheduledIds.add(id);
          return true;
        },
        alarmCancelOverride: (int id) async {
          cancelledIds.add(id);
          return true;
        },
      );
    });

    test(
        'scheduleAlarms throws ScheduleException for mathematically invalid schedule',
        () async {
      const invalidSchedule = ScheduleConfigEntity(
        startHour: 10,
        endHour: 10,
      );

      expect(
        () => dataSource.scheduleAlarms(invalidSchedule),
        throwsA(isA<ScheduleException>()),
      );
    });

    test(
        'scheduleAlarms schedules start and end alarms and persists active days',
        () async {
      const validSchedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        activeDays: [1, 2, 3, 4, 5],
      );

      final result = await dataSource.scheduleAlarms(validSchedule);
      expect(result, isTrue);
      expect(
        periodicScheduledIds,
        containsAll(
            [ScheduleConstants.startAlarmId, ScheduleConstants.endAlarmId]),
      );

      final prefs = await SharedPreferences.getInstance();
      final savedDays =
          prefs.getStringList(ScheduleConstants.scheduleActiveDaysPrefsKey);
      expect(savedDays, equals(['1', '2', '3', '4', '5']));
    });

    test('cancelAlarms invokes cancel for both alarm IDs', () async {
      final result = await dataSource.cancelAlarms();
      expect(result, isTrue);
      expect(
        cancelledIds,
        containsAll(
            [ScheduleConstants.startAlarmId, ScheduleConstants.endAlarmId]),
      );
    });

    test(
        'schedules and cancels alarms via native method channel when no override is provided',
        () async {
      const channel = MethodChannel('com.focusmaxxing/shield');
      final log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        return true;
      });

      final nativeSource = ScheduleAlarmDataSourceImpl(
        isTestMode: true,
        methodChannel: channel,
      );

      const validSchedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        activeDays: [1, 2, 3, 4, 5],
      );

      final scheduleResult = await nativeSource.scheduleAlarms(validSchedule);
      expect(scheduleResult, isTrue);

      final cancelResult = await nativeSource.cancelAlarms();
      expect(cancelResult, isTrue);

      expect(
        log.map((c) => c.method),
        containsAll(['scheduleAlarms', 'cancelAlarms']),
      );
    });

    test(
        'computeNextAlarmTimes activates immediately when enabled inside an active overnight window before midnight',
        () {
      const overnightSchedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 22,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
        activeDays: [1, 2, 3, 4, 5],
      );
      final now = DateTime(2026, 10, 26, 23, 30); // Monday 23:30

      final (:nextStart, :nextEnd) =
          ScheduleAlarmDataSourceImpl.computeNextAlarmTimes(
        overnightSchedule,
        now,
      );

      expect(nextStart, equals(now));
      expect(nextEnd, equals(DateTime(2026, 10, 27, 6, 0)));
    });

    test(
        'computeNextAlarmTimes activates immediately when enabled inside an active overnight window after midnight',
        () {
      const overnightSchedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 22,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
        activeDays: [1, 2, 3, 4, 5],
      );
      final now = DateTime(2026, 10, 31, 1, 30); // Saturday 01:30 (Friday night window)

      final (:nextStart, :nextEnd) =
          ScheduleAlarmDataSourceImpl.computeNextAlarmTimes(
        overnightSchedule,
        now,
      );

      expect(nextStart, equals(now));
      expect(nextEnd, equals(DateTime(2026, 10, 31, 6, 0)));
    });

    test(
        'computeNextAlarmTimes schedules next start and next-day end when outside overnight window',
        () {
      const overnightSchedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 22,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
        activeDays: [1, 2, 3, 4, 5],
      );
      final now = DateTime(2026, 10, 26, 20, 0); // Monday 20:00

      final (:nextStart, :nextEnd) =
          ScheduleAlarmDataSourceImpl.computeNextAlarmTimes(
        overnightSchedule,
        now,
      );

      expect(nextStart, equals(DateTime(2026, 10, 26, 22, 0)));
      expect(nextEnd, equals(DateTime(2026, 10, 27, 6, 0)));
    });

    test(
        'computeNextAlarmTimes skips inactive weekend days and preserves wall-clock hour and minute',
        () {
      const weekdaySchedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 9,
        startMinute: 30,
        endHour: 17,
        endMinute: 30,
        activeDays: [1, 2, 3, 4, 5],
      );
      final fridayNight = DateTime(2026, 10, 30, 18, 0); // Friday 18:00

      final (:nextStart, :nextEnd) =
          ScheduleAlarmDataSourceImpl.computeNextAlarmTimes(
        weekdaySchedule,
        fridayNight,
      );

      expect(nextStart, equals(DateTime(2026, 11, 2, 9, 30))); // Monday 09:30
      expect(nextEnd, equals(DateTime(2026, 11, 2, 17, 30))); // Monday 17:30
    });
  });
}
