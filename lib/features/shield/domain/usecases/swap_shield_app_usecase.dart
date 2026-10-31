import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';

class SwapShieldAppUseCase {
  final IShieldRepository repository;

  const SwapShieldAppUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String deactivatePackageName,
    required String activatePackageName,
    required String activateAppName,
    bool activateIsPreset = false,
  }) {
    final trimmedDeactivate = deactivatePackageName.trim();
    final trimmedActivate = activatePackageName.trim();
    if (trimmedDeactivate.isEmpty || trimmedActivate.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Package names cannot be empty')),
      );
    }
    return repository.swapShieldApp(
      deactivatePackageName: trimmedDeactivate,
      activatePackageName: trimmedActivate,
      activateAppName: activateAppName.trim().isNotEmpty
          ? activateAppName.trim()
          : trimmedActivate,
      activateIsPreset: activateIsPreset,
    );
  }
}
