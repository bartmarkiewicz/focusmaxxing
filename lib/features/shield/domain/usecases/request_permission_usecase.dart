import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class RequestPermissionUseCase {
  final IShieldRepository repository;

  const RequestPermissionUseCase(this.repository);

  Future<Either<Failure, bool>> call(ShieldPermissionType permissionType) {
    return repository.requestPermission(permissionType);
  }
}
