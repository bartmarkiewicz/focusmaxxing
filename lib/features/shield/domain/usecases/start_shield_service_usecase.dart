import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class StartShieldServiceUseCase {
  final IShieldRepository repository;

  const StartShieldServiceUseCase(this.repository);

  Future<Either<Failure, bool>> call(
    List<String> blockedPackages, {
    bool isScheduled = false,
    String? timeRange,
  }) {
    return repository.startShieldService(
      blockedPackages,
      isScheduled: isScheduled,
      timeRange: timeRange,
    );
  }
}
