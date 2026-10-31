import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class StopShieldServiceUseCase {
  final IShieldRepository repository;

  const StopShieldServiceUseCase(this.repository);

  Future<Either<Failure, bool>> call({bool force = false}) {
    return repository.stopShieldService(force: force);
  }
}
