import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';

export 'package:focusmaxxing/features/billing/domain/exceptions/billing_failure_exception.dart';

/// Contract for querying product pricing, purchasing Lifetime Pro, and
/// restoring non-consumable entitlements.
abstract class IBillingRepository {
  /// Emits updates whenever the native billing stream processes a purchase,
  /// restoration, or cancellation event.
  Stream<ProUnlockStatusEntity> get purchaseStatusStream;

  /// Fetches store product metadata for `focusmaxxing_lifetime_pro`, falling
  /// back to [ProProductDetailsEntity.fallback] if the store is unreachable.
  Future<ProProductDetailsEntity> getProDetails();

  /// Initiates the non-consumable purchase flow for Lifetime Pro (`$9.99`)
  /// and resolves with the updated [ProUnlockStatusEntity].
  Future<ProUnlockStatusEntity> purchaseLifetimePro();

  /// Restores any previously purchased Lifetime Pro entitlement (including
  /// Google Play Family Library shares) and updates local encrypted cache.
  Future<ProUnlockStatusEntity> restorePurchases();

  /// Returns `true` if Lifetime Pro is currently unlocked in local cache.
  Future<bool> isProPurchased();

  /// Returns the full cached [ProUnlockStatusEntity] from local storage.
  Future<ProUnlockStatusEntity> getCachedProStatus();

  /// Cancels active purchase stream subscriptions and releases resources.
  Future<void> dispose();
}
