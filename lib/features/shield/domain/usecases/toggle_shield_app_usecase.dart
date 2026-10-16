import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class ToggleShieldAppUseCase {
  final IShieldRepository repository;

  const ToggleShieldAppUseCase(this.repository);

  Future<Either<Failure, ShieldedAppEntity>> call({
    required String packageName,
    required String appName,
    required bool isActive,
    bool isPreset = false,
    Uint8List? iconBytes,
  }) {
    final trimmedPkg = packageName.trim();
    if (trimmedPkg.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Package name cannot be empty')),
      );
    }
    return repository.toggleShieldApp(
      packageName: trimmedPkg,
      appName: appName.trim().isNotEmpty ? appName.trim() : trimmedPkg,
      isActive: isActive,
      isPreset: isPreset,
      iconBytes: iconBytes,
    );
  }
}
