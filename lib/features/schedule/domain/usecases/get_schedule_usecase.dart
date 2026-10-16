import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';

class GetScheduleUseCase {
  final IScheduleRepository repository;

  const GetScheduleUseCase(this.repository);

  Future<Either<Failure, ScheduleConfigEntity>> call() =>
      repository.getSchedule();
}
