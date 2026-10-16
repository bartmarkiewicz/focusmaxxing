import 'package:flutter_test/flutter_test.dart';
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

    test('persists verified Pro unlock and restores identical status', () async {
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
      expect(prefs.getBool(BillingLocalCacheSourceImpl.proUnlockedPrefsKey), isTrue);
      expect(prefs.getBool(BillingLocalCacheSourceImpl.lifetimeProLegacyPrefsKey), isTrue);
    });

    test('restores unlocked state from legacy boolean key if encrypted receipt is absent', () async {
      await prefs.setBool(BillingLocalCacheSourceImpl.lifetimeProLegacyPrefsKey, true);

      final status = await cacheSource.getProUnlockStatus();
      expect(status.isUnlocked, isTrue);
    });

    test('safely falls back to locked when encrypted receipt signature is tampered even if plaintext boolean is true', () async {
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
      await prefs.setBool(BillingLocalCacheSourceImpl.proUnlockedPrefsKey, true);
      await prefs.setBool(BillingLocalCacheSourceImpl.lifetimeProLegacyPrefsKey, true);

      final status = await cacheSource.getProUnlockStatus();
      expect(status.isUnlocked, isFalse);
    });
  });
}
