import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/schedule/data/datasources/schedule_alarm_data_source.dart';
import 'package:focusmaxxing/features/schedule/data/datasources/schedule_local_data_source.dart';
import 'package:focusmaxxing/features/schedule/data/models/schedule_config_model.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';

class ScheduleRepositoryImpl implements IScheduleRepository {
  final IScheduleLocalDataSource localDataSource;
  final IScheduleAlarmDataSource alarmDataSource;
  final DateTime Function() _clock;

  ScheduleRepositoryImpl({
    required this.localDataSource,
    required this.alarmDataSource,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @override
  Future<Either<Failure, ScheduleConfigEntity>> getSchedule() async {
    try {
      final model = await localDataSource.getSchedule();
      return Right(model);
    } on ScheduleException catch (e) {
      return Left(ScheduleFailure(e.message));
    } catch (e) {
      return Left(ScheduleFailure('Unexpected error reading schedule: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSchedule(
      ScheduleConfigEntity schedule) async {
    try {
      if (!schedule.isValid) {
        if (schedule.startTotalMinutes == schedule.endTotalMinutes) {
          return const Left(
            ValidationFailure('Start time and end time cannot be identical'),
          );
        }
        if (schedule.activeDays.isEmpty) {
          return const Left(
            ValidationFailure('At least one day must be selected'),
          );
        }
        return const Left(
          ValidationFailure('Invalid schedule configuration'),
        );
      }
      final model = ScheduleConfigModel.fromEntity(schedule);
      await localDataSource.saveSchedule(model);

      if (schedule.isEnabled) {
        await alarmDataSource.scheduleAlarms(schedule);
      } else {
        await alarmDataSource.cancelAlarms();
      }

      return const Right(null);
    } on ScheduleException catch (e) {
      return Left(ScheduleFailure(e.message));
    } catch (e) {
      return Left(ScheduleFailure('Unexpected error saving schedule: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> armAlarms(ScheduleConfigEntity schedule) async {
    try {
      if (!schedule.isValid) {
        return const Left(
          ValidationFailure('Cannot arm alarms with invalid schedule'),
        );
      }
      await alarmDataSource.scheduleAlarms(schedule);
      return const Right(null);
    } on ScheduleException catch (e) {
      return Left(ScheduleFailure(e.message));
    } catch (e) {
      return Left(ScheduleFailure('Failed to arm alarms: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> cancelAlarms() async {
    try {
      await alarmDataSource.cancelAlarms();
      return const Right(null);
    } on ScheduleException catch (e) {
      return Left(ScheduleFailure(e.message));
    } catch (e) {
      return Left(ScheduleFailure('Failed to cancel alarms: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isScheduleActiveNow() async {
    final result = await getSchedule();
    return result.fold(
      Left.new,
      (schedule) {
        if (!schedule.isEnabled) return const Right(false);
        final now = _clock();
        return Right(schedule.isWithinSchedule(now));
      },
    );
  }
}
