import 'dart:async';

import 'package:focusmaxxing/features/billing/data/datasources/billing_local_cache_source.dart';
import 'package:focusmaxxing/features/billing/data/datasources/in_app_purchase_client.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Concrete implementation of [IBillingRepository] backed by Google Play
/// Billing (`in_app_purchase`) and offline-tolerant encrypted local caching.
class BillingRepositoryImpl implements IBillingRepository {
  final IInAppPurchaseClient _iapClient;
  final IBillingLocalCacheSource _localCacheSource;
  final Duration restoreTimeout;

  final StreamController<ProUnlockStatusEntity> _statusController =
      StreamController<ProUnlockStatusEntity>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  ProductDetails? _cachedProductDetails;
  Completer<ProUnlockStatusEntity>? _pendingPurchaseCompleter;
  Completer<ProUnlockStatusEntity>? _pendingRestoreCompleter;
  bool _isDisposed = false;

  BillingRepositoryImpl({
    IInAppPurchaseClient? iapClient,
    IBillingLocalCacheSource? localCacheSource,
    this.restoreTimeout = const Duration(seconds: 8),
  })  : _iapClient = iapClient ?? const InAppPurchaseClientImpl(),
        _localCacheSource =
            localCacheSource ?? const BillingLocalCacheSourceImpl() {
    _ensureStreamSubscribed();
  }

  void _ensureStreamSubscribed() {
    if (_purchaseSubscription != null || _isDisposed) {
      return;
    }
    _purchaseSubscription = _iapClient.purchaseStream.listen(
      (purchases) {
        unawaited(_handlePurchaseUpdates(purchases));
      },
      onError: (Object error) {
        final message = error.toString();
        _failPendingPurchase(
          BillingFailureException('Billing stream error: $message'),
        );
      },
    );
  }

  @override
  Stream<ProUnlockStatusEntity> get purchaseStatusStream =>
      _statusController.stream;

  @override
  Future<ProProductDetailsEntity> getProDetails() async {
    _ensureStreamSubscribed();
    final available = await _iapClient.isAvailable();
    if (!available) {
      return ProProductDetailsEntity.fallback;
    }

    final response = await _iapClient.queryProductDetails(
      const <String>{ProUnlockStatusEntity.lifetimeProProductId},
    );

    if (response.error != null || response.productDetails.isEmpty) {
      return ProProductDetailsEntity.fallback;
    }

    ProductDetails? matched;
    for (final item in response.productDetails) {
      if (item.id == ProUnlockStatusEntity.lifetimeProProductId) {
        matched = item;
        break;
      }
    }
    final product = matched ?? response.productDetails.first;
    _cachedProductDetails = product;

    return ProProductDetailsEntity(
      id: product.id,
      title: product.title,
      description: product.description,
      price: product.price,
      rawPrice: product.rawPrice,
      currencyCode: product.currencyCode,
    );
  }

  @override
  Future<ProUnlockStatusEntity> purchaseLifetimePro() async {
    _ensureStreamSubscribed();

    final alreadyUnlocked = await _localCacheSource.getProUnlockStatus();
    if (alreadyUnlocked.isUnlocked) {
      return alreadyUnlocked;
    }

    final available = await _iapClient.isAvailable();
    if (!available) {
      throw const BillingFailureException(
        'Google Play Billing is unavailable. Check your connection and try again.',
      );
    }

    var productDetails = _cachedProductDetails;
    if (productDetails == null) {
      final response = await _iapClient.queryProductDetails(
        const <String>{ProUnlockStatusEntity.lifetimeProProductId},
      );
      if (response.error != null) {
        throw BillingFailureException(
          response.error!.message.isNotEmpty
              ? response.error!.message
              : 'Unable to load Lifetime Pro product details from Google Play.',
        );
      }
      for (final item in response.productDetails) {
        if (item.id == ProUnlockStatusEntity.lifetimeProProductId) {
          productDetails = item;
          break;
        }
      }
      if (productDetails == null) {
        if (response.productDetails.isNotEmpty) {
          productDetails = response.productDetails.first;
        } else {
          throw const BillingFailureException(
            'Lifetime Pro product details could not be loaded from store.',
          );
        }
      }
      _cachedProductDetails = productDetails;
    }

    final existingCompleter = _pendingPurchaseCompleter;
    if (existingCompleter != null && !existingCompleter.isCompleted) {
      return existingCompleter.future;
    }

    final completer = Completer<ProUnlockStatusEntity>();
    completer.future.ignore();
    _pendingPurchaseCompleter = completer;

    final purchaseParam = PurchaseParam(productDetails: productDetails);
    final launched = await _iapClient.buyNonConsumable(
      purchaseParam: purchaseParam,
    );

    if (!launched) {
      _pendingPurchaseCompleter = null;
      if (!completer.isCompleted) {
        throw const BillingFailureException(
          'Unable to launch the Google Play purchase sheet.',
        );
      }
    }

    return completer.future;
  }

