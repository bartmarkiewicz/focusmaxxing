import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/security/pro_receipt_verifier.dart';
import 'package:focusmaxxing/features/billing/data/datasources/billing_local_cache_source.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BillingLocalCacheSourceImpl', () {
    late SharedPreferences prefs;
    late BillingLocalCacheSourceImpl cacheSource;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      cacheSource = BillingLocalCacheSourceImpl(sharedPreferences: prefs);
    });

    test('returns locked state when cache is clean', () async {
      final status = await cacheSource.getProUnlockStatus();

      expect(status.isUnlocked, isFalse);
      expect(status.orderId, isNull);
      expect(status.purchaseDateMs, isNull);
    });

    test('persists verified Pro unlock and restores identical status',
        () async {
      const original = ProUnlockStatusEntity(
        isUnlocked: true,
        purchaseDateMs: 1729000000000,
        orderId: 'GPA.9999-1111-2222',
      );

      await cacheSource.saveProUnlockStatus(original);
      final restored = await cacheSource.getProUnlockStatus();

      expect(restored.isUnlocked, isTrue);
      expect(restored.purchaseDateMs, 1729000000000);
      expect(restored.orderId, 'GPA.9999-1111-2222');

      // Verifies synchronization of cross-feature flags
      expect(prefs.getBool(BillingLocalCacheSourceImpl.proUnlockedPrefsKey),
          isTrue);
      expect(
          prefs.getBool(BillingLocalCacheSourceImpl.lifetimeProLegacyPrefsKey),
          isTrue);
    });

    test(
        'evaluates to locked when encrypted receipt is absent even if legacy boolean keys are true',
        () async {
      await prefs.setBool(
          BillingLocalCacheSourceImpl.lifetimeProLegacyPrefsKey, true);
      await prefs.setBool(
          BillingLocalCacheSourceImpl.proUnlockedPrefsKey, true);

      final status = await cacheSource.getProUnlockStatus();
      expect(status.isUnlocked, isFalse);
      expect(status, equals(ProUnlockStatusEntity.locked));
    });

    test(
        'safely falls back to locked when encrypted receipt signature is tampered even if plaintext boolean is true',
        () async {
      const original = ProUnlockStatusEntity(
        isUnlocked: true,
        purchaseDateMs: 1729000000000,
        orderId: 'GPA.9999-1111-2222',
      );
      await cacheSource.saveProUnlockStatus(original);

      // Tamper with the encrypted string in SharedPreferences while leaving booleans true
      await prefs.setString(
        BillingLocalCacheSourceImpl.encryptedReceiptPrefsKey,
        'INVALID_CORRUPTED_BASE64_CIPHER',
      );
      await prefs.setBool(
          BillingLocalCacheSourceImpl.proUnlockedPrefsKey, true);
      await prefs.setBool(
          BillingLocalCacheSourceImpl.lifetimeProLegacyPrefsKey, true);

      final status = await cacheSource.getProUnlockStatus();
      expect(status.isUnlocked, isFalse);
    });

    test(
        'ProReceiptVerifier verifies authentic HMAC-SHA256 signed receipt and rejects modified cipher',
        () {
      final encoded = ProReceiptVerifier.encodeSignedReceipt(
        isUnlocked: true,
        purchaseDateMs: 1729000000000,
        orderId: 'GPA.HMAC-TEST-9999',
      );
      final decoded = ProReceiptVerifier.decodeAndVerifyReceipt(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.isUnlocked, isTrue);
      expect(decoded.orderId, equals('GPA.HMAC-TEST-9999'));

      final flipped = encoded.substring(0, encoded.length - 2) +
          (encoded.endsWith('A') ? 'B' : 'A');
      expect(ProReceiptVerifier.decodeAndVerifyReceipt(flipped), isNull);
    });

    test(
        'ProReceiptVerifier rejects downgraded envelope missing HMAC-SHA256 signature field',
        () {
      final encoded = ProReceiptVerifier.encodeSignedReceipt(
        isUnlocked: true,
        purchaseDateMs: 1729000000000,
        orderId: 'GPA.DOWNGRADE-TEST',
      );
      // Strip the "h" field from the JSON inside the base64 envelope by crafting a payload with only 'p' and 's'
      final validDecoded = ProReceiptVerifier.decodeAndVerifyReceipt(encoded);
      expect(validDecoded, isNotNull);

      // An envelope without 'h' must be rejected even if 'p' and 's' are present
      const downgradedEnvelope =
          'eyJwIjoiIiwicyI6MTIzNDU2Nzh9'; // {"p":"","s":12345678}
      expect(
        ProReceiptVerifier.decodeAndVerifyReceipt(downgradedEnvelope),
        isNull,
      );
    });

    test(
        'ensureUnlockedInPrefs preserves existing purchaseDateMs and orderId metadata',
        () async {
      const original = ProUnlockStatusEntity(
        isUnlocked: true,
        purchaseDateMs: 1729000000000,
        orderId: 'GPA.PRESERVE-META-1234',
      );
      await cacheSource.saveProUnlockStatus(original);

      await ProReceiptVerifier.ensureUnlockedInPrefs(prefs);

      final restored = await cacheSource.getProUnlockStatus();
      expect(restored.isUnlocked, isTrue);
      expect(restored.purchaseDateMs, equals(1729000000000));
      expect(restored.orderId, equals('GPA.PRESERVE-META-1234'));
    });
  });
}
