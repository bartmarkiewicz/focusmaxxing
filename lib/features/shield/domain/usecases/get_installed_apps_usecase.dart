import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class GetInstalledAppsUseCase {
  final IShieldRepository repository;

  const GetInstalledAppsUseCase(this.repository);

  Future<Either<Failure, List<ShieldedAppEntity>>> call() {
    return repository.getInstalledApps();
  }
}
