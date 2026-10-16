import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/save_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/toggle_auto_shield_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/check_schedule_active_now_usecase.dart';

class FakeScheduleRepository implements IScheduleRepository {
  ScheduleConfigEntity schedule = ScheduleConfigEntity.initial;
  bool armAlarmsCalled = false;
  bool cancelAlarmsCalled = false;

  @override
  Future<Either<Failure, ScheduleConfigEntity>> getSchedule() async {
    return Right(schedule);
  }

  @override
  Future<Either<Failure, void>> saveSchedule(ScheduleConfigEntity newSchedule) async {
    schedule = newSchedule;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> armAlarms(ScheduleConfigEntity newSchedule) async {
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
  group('Schedule UseCases', () {
    late FakeScheduleRepository repository;
    late GetScheduleUseCase getScheduleUseCase;
    late SaveScheduleUseCase saveScheduleUseCase;
    late ToggleAutoShieldUseCase toggleAutoShieldUseCase;

    setUp(() {
      repository = FakeScheduleRepository();
      getScheduleUseCase = GetScheduleUseCase(repository);
      saveScheduleUseCase = SaveScheduleUseCase(repository);
      toggleAutoShieldUseCase = ToggleAutoShieldUseCase(repository);
    });

    test('GetScheduleUseCase returns current schedule from repository', () async {
      final result = await getScheduleUseCase();
      expect(result.isRight(), isTrue);
      expect(result.getOrElse(() => throw Exception()), equals(ScheduleConfigEntity.initial));
    });

    test('SaveScheduleUseCase succeeds for valid schedule', () async {
      const validSchedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
      );

      final result = await saveScheduleUseCase(validSchedule);
      expect(result.isRight(), isTrue);
      expect(repository.schedule, equals(validSchedule));
    });

    test('SaveScheduleUseCase returns ValidationFailure when schedule is invalid', () async {
      const invalidSchedule = ScheduleConfigEntity(
        isEnabled: true,
        startHour: 18,
        startMinute: 0,
        endHour: 9,
        endMinute: 0,
      );

      final result = await saveScheduleUseCase(invalidSchedule);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('ToggleAutoShieldUseCase toggles enabled state and persists', () async {
      final result = await toggleAutoShieldUseCase(true);
      expect(result.isRight(), isTrue);
      expect(repository.schedule.isEnabled, isTrue);

      final toggleOff = await toggleAutoShieldUseCase(false);
      expect(toggleOff.isRight(), isTrue);
      expect(repository.schedule.isEnabled, isFalse);
    });

    test('CheckScheduleActiveNowUseCase returns repository evaluation', () async {
      final checkUseCase = CheckScheduleActiveNowUseCase(repository);
      repository.schedule = const ScheduleConfigEntity(isEnabled: true);
      final activeResult = await checkUseCase();
      expect(activeResult, equals(const Right(true)));

      repository.schedule = const ScheduleConfigEntity(isEnabled: false);
      final inactiveResult = await checkUseCase();
      expect(inactiveResult, equals(const Right(false)));
    });
  });
}
