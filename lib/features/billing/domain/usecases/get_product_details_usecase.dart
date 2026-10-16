import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';

/// Queries store product details for the Lifetime Pro one-time unlock.
class GetProductDetailsUseCase {
  final IBillingRepository _repository;

  const GetProductDetailsUseCase(this._repository);

  Future<ProProductDetailsEntity> call() {
    return _repository.getProDetails();
  }
}
