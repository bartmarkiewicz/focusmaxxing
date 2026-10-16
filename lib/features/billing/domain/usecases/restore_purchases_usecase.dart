import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';

/// Restores previously purchased Lifetime Pro entitlements from Google Play.
class RestorePurchasesUseCase {
  final IBillingRepository _repository;

  const RestorePurchasesUseCase(this._repository);

  Future<ProUnlockStatusEntity> call() {
    return _repository.restorePurchases();
  }
}
