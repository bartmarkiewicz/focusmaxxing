import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';

class ToggleAutoShieldUseCase {
  final IScheduleRepository repository;

  const ToggleAutoShieldUseCase(this.repository);

  Future<Either<Failure, ScheduleConfigEntity>> call(bool isEnabled) async {
    final currentResult = await repository.getSchedule();
    return currentResult.fold(
      Left.new,
      (currentSchedule) async {
        final updatedSchedule = currentSchedule.copyWith(isEnabled: isEnabled);
        if (isEnabled && !updatedSchedule.isValid) {
          return const Left(
            ValidationFailure('Invalid schedule configuration'),
          );
        }
        final saveResult = await repository.saveSchedule(updatedSchedule);
        return saveResult.fold(
          Left.new,
          (_) => Right(updatedSchedule),
        );
      },
    );
  }
}