  @override
  Future<ProUnlockStatusEntity> restorePurchases() async {
    _ensureStreamSubscribed();

    final available = await _iapClient.isAvailable();
    if (!available) {
      return _localCacheSource.getProUnlockStatus();
    }

    final existingCompleter = _pendingRestoreCompleter;
    if (existingCompleter != null && !existingCompleter.isCompleted) {
      return existingCompleter.future;
    }

    final completer = Completer<ProUnlockStatusEntity>();
    completer.future.ignore();
    _pendingRestoreCompleter = completer;

    await _iapClient.restorePurchases();

    try {
      return await completer.future.timeout(restoreTimeout);
    } on TimeoutException {
      _pendingRestoreCompleter = null;
      return _localCacheSource.getProUnlockStatus();
    }
  }

  @override
  Future<bool> isProPurchased() async {
    final status = await _localCacheSource.getProUnlockStatus();
    return status.isUnlocked;
  }

  @override
  Future<ProUnlockStatusEntity> getCachedProStatus() {
    return _localCacheSource.getProUnlockStatus();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    final relevantPurchases = purchaseDetailsList
        .where((p) => p.productID == ProUnlockStatusEntity.lifetimeProProductId)
        .toList(growable: false);

    if (relevantPurchases.isEmpty) {
      if (_pendingRestoreCompleter != null &&
          !_pendingRestoreCompleter!.isCompleted) {
        final current = await _localCacheSource.getProUnlockStatus();
        _completePendingRestore(current);
      }
      return;
    }

    // Prioritize active purchases and restorations before errors/cancellations
    final successfulPurchases = relevantPurchases.where(
      (p) =>
          p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored,
    );
    final otherPurchases = relevantPurchases.where(
      (p) =>
          p.status != PurchaseStatus.purchased &&
          p.status != PurchaseStatus.restored,
    );

    for (final purchase in [...successfulPurchases, ...otherPurchases]) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final isValid = _verifyPurchaseLocally(purchase);
          if (!isValid) {
            _failPendingPurchase(
              const BillingFailureException(
                'Purchase verification failed: invalid receipt token.',
              ),
              failRestore: false,
            );
            continue;
          }

          final parsedDate = int.tryParse(purchase.transactionDate ?? '');
          final purchaseDateMs =
              parsedDate ?? DateTime.now().millisecondsSinceEpoch;
          final rawPurchaseId = purchase.purchaseID?.trim();
          final orderId = (rawPurchaseId != null && rawPurchaseId.isNotEmpty)
              ? rawPurchaseId
              : purchase.verificationData.serverVerificationData.trim();

          final unlockedStatus = ProUnlockStatusEntity(
            isUnlocked: true,
            purchaseDateMs: purchaseDateMs,
            orderId: orderId,
          );

          // 1. Persist locally first to prevent unacknowledged entitlement loss
          await _localCacheSource.saveProUnlockStatus(unlockedStatus);

          // 2. Complete transaction with store only after persistence succeeds
          if (purchase.pendingCompletePurchase) {
            await _iapClient.completePurchase(purchase);
          }

          if (!_isDisposed && !_statusController.isClosed) {
            _statusController.add(unlockedStatus);
          }

          _completePendingPurchase(unlockedStatus);
          _completePendingRestore(unlockedStatus);

        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _iapClient.completePurchase(purchase);
          }
          _failPendingPurchase(
            const BillingFailureException(
              'Purchase was cancelled.',
              isCancelled: true,
            ),
            failRestore: false,
          );

        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _iapClient.completePurchase(purchase);
          }
          final errorMessage = purchase.error?.message.trim();
          _failPendingPurchase(
            BillingFailureException(
              (errorMessage != null && errorMessage.isNotEmpty)
                  ? errorMessage
                  : 'Google Play purchase failed.',
            ),
          );
      }
    }
  }

  bool _verifyPurchaseLocally(PurchaseDetails purchase) {
    if (purchase.productID != ProUnlockStatusEntity.lifetimeProProductId) {
      return false;
    }
    final serverToken = purchase.verificationData.serverVerificationData.trim();
    final localToken = purchase.verificationData.localVerificationData.trim();
    return serverToken.isNotEmpty || localToken.isNotEmpty;
  }

  void _completePendingPurchase(ProUnlockStatusEntity status) {
    final completer = _pendingPurchaseCompleter;
    _pendingPurchaseCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(status);
    }
  }

  void _completePendingRestore(ProUnlockStatusEntity status) {
    final completer = _pendingRestoreCompleter;
    _pendingRestoreCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(status);
    }
  }

  void _failPendingPurchase(
    BillingFailureException exception, {
    bool failRestore = true,
  }) {
    final completer = _pendingPurchaseCompleter;
    _pendingPurchaseCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(exception);
    }

    if (failRestore) {
      final restoreCompleter = _pendingRestoreCompleter;
      _pendingRestoreCompleter = null;
      if (restoreCompleter != null && !restoreCompleter.isCompleted) {
        restoreCompleter.completeError(exception);
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    await _statusController.close();
  }
}
