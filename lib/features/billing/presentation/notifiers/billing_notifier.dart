import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:focusmaxxing/core/theme/theme_notifier.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/get_product_details_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/purchase_lifetime_pro_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/restore_purchases_usecase.dart';
import 'package:focusmaxxing/features/schedule/presentation/notifiers/schedule_notifier.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';

/// Billing lifecycle states tracking the one-time Lifetime Pro unlock flow.
enum BillingStatus {
  initial,
  loading,
  purchased,
  error,
}

/// State notifier managing Lifetime Pro store metadata, purchase execution,
/// restoration, and cross-notifier entitlement synchronization.
class BillingNotifier extends ChangeNotifier {
  final GetProductDetailsUseCase getProductDetailsUseCase;
  final PurchaseLifetimeProUseCase purchaseLifetimeProUseCase;
  final RestorePurchasesUseCase restorePurchasesUseCase;
  final IBillingRepository repository;

  ShieldNotifier? shieldNotifier;
  AudioNotifier? audioNotifier;
  ScheduleNotifier? scheduleNotifier;
  ThemeNotifier? themeNotifier;
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
    required this.repository,
    this.shieldNotifier,
    this.audioNotifier,
    this.scheduleNotifier,
    this.themeNotifier,
    bool autoInitialize = true,
  }) {
    _purchaseStreamSubscription = repository.purchaseStatusStream.listen(
      _handleEntitlementChanged,
      onError: (Object error) {
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

  void attachShieldNotifier(ShieldNotifier? notifier) {
    shieldNotifier = notifier;
    if (_unlockStatus.isUnlocked) {
      unawaited(shieldNotifier?.unlockLifetimePro());
    }
  }

  void attachAudioNotifier(AudioNotifier? notifier) {
    audioNotifier = notifier;
    if (_unlockStatus.isUnlocked) {
      audioNotifier?.setProUnlocked(true);
    }
  }

  void attachScheduleNotifier(ScheduleNotifier? notifier) {
    scheduleNotifier = notifier;
    if (_unlockStatus.isUnlocked) {
      unawaited(scheduleNotifier?.unlockLifetimePro());
    }
  }

  bool _isInitialized = false;

  void attachThemeNotifier(ThemeNotifier? notifier) {
    themeNotifier = notifier;
    if (_isInitialized && !_unlockStatus.isUnlocked) {
      unawaited(themeNotifier?.validateProAccess(isLifetimePro: false));
    }
  }

  /// Loads cached entitlement status and queries product details from the store.
  Future<void> initialize() async {
    try {
      final cached = await repository.getCachedProStatus();
      _unlockStatus = cached;
      _isInitialized = true;
      if (cached.isUnlocked) {
        _status = BillingStatus.purchased;
        _propagateProEntitlement();
      } else {
        unawaited(themeNotifier?.validateProAccess(isLifetimePro: false));
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
      _handleEntitlementChanged(updatedStatus);
      if (!_isDisposed && !updatedStatus.isUnlocked) {
        _status = BillingStatus.initial;
        _errorMessage =
            'No previous Lifetime Pro purchase found for this Google account.';
        notifyListeners();
      }
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
    _unlockStatus = updatedStatus;
    if (updatedStatus.isUnlocked) {
      _status = BillingStatus.purchased;
      _errorMessage = null;
      _propagateProEntitlement();
    } else {
      _status = BillingStatus.initial;
      unawaited(themeNotifier?.validateProAccess(isLifetimePro: false));
    }
    notifyListeners();
  }

  void _propagateProEntitlement() {
    unawaited(shieldNotifier?.unlockLifetimePro());
    audioNotifier?.setProUnlocked(true);
    unawaited(scheduleNotifier?.unlockLifetimePro());
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_purchaseStreamSubscription?.cancel());
    _purchaseStreamSubscription = null;
    super.dispose();
  }
}
