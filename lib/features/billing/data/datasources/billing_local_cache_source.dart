import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

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
/// that stores an obfuscated/integrity-signed receipt record alongside the
/// cross-feature `is_pro_unlocked` and `is_lifetime_pro` flags.
class BillingLocalCacheSourceImpl implements IBillingLocalCacheSource {
  /// Primary boolean key specified by Milestone 3 Phase 3.2.
  static const String proUnlockedPrefsKey = 'is_pro_unlocked';

  /// Legacy/cross-feature boolean key observed by `ShieldNotifier` and `AudioNotifier`.
  static const String lifetimeProLegacyPrefsKey = 'is_lifetime_pro';

  /// Key storing the encrypted/signed receipt payload.
  static const String encryptedReceiptPrefsKey = 'billing_encrypted_receipt_v1';

  /// Key storing purchase timestamp in epoch milliseconds.
  static const String purchaseDateMsPrefsKey = 'billing_purchase_date_ms';

  /// Key storing the Google Play order ID.
  static const String orderIdPrefsKey = 'billing_order_id';

  static const List<int> _cipherKeyBytes = <int>[
    0x46, 0x4F, 0x43, 0x55, 0x53, 0x4D, 0x41, 0x58, // FOCUSMAX
    0x58, 0x49, 0x4E, 0x47, 0x5F, 0x50, 0x52, 0x4F, // XING_PRO
    0x5F, 0x39, 0x39, 0x39, 0x5F, 0x4B, 0x45, 0x59, // _999_KEY
  ];

  final SharedPreferences? sharedPreferences;

  const BillingLocalCacheSourceImpl({
    this.sharedPreferences,
  });

  Future<SharedPreferences> _resolvePrefs() async {
    return sharedPreferences ?? await SharedPreferences.getInstance();
  }

  @override
  Future<ProUnlockStatusEntity> getProUnlockStatus() async {
    try {
      final prefs = await _resolvePrefs();

      final encryptedPayload = prefs.getString(encryptedReceiptPrefsKey);
      if (encryptedPayload != null && encryptedPayload.isNotEmpty) {
        final decodedStatus = _decodeAndVerifyReceipt(encryptedPayload);
        if (decodedStatus != null) {
          return decodedStatus;
        }
        // Tampered or corrupted receipt: do not fall back to plaintext booleans.
        return ProUnlockStatusEntity.locked;
      }

      // Legacy migration fallback: only when no encrypted receipt exists yet.
      final isUnlockedFlag =
          (prefs.getBool(proUnlockedPrefsKey) ?? false) ||
          (prefs.getBool(lifetimeProLegacyPrefsKey) ?? false);

      if (isUnlockedFlag) {
        return ProUnlockStatusEntity(
          isUnlocked: true,
          purchaseDateMs: prefs.getInt(purchaseDateMsPrefsKey),
          orderId: prefs.getString(orderIdPrefsKey),
        );
      }
    } on Exception catch (e) {
      developer.log(
        'Failed to read Pro unlock status from local cache',
        error: e,
        name: 'BillingLocalCacheSource',
      );
      return ProUnlockStatusEntity.locked;
    }

    return ProUnlockStatusEntity.locked;
  }

  @override
  Future<void> saveProUnlockStatus(ProUnlockStatusEntity status) async {
    try {
      final prefs = await _resolvePrefs();
      final encodedReceipt = _encodeAndSignReceipt(status);

      await prefs.setString(encryptedReceiptPrefsKey, encodedReceipt);
      await prefs.setBool(proUnlockedPrefsKey, status.isUnlocked);
      await prefs.setBool(lifetimeProLegacyPrefsKey, status.isUnlocked);

      final purchaseDateMs = status.purchaseDateMs;
      if (purchaseDateMs != null) {
        await prefs.setInt(purchaseDateMsPrefsKey, purchaseDateMs);
      } else if (!status.isUnlocked) {
        await prefs.remove(purchaseDateMsPrefsKey);
      }

      final orderId = status.orderId;
      if (orderId != null) {
        await prefs.setString(orderIdPrefsKey, orderId);
      } else if (!status.isUnlocked) {
        await prefs.remove(orderIdPrefsKey);
      }
    } on Exception catch (e) {
      developer.log(
        'Failed to persist Pro unlock status to local cache',
        error: e,
        name: 'BillingLocalCacheSource',
      );
    }
  }

  String _encodeAndSignReceipt(ProUnlockStatusEntity status) {
    final payloadMap = <String, Object?>{
      'u': status.isUnlocked,
      'd': status.purchaseDateMs,
      'o': status.orderId,
      'p': ProUnlockStatusEntity.lifetimeProProductId,
    };
    final jsonString = jsonEncode(payloadMap);
    final signature = _computeFnv1aHash(jsonString);
    final envelope = jsonEncode(<String, Object?>{
      'p': jsonString,
      's': signature,
    });
    final plainBytes = utf8.encode(envelope);
    final cipherBytes = _xorTransform(plainBytes);
    return base64UrlEncode(cipherBytes);
  }

  ProUnlockStatusEntity? _decodeAndVerifyReceipt(String encoded) {
    try {
      final cipherBytes = base64Url.decode(encoded);
      final plainBytes = _xorTransform(cipherBytes);
      final envelopeString = utf8.decode(plainBytes);
      final dynamic decodedEnvelope = jsonDecode(envelopeString);
      if (decodedEnvelope is! Map<String, dynamic>) {
        return null;
      }

      final payloadString = decodedEnvelope['p'];
      final signature = decodedEnvelope['s'];
      if (payloadString is! String || signature is! int) {
        return null;
      }

      if (_computeFnv1aHash(payloadString) != signature) {
        return null;
      }

      final dynamic payload = jsonDecode(payloadString);
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final isUnlocked = payload['u'];
      final purchaseDateMs = payload['d'];
      final orderId = payload['o'];

      if (isUnlocked is! bool) {
        return null;
      }

      return ProUnlockStatusEntity(
        isUnlocked: isUnlocked,
        purchaseDateMs: purchaseDateMs is int ? purchaseDateMs : null,
        orderId: orderId is String ? orderId : null,
      );
    } on Exception {
      return null;
    }
  }

  Uint8List _xorTransform(List<int> input) {
    final output = Uint8List(input.length);
    for (var i = 0; i < input.length; i++) {
      output[i] = input[i] ^ _cipherKeyBytes[i % _cipherKeyBytes.length];
    }
    return output;
  }

  int _computeFnv1aHash(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
