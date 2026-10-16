import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/billing/data/datasources/billing_local_cache_source.dart';
import 'package:focusmaxxing/features/billing/data/datasources/in_app_purchase_client.dart';
import 'package:focusmaxxing/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeInAppPurchaseClient implements IInAppPurchaseClient {
  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  bool available = true;
  bool buyResult = true;
  List<ProductDetails> productsToReturn = <ProductDetails>[
    ProductDetails(
      id: ProUnlockStatusEntity.lifetimeProProductId,
      title: 'Lifetime Pro',
      description: 'Unlock all features',
      price: r'$9.99',
      rawPrice: 9.99,
      currencyCode: 'USD',
    ),
  ];
  IAPError? queryError;
  final List<PurchaseDetails> completedPurchases = <PurchaseDetails>[];
  bool restorePurchasesCalled = false;
  List<PurchaseDetails>? purchasesToEmitOnBuy;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: productsToReturn,
      notFoundIDs: const <String>[],
      error: queryError,
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    final toEmit = purchasesToEmitOnBuy;
    if (toEmit != null) {
      scheduleMicrotask(() => emitPurchases(toEmit));
    }
    return buyResult;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorePurchasesCalled = true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  void emitPurchases(List<PurchaseDetails> purchases) {
    controller.add(purchases);
  }

  Future<void> dispose() async {
    await controller.close();
  }
}

PurchaseDetails _createPurchase({
  required PurchaseStatus status,
  String productID = ProUnlockStatusEntity.lifetimeProProductId,
  String purchaseID = 'ORDER_123',
  bool pendingComplete = true,
  String? errorMessage,
}) {
  final purchase = PurchaseDetails(
    productID: productID,
    purchaseID: purchaseID,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local_receipt_$purchaseID',
      serverVerificationData: 'server_receipt_$purchaseID',
      source: 'google_play',
    ),
    transactionDate: '1729000000000',
    status: status,
  );
  purchase.pendingCompletePurchase = pendingComplete;
  if (errorMessage != null) {
    purchase.error = IAPError(
      source: 'google_play',
      code: 'billing_err',
      message: errorMessage,
    );
  }
  return purchase;
}

void main() {
  group('BillingRepositoryImpl', () {
    late SharedPreferences prefs;
    late BillingLocalCacheSourceImpl localCache;
    late _FakeInAppPurchaseClient iapClient;
    late BillingRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      localCache = BillingLocalCacheSourceImpl(sharedPreferences: prefs);
      iapClient = _FakeInAppPurchaseClient();
      repository = BillingRepositoryImpl(
        iapClient: iapClient,
        localCacheSource: localCache,
        restoreTimeout: const Duration(milliseconds: 100),
      );
    });

    tearDown(() async {
      await repository.dispose();
      await iapClient.dispose();
    });

    test('getProDetails returns product metadata from store when available', () async {
      final details = await repository.getProDetails();

      expect(details.id, ProUnlockStatusEntity.lifetimeProProductId);
      expect(details.title, 'Lifetime Pro');
      expect(details.price, r'$9.99');
    });

    test('getProDetails falls back to default pricing if store is unavailable', () async {
      iapClient.available = false;

      final details = await repository.getProDetails();

      expect(details.id, ProUnlockStatusEntity.lifetimeProProductId);
      expect(details.price, ProUnlockStatusEntity.defaultFormattedPrice);
    });

    test('purchaseLifetimePro completes successfully and persists receipt', () async {
      iapClient.purchasesToEmitOnBuy = [
        _createPurchase(status: PurchaseStatus.purchased, purchaseID: 'ORDER_555'),
      ];

      final status = await repository.purchaseLifetimePro();

      expect(status.isUnlocked, isTrue);
      expect(status.orderId, 'ORDER_555');
      expect(iapClient.completedPurchases, hasLength(1));

      // Local storage is updated
      final cached = await repository.getCachedProStatus();
      expect(cached.isUnlocked, isTrue);
      expect(cached.orderId, 'ORDER_555');
    });

    test('purchaseLifetimePro throws cancellation exception on PurchaseStatus.canceled', () async {
      iapClient.purchasesToEmitOnBuy = [
        _createPurchase(status: PurchaseStatus.canceled),
      ];

      expect(
        repository.purchaseLifetimePro(),
        throwsA(
          isA<BillingFailureException>().having(
            (e) => e.isCancelled,
            'isCancelled',
            isTrue,
          ),
        ),
      );
    });

    test('purchaseLifetimePro throws failure exception on PurchaseStatus.error', () async {
      iapClient.purchasesToEmitOnBuy = [
        _createPurchase(
          status: PurchaseStatus.error,
          errorMessage: 'User credit card declined',
        ),
      ];

      expect(
        repository.purchaseLifetimePro(),
        throwsA(
          isA<BillingFailureException>().having(
            (e) => e.message,
            'message',
            contains('User credit card declined'),
          ),
        ),
      );
    });

    test('restorePurchases restores entitlement when store stream emits restored purchase', () async {
      final restoreFuture = repository.restorePurchases();

      iapClient.emitPurchases([
        _createPurchase(status: PurchaseStatus.restored, purchaseID: 'RESTORED_777'),
      ]);

      final status = await restoreFuture;

      expect(status.isUnlocked, isTrue);
      expect(status.orderId, 'RESTORED_777');
      expect(await repository.isProPurchased(), isTrue);
    });

    test('restorePurchases succeeds even if stream contains a past cancelled transaction', () async {
      final restoreFuture = repository.restorePurchases();

      iapClient.emitPurchases([
        _createPurchase(status: PurchaseStatus.canceled, purchaseID: 'OLD_CANCEL'),
        _createPurchase(status: PurchaseStatus.restored, purchaseID: 'RESTORED_888'),
      ]);

      final status = await restoreFuture;

      expect(status.isUnlocked, isTrue);
      expect(status.orderId, 'RESTORED_888');
    });

    test('restorePurchases falls back to local cache if no purchases exist in store', () async {
      final status = await repository.restorePurchases();

      expect(status.isUnlocked, isFalse);
    });
  });
}
