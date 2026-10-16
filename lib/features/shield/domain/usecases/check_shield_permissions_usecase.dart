import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class CheckShieldPermissionsUseCase {
  final IShieldRepository repository;

  const CheckShieldPermissionsUseCase(this.repository);

  Future<Either<Failure, ShieldPermissionStatus>> call() {
    return repository.checkPermissions();
  }
}
