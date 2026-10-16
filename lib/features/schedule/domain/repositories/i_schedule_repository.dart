import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';

abstract interface class IScheduleRepository {
  /// Fetches the currently persisted schedule configuration.
  Future<Either<Failure, ScheduleConfigEntity>> getSchedule();

  /// Persists the schedule configuration and synchronizes background alarms if enabled.
  Future<Either<Failure, void>> saveSchedule(ScheduleConfigEntity schedule);

  /// Configures and arms the background OS alarms according to the schedule.
  Future<Either<Failure, void>> armAlarms(ScheduleConfigEntity schedule);

  /// Cancels all pending background schedule alarms.
  Future<Either<Failure, void>> cancelAlarms();

  /// Checks if the current wall-clock time falls inside an active enabled schedule.
  Future<Either<Failure, bool>> isScheduleActiveNow();
}
