import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class BringAppToForegroundUseCase {
  final IShieldRepository repository;

  const BringAppToForegroundUseCase(this.repository);

  Future<Either<Failure, bool>> call() {
    return repository.bringAppToForeground();
  }
}
