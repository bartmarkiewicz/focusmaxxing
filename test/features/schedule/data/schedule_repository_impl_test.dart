import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/schedule/data/datasources/schedule_alarm_data_source.dart';
import 'package:focusmaxxing/features/schedule/data/datasources/schedule_local_data_source.dart';
import 'package:focusmaxxing/features/schedule/data/models/schedule_config_model.dart';
import 'package:focusmaxxing/features/schedule/data/repositories/schedule_repository_impl.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';

class FakeScheduleLocalDataSource implements IScheduleLocalDataSource {
  ScheduleConfigModel storedModel = const ScheduleConfigModel();
  bool shouldThrow = false;

  @override
  Future<ScheduleConfigModel> getSchedule() async {
    if (shouldThrow) {
      throw const ScheduleException('Storage read failure');
    }
    return storedModel;
  }

  @override
  Future<void> saveSchedule(ScheduleConfigModel schedule) async {
    if (shouldThrow) {
      throw const ScheduleException('Storage write failure');
    }
    storedModel = schedule;
  }
}

class FakeScheduleAlarmDataSource implements IScheduleAlarmDataSource {
  bool alarmsScheduled = false;
  bool alarmsCancelled = false;
  bool shouldThrow = false;

  @override
  Future<bool> scheduleAlarms(ScheduleConfigEntity schedule) async {
    if (shouldThrow) {
      throw const ScheduleException('Alarm arming failure');
    }
    alarmsScheduled = true;
    alarmsCancelled = false;
    return true;
  }

  @override
  Future<bool> cancelAlarms() async {
    if (shouldThrow) {
      throw const ScheduleException('Alarm cancellation failure');
    }
    alarmsCancelled = true;
    alarmsScheduled = false;
    return true;
  }
}

void main() {
  group('ScheduleRepositoryImpl', () {
    late FakeScheduleLocalDataSource localDataSource;
    late FakeScheduleAlarmDataSource alarmDataSource;
    late ScheduleRepositoryImpl repository;
    DateTime simulatedNow = DateTime(2026, 10, 19, 11, 0); // Monday 11:00

    setUp(() {
      localDataSource = FakeScheduleLocalDataSource();
      alarmDataSource = FakeScheduleAlarmDataSource();
      simulatedNow = DateTime(2026, 10, 19, 11, 0);
      repository = ScheduleRepositoryImpl(
        localDataSource: localDataSource,
        alarmDataSource: alarmDataSource,
        clock: () => simulatedNow,
      );
    });

    test('getSchedule returns entity from localDataSource', () async {
      localDataSource.storedModel = const ScheduleConfigModel(
        isEnabled: true,
        startHour: 8,
        startMinute: 0,
        endHour: 16,
        endMinute: 0,
      );

      final result = await repository.getSchedule();
      expect(result.isRight(), isTrue);
      final entity = result.getOrElse(() => throw Exception());
      expect(entity.isEnabled, isTrue);
      expect(entity.startHour, equals(8));
      expect(entity.endHour, equals(16));
    });

    test('getSchedule returns ScheduleFailure on exception', () async {
      localDataSource.shouldThrow = true;
      final result = await repository.getSchedule();
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ScheduleFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('saveSchedule arms alarms when isEnabled is true', () async {
      const schedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
      );

      final result = await repository.saveSchedule(schedule);
      expect(result.isRight(), isTrue);
      expect(localDataSource.storedModel.isEnabled, isTrue);
      expect(alarmDataSource.alarmsScheduled, isTrue);
      expect(alarmDataSource.alarmsCancelled, isFalse);
    });

    test('saveSchedule cancels alarms when isEnabled is false', () async {
      const schedule = ScheduleConfigEntity(
        isEnabled: false,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
      );

      final result = await repository.saveSchedule(schedule);
      expect(result.isRight(), isTrue);
      expect(localDataSource.storedModel.isEnabled, isFalse);
      expect(alarmDataSource.alarmsCancelled, isTrue);
      expect(alarmDataSource.alarmsScheduled, isFalse);
    });

    test('saveSchedule returns ValidationFailure if schedule is invalid', () async {
      const invalidSchedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 17,
        startMinute: 0,
        endHour: 9,
        endMinute: 0,
      );

      final result = await repository.saveSchedule(invalidSchedule);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected failure'),
      );
      expect(alarmDataSource.alarmsScheduled, isFalse);
    });

    test('isScheduleActiveNow checks clock against schedule bounds', () async {
      localDataSource.storedModel = const ScheduleConfigModel(
        isEnabled: true,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        activeDays: [DateTime.monday],
      );

      // Monday 11:00 -> active
      simulatedNow = DateTime(2026, 10, 19, 11, 0);
      final activeResult = await repository.isScheduleActiveNow();
      expect(activeResult, equals(const Right<Failure, bool>(true)));

      // Monday 18:00 -> inactive
      simulatedNow = DateTime(2026, 10, 19, 18, 0);
      final inactiveResult = await repository.isScheduleActiveNow();
      expect(inactiveResult, equals(const Right<Failure, bool>(false)));

      // Tuesday 11:00 -> inactive day
      simulatedNow = DateTime(2026, 10, 20, 11, 0);
      final dayMismatchResult = await repository.isScheduleActiveNow();
      expect(dayMismatchResult, equals(const Right<Failure, bool>(false)));
    });
  });
}
