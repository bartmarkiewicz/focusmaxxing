import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class SyncShieldWithOverlayUseCase {
  final IShieldRepository repository;

  const SyncShieldWithOverlayUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String goal,
    required int remainingSeconds,
    required bool isBreak,
  }) {
    return repository.syncOverlayState(
      goal: goal,
      remainingSeconds: remainingSeconds,
      isBreak: isBreak,
    );
  }
}
