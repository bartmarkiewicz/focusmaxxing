import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';

/// Evaluates if the current wall-clock time falls inside an active auto-shield schedule window.
class CheckScheduleActiveNowUseCase {
  final IScheduleRepository repository;

  const CheckScheduleActiveNowUseCase(this.repository);

  Future<Either<Failure, bool>> call() => repository.isScheduleActiveNow();
}
