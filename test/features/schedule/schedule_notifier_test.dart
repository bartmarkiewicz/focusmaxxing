import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/security/pro_receipt_verifier.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/save_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/toggle_auto_shield_usecase.dart';
import 'package:focusmaxxing/features/schedule/presentation/notifiers/schedule_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockScheduleRepository implements IScheduleRepository {
  ScheduleConfigEntity schedule = ScheduleConfigEntity.initial;
  bool armAlarmsCalled = false;
  bool cancelAlarmsCalled = false;
  bool shouldFailSave = false;

  @override
  Future<Either<Failure, ScheduleConfigEntity>> getSchedule() async {
    return Right(schedule);
  }

  @override
  Future<Either<Failure, void>> saveSchedule(
      ScheduleConfigEntity newSchedule) async {
    if (shouldFailSave) {
      return const Left(ScheduleFailure('Failed to save schedule'));
    }
    schedule = newSchedule;
    if (newSchedule.isEnabled) {
      armAlarmsCalled = true;
      cancelAlarmsCalled = false;
    } else {
      cancelAlarmsCalled = true;
      armAlarmsCalled = false;
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> armAlarms(
      ScheduleConfigEntity newSchedule) async {
    armAlarmsCalled = true;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> cancelAlarms() async {
    cancelAlarmsCalled = true;
    return const Right(null);
  }

  @override
  Future<Either<Failure, bool>> isScheduleActiveNow() async {
    return Right(schedule.isEnabled);
  }
}

void main() {
  group('ScheduleNotifier', () {
    late MockScheduleRepository repository;
    late GetScheduleUseCase getScheduleUseCase;
    late SaveScheduleUseCase saveScheduleUseCase;
    late ToggleAutoShieldUseCase toggleAutoShieldUseCase;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = MockScheduleRepository();
      getScheduleUseCase = GetScheduleUseCase(repository);
      saveScheduleUseCase = SaveScheduleUseCase(repository);
      toggleAutoShieldUseCase = ToggleAutoShieldUseCase(repository);
    });

    test('loads persisted schedule on initialization', () async {
      final notifier = ScheduleNotifier(
        getScheduleUseCase: getScheduleUseCase,
        saveScheduleUseCase: saveScheduleUseCase,
        toggleAutoShieldUseCase: toggleAutoShieldUseCase,
        repository: repository,
        autoInitialize: true,
      );

      await Future<void>.delayed(Duration.zero);
      expect(notifier.schedule, equals(ScheduleConfigEntity.initial));
      expect(notifier.isEnabled, isFalse);
      expect(notifier.formattedTimeRange, equals('09:00 - 17:00'));
    });

    test('enforcing Pro gating: non-pro user cannot enable auto-shield',
        () async {
      SharedPreferences.setMockInitialValues({'is_lifetime_pro': false});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ScheduleNotifier(
        getScheduleUseCase: getScheduleUseCase,
        saveScheduleUseCase: saveScheduleUseCase,
        toggleAutoShieldUseCase: toggleAutoShieldUseCase,
        repository: repository,
        sharedPreferences: prefs,
        autoInitialize: false,
      );

      final success = await notifier.setEnabled(true);
      expect(success, isFalse);
      expect(notifier.requiresProPrompt, isTrue);
      expect(notifier.isEnabled, isFalse);

      notifier.dismissProPrompt();
      expect(notifier.requiresProPrompt, isFalse);
    });

    test('pro user can enable auto-shield, arming background alarms', () async {
      SharedPreferences.setMockInitialValues({
        ProReceiptVerifier.encryptedReceiptPrefsKey:
            ProReceiptVerifier.encodeSignedReceipt(isUnlocked: true),
      });
      final prefs = await SharedPreferences.getInstance();

      final notifier = ScheduleNotifier(
        getScheduleUseCase: getScheduleUseCase,
        saveScheduleUseCase: saveScheduleUseCase,
        toggleAutoShieldUseCase: toggleAutoShieldUseCase,
        repository: repository,
        sharedPreferences: prefs,
        autoInitialize: false,
      );

      final success = await notifier.setEnabled(true);
      expect(success, isTrue);
      expect(notifier.isEnabled, isTrue);
      expect(repository.armAlarmsCalled, isTrue);

      final disableSuccess = await notifier.setEnabled(false);
      expect(disableSuccess, isTrue);
      expect(notifier.isEnabled, isFalse);
      expect(repository.cancelAlarmsCalled, isTrue);
    });

    test(
        'rejects tampered plaintext is_lifetime_pro when cryptographic receipt is missing',
        () async {
      SharedPreferences.setMockInitialValues({'is_lifetime_pro': true});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ScheduleNotifier(
        getScheduleUseCase: getScheduleUseCase,
        saveScheduleUseCase: saveScheduleUseCase,
        toggleAutoShieldUseCase: toggleAutoShieldUseCase,
        repository: repository,
        sharedPreferences: prefs,
        autoInitialize: false,
      );

      expect(notifier.isPro, isFalse);
      final success = await notifier.setEnabled(true);
      expect(success, isFalse);
      expect(notifier.requiresProPrompt, isTrue);
    });

    test('setStartTime validates identical times while allowing overnight schedules', () async {
      final notifier = ScheduleNotifier(
        getScheduleUseCase: getScheduleUseCase,
        saveScheduleUseCase: saveScheduleUseCase,
        toggleAutoShieldUseCase: toggleAutoShieldUseCase,
        repository: repository,
        autoInitialize: false,
      );

      // End time is 17:00. Trying to set start time to 17:00 fails (identical times)
      final failResult = await notifier.setStartTime(17, 0);
      expect(failResult, isFalse);
      expect(notifier.errorMessage, equals('Start time and end time cannot be identical'));

      // Setting overnight start time 22:00 succeeds
      final overnightResult = await notifier.setStartTime(22, 0);
      expect(overnightResult, isTrue);
      expect(notifier.errorMessage, isNull);
      expect(notifier.startHour, equals(22));
      expect(notifier.startMinute, equals(0));

      // Setting daytime start time 08:30 succeeds
      final okResult = await notifier.setStartTime(8, 30);
      expect(okResult, isTrue);
      expect(notifier.errorMessage, isNull);
      expect(notifier.startHour, equals(8));
      expect(notifier.startMinute, equals(30));
    });

    test('setEndTime validates identical times while allowing overnight schedules', () async {
      final notifier = ScheduleNotifier(
        getScheduleUseCase: getScheduleUseCase,
        saveScheduleUseCase: saveScheduleUseCase,
        toggleAutoShieldUseCase: toggleAutoShieldUseCase,
        repository: repository,
        autoInitialize: false,
      );

      // Start time is 09:00. Trying to set end time to 09:00 fails (identical times)
      final failResult = await notifier.setEndTime(9, 0);
      expect(failResult, isFalse);
      expect(notifier.errorMessage, equals('Start time and end time cannot be identical'));

      // Setting overnight end time 06:00 succeeds
      final overnightResult = await notifier.setEndTime(6, 0);
      expect(overnightResult, isTrue);
      expect(notifier.errorMessage, isNull);
      expect(notifier.endHour, equals(6));
      expect(notifier.endMinute, equals(0));

      // Setting daytime end time 18:00 succeeds
      final okResult = await notifier.setEndTime(18, 0);
      expect(okResult, isTrue);
      expect(notifier.errorMessage, isNull);
      expect(notifier.endHour, equals(18));
      expect(notifier.endMinute, equals(0));
    });

    test('toggleWeekday adds and removes active weekdays', () async {
      final notifier = ScheduleNotifier(
        getScheduleUseCase: getScheduleUseCase,
        saveScheduleUseCase: saveScheduleUseCase,
        toggleAutoShieldUseCase: toggleAutoShieldUseCase,
        repository: repository,
        autoInitialize: false,
      );

      // Saturday is not in default schedule (Mon-Fri)
      expect(notifier.activeDays.contains(DateTime.saturday), isFalse);
      final addSaturday = await notifier.toggleWeekday(DateTime.saturday);
      expect(addSaturday, isTrue);
      expect(notifier.activeDays.contains(DateTime.saturday), isTrue);

      // Remove Friday
      final removeFriday = await notifier.toggleWeekday(DateTime.friday);
      expect(removeFriday, isTrue);
      expect(notifier.activeDays.contains(DateTime.friday), isFalse);
    });

    test('toggleWeekday disallows removing all days when schedule is enabled',
        () async {
      repository.schedule = const ScheduleConfigEntity(
        isEnabled: true,
        activeDays: [DateTime.monday],
      );

      final notifier = ScheduleNotifier(
        getScheduleUseCase: getScheduleUseCase,
        saveScheduleUseCase: saveScheduleUseCase,
        toggleAutoShieldUseCase: toggleAutoShieldUseCase,
        repository: repository,
        autoInitialize: true,
      );
      await Future<void>.delayed(Duration.zero);

      final removeResult = await notifier.toggleWeekday(DateTime.monday);
      expect(removeResult, isFalse);
      expect(
        notifier.errorMessage,
        equals('Schedule must include at least one active day'),
      );
      expect(notifier.activeDays, equals([DateTime.monday]));
    });

    test(
        'unlockLifetimePro updates isPro, dismisses prompt, and persists to SharedPreferences',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = ScheduleNotifier(
        getScheduleUseCase: getScheduleUseCase,
        saveScheduleUseCase: saveScheduleUseCase,
        toggleAutoShieldUseCase: toggleAutoShieldUseCase,
        repository: repository,
        sharedPreferences: prefs,
        autoInitialize: false,
      );

      await notifier.unlockLifetimePro();
      expect(notifier.isPro, isTrue);
      expect(notifier.requiresProPrompt, isFalse);
      expect(prefs.getBool('is_lifetime_pro'), isTrue);
    });
  });
}
