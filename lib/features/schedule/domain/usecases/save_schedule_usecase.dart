import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';

class SaveScheduleUseCase {
  final IScheduleRepository repository;

  const SaveScheduleUseCase(this.repository);

  Future<Either<Failure, void>> call(ScheduleConfigEntity schedule) async {
    if (!schedule.isValid) {
      return const Left(
        ValidationFailure('Start time must precede end time'),
      );
    }
    return repository.saveSchedule(schedule);
  }
}
