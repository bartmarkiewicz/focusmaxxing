import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/get_product_details_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/purchase_lifetime_pro_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/restore_purchases_usecase.dart';

class _FakeBillingRepository implements IBillingRepository {
  final StreamController<ProUnlockStatusEntity> _controller =
      StreamController<ProUnlockStatusEntity>.broadcast();

  ProProductDetailsEntity productDetails = ProProductDetailsEntity.fallback;
  ProUnlockStatusEntity proStatus = ProUnlockStatusEntity.locked;
  bool shouldFailPurchase = false;
  bool shouldCancelPurchase = false;

  @override
  Stream<ProUnlockStatusEntity> get purchaseStatusStream => _controller.stream;

  @override
  Future<ProProductDetailsEntity> getProDetails() async => productDetails;

  @override
  Future<ProUnlockStatusEntity> purchaseLifetimePro() async {
    if (shouldCancelPurchase) {
      throw const BillingFailureException('Cancelled', isCancelled: true);
    }
    if (shouldFailPurchase) {
      throw const BillingFailureException('Card declined');
    }
    proStatus = const ProUnlockStatusEntity(
      isUnlocked: true,
      orderId: 'GPA.1234-5678',
      purchaseDateMs: 1700000000000,
    );
    _controller.add(proStatus);
    return proStatus;
  }

  @override
  Future<ProUnlockStatusEntity> restorePurchases() async {
    proStatus = const ProUnlockStatusEntity(
      isUnlocked: true,
      orderId: 'GPA.RESTORED-999',
    );
    _controller.add(proStatus);
    return proStatus;
  }

  @override
  Future<bool> isProPurchased() async => proStatus.isUnlocked;

  @override
  Future<ProUnlockStatusEntity> getCachedProStatus() async => proStatus;

  @override
  Future<void> dispose() async => _controller.close();
}

void main() {
  group('Billing Use Cases', () {
    late _FakeBillingRepository repository;

    setUp(() {
      repository = _FakeBillingRepository();
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('GetProductDetailsUseCase forwards query to repository', () async {
      final useCase = GetProductDetailsUseCase(repository);
      final details = await useCase();

      expect(details.id, ProUnlockStatusEntity.lifetimeProProductId);
      expect(details.price, r'$9.99');
      expect(details.rawPrice, 9.99);
    });

    test('PurchaseLifetimeProUseCase executes purchase successfully', () async {
      final useCase = PurchaseLifetimeProUseCase(repository);
      final status = await useCase();

      expect(status.isUnlocked, isTrue);
      expect(status.orderId, 'GPA.1234-5678');
    });

    test('RestorePurchasesUseCase triggers restore flow on repository', () async {
      final useCase = RestorePurchasesUseCase(repository);
      final status = await useCase();

      expect(status.isUnlocked, isTrue);
      expect(status.orderId, 'GPA.RESTORED-999');
    });
  });
}
