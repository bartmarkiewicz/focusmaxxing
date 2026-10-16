import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';

/// Executes the non-consumable Lifetime Pro purchase transaction.
class PurchaseLifetimeProUseCase {
  final IBillingRepository _repository;

  const PurchaseLifetimeProUseCase(this._repository);

  Future<ProUnlockStatusEntity> call() {
    return _repository.purchaseLifetimePro();
  }
}
