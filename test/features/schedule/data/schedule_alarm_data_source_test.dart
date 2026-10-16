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

    test('scheduleAlarms throws ScheduleException for mathematically invalid schedule', () async {
      const invalidSchedule = ScheduleConfigEntity(
        startHour: 10,
        endHour: 10,
      );

      expect(
        () => dataSource.scheduleAlarms(invalidSchedule),
        throwsA(isA<ScheduleException>()),
      );
    });

    test('scheduleAlarms schedules start and end alarms and persists active days', () async {
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
        containsAll([ScheduleConstants.startAlarmId, ScheduleConstants.endAlarmId]),
      );

      final prefs = await SharedPreferences.getInstance();
      final savedDays = prefs.getStringList(ScheduleConstants.scheduleActiveDaysPrefsKey);
      expect(savedDays, equals(['1', '2', '3', '4', '5']));
    });

    test('cancelAlarms invokes cancel for both alarm IDs', () async {
      final result = await dataSource.cancelAlarms();
      expect(result, isTrue);
      expect(
        cancelledIds,
        containsAll([ScheduleConstants.startAlarmId, ScheduleConstants.endAlarmId]),
      );
    });
  });
}
