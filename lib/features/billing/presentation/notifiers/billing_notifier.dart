import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/exceptions/billing_failure_exception.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/get_product_details_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/purchase_lifetime_pro_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/restore_purchases_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/watch_pro_entitlement_usecase.dart';

/// Billing lifecycle states tracking the one-time Lifetime Pro unlock flow.
enum BillingStatus {
  initial,
  loading,
  purchased,
  error,
}

/// State notifier managing Lifetime Pro store metadata, purchase execution,
/// and restoration via domain use cases.
class BillingNotifier extends ChangeNotifier {
  final GetProductDetailsUseCase getProductDetailsUseCase;
  final PurchaseLifetimeProUseCase purchaseLifetimeProUseCase;
  final RestorePurchasesUseCase restorePurchasesUseCase;
  final WatchProEntitlementUseCase watchProEntitlementUseCase;

  StreamSubscription<ProUnlockStatusEntity>? _purchaseStreamSubscription;

  BillingStatus _status = BillingStatus.initial;
  ProUnlockStatusEntity _unlockStatus = ProUnlockStatusEntity.locked;
  ProProductDetailsEntity _productDetails = ProProductDetailsEntity.fallback;
  String? _errorMessage;
  bool _isDisposed = false;

  BillingNotifier({
    required this.getProductDetailsUseCase,
    required this.purchaseLifetimeProUseCase,
    required this.restorePurchasesUseCase,
    required this.watchProEntitlementUseCase,
    bool autoInitialize = true,
  }) {
    _purchaseStreamSubscription = watchProEntitlementUseCase().listen(
      _handleEntitlementChanged,
      onError: (Object error) {
        if (_isDisposed) return;
        _errorMessage = error.toString();
        _status = BillingStatus.error;
        notifyListeners();
      },
    );

    if (autoInitialize) {
      unawaited(initialize());
    }
  }

  BillingStatus get status => _status;
  bool get isProUnlocked => _unlockStatus.isUnlocked;
  ProUnlockStatusEntity get unlockStatus => _unlockStatus;
  ProProductDetailsEntity get productDetails => _productDetails;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == BillingStatus.loading;

  /// Loads cached entitlement status and queries product details from the store.
  Future<void> initialize() async {
    try {
      final cached = await watchProEntitlementUseCase.getCachedStatus();
      _unlockStatus = cached;
      if (cached.isUnlocked) {
        _status = BillingStatus.purchased;
      }

      final details = await getProductDetailsUseCase();
      _productDetails = details;
    } on Exception catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  /// Initiates the one-time $9.99 Lifetime Pro purchase flow.
  Future<bool> buyLifetimePro() async {
    if (_unlockStatus.isUnlocked) {
      return true;
    }

    _status = BillingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedStatus = await purchaseLifetimeProUseCase();
      _handleEntitlementChanged(updatedStatus);
      watchProEntitlementUseCase.notifyEntitlementChanged(updatedStatus);
      return updatedStatus.isUnlocked;
    } on BillingFailureException catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.isCancelled ? null : e.message;
        _status = _unlockStatus.isUnlocked
            ? BillingStatus.purchased
            : (_errorMessage != null
                ? BillingStatus.error
                : BillingStatus.initial);
        notifyListeners();
      }
      return false;
    } on Exception catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _status = BillingStatus.error;
        notifyListeners();
      }
      return false;
    }
  }

  /// Queries Google Play Billing to restore any existing Lifetime Pro purchase.
  Future<bool> restorePurchases() async {
    _status = BillingStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedStatus = await restorePurchasesUseCase();
      if (_isDisposed) return updatedStatus.isUnlocked;
      if (updatedStatus.isUnlocked) {
        _handleEntitlementChanged(updatedStatus);
      } else {
        _unlockStatus = updatedStatus;
        _status = BillingStatus.initial;
        _errorMessage =
            'No previous Lifetime Pro purchase found for this Google account.';
        notifyListeners();
      }
      watchProEntitlementUseCase.notifyEntitlementChanged(updatedStatus);
      return updatedStatus.isUnlocked;
    } on BillingFailureException catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.message;
        _status = BillingStatus.error;
        notifyListeners();
      }
      return false;
    } on Exception catch (e) {
      if (!_isDisposed) {
        _errorMessage = e.toString();
        _status = BillingStatus.error;
        notifyListeners();
      }
      return false;
    }
  }

  void clearError() {
    if (_isDisposed) return;
    _errorMessage = null;
    if (_status == BillingStatus.error) {
      _status = _unlockStatus.isUnlocked
          ? BillingStatus.purchased
          : BillingStatus.initial;
    }
    notifyListeners();
  }

  void _handleEntitlementChanged(ProUnlockStatusEntity updatedStatus) {
    if (_isDisposed) return;
    final targetStatus =
        updatedStatus.isUnlocked ? BillingStatus.purchased : BillingStatus.initial;
    if (_unlockStatus == updatedStatus && _status == targetStatus) {
      return;
    }
    _unlockStatus = updatedStatus;
    _status = targetStatus;
    if (updatedStatus.isUnlocked) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_purchaseStreamSubscription?.cancel());
    _purchaseStreamSubscription = null;
    super.dispose();
  }
}
