import 'dart:developer' as developer;

import 'package:focusmaxxing/core/security/pro_receipt_verifier.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract for persisting and retrieving the user's Lifetime Pro entitlement
/// in local offline storage.
abstract class IBillingLocalCacheSource {
  /// Reads the cached [ProUnlockStatusEntity] from local storage.
  Future<ProUnlockStatusEntity> getProUnlockStatus();

  /// Persists the verified [ProUnlockStatusEntity] to local storage.
  Future<void> saveProUnlockStatus(ProUnlockStatusEntity status);
}

/// [SharedPreferences]-backed implementation of [IBillingLocalCacheSource]
/// that delegates cryptographic receipt signing and verification to
/// [ProReceiptVerifier].
class BillingLocalCacheSourceImpl implements IBillingLocalCacheSource {
  /// Primary boolean key specified by Milestone 3 Phase 3.2.
  static const String proUnlockedPrefsKey =
      ProReceiptVerifier.proUnlockedPrefsKey;

  /// Legacy/cross-feature boolean key observed by `ShieldNotifier` and `AudioNotifier`.
  static const String lifetimeProLegacyPrefsKey =
      ProReceiptVerifier.lifetimeProLegacyPrefsKey;

  /// Key storing the encrypted/signed receipt payload.
  static const String encryptedReceiptPrefsKey =
      ProReceiptVerifier.encryptedReceiptPrefsKey;

  /// Key storing purchase timestamp in epoch milliseconds.
  static const String purchaseDateMsPrefsKey =
      ProReceiptVerifier.purchaseDateMsPrefsKey;

  /// Key storing the Google Play order ID.
  static const String orderIdPrefsKey = ProReceiptVerifier.orderIdPrefsKey;

  final SharedPreferences? sharedPreferences;

  const BillingLocalCacheSourceImpl({
    this.sharedPreferences,
  });

  Future<SharedPreferences> _resolvePrefs() async {
    return sharedPreferences ?? await SharedPreferences.getInstance();
  }

  /// Synchronously verifies whether [prefs] holds a valid cryptographic Pro receipt.
  static bool isProUnlockedInPrefs(SharedPreferences prefs) {
    return ProReceiptVerifier.isProUnlockedInPrefs(prefs);
  }

  /// Synchronously encodes and signs [status] into a base64url receipt payload.
  static String encodeSignedReceipt(ProUnlockStatusEntity status) {
    return ProReceiptVerifier.encodeSignedReceipt(
      isUnlocked: status.isUnlocked,
      purchaseDateMs: status.purchaseDateMs,
      orderId: status.orderId,
    );
  }

  @override
  Future<ProUnlockStatusEntity> getProUnlockStatus() async {
    try {
      final prefs = await _resolvePrefs();
      final verified = ProReceiptVerifier.readVerifiedReceiptSync(prefs);
      if (!verified.isUnlocked) {
        return ProUnlockStatusEntity.locked;
      }
      return ProUnlockStatusEntity(
        isUnlocked: true,
        purchaseDateMs: verified.purchaseDateMs,
        orderId: verified.orderId,
      );
    } on Exception catch (e) {
      developer.log(
        'Failed to read Pro unlock status from local cache',
        error: e,
        name: 'BillingLocalCacheSource',
      );
      return ProUnlockStatusEntity.locked;
    }
  }

  @override
  Future<void> saveProUnlockStatus(ProUnlockStatusEntity status) async {
    try {
      final prefs = await _resolvePrefs();
      await ProReceiptVerifier.persistVerifiedReceipt(
        prefs,
        VerifiedProReceipt(
          isUnlocked: status.isUnlocked,
          purchaseDateMs: status.purchaseDateMs,
          orderId: status.orderId,
        ),
      );
    } on Exception catch (e) {
      developer.log(
        'Failed to persist Pro unlock status to local cache',
        error: e,
        name: 'BillingLocalCacheSource',
      );
    }
  }
}
