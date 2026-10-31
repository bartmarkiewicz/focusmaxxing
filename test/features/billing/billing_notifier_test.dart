import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/theme/theme_notifier.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/get_product_details_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/purchase_lifetime_pro_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/restore_purchases_usecase.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:focusmaxxing/features/schedule/presentation/notifiers/schedule_notifier.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';

class _FakeBillingRepo implements IBillingRepository {
  final StreamController<ProUnlockStatusEntity> controller =
      StreamController<ProUnlockStatusEntity>.broadcast();

  ProUnlockStatusEntity currentStatus = ProUnlockStatusEntity.locked;
  ProProductDetailsEntity details = ProProductDetailsEntity.fallback;
  bool shouldCancel = false;
  String? failMessage;

  @override
  Stream<ProUnlockStatusEntity> get purchaseStatusStream => controller.stream;

  @override
  Future<ProProductDetailsEntity> getProDetails() async => details;

  @override
  Future<ProUnlockStatusEntity> purchaseLifetimePro() async {
    if (shouldCancel) {
      throw const BillingFailureException('Cancelled', isCancelled: true);
    }
    if (failMessage != null) {
      throw BillingFailureException(failMessage!);
    }
    currentStatus = const ProUnlockStatusEntity(
      isUnlocked: true,
      orderId: 'GPA.BUY-1234',
      purchaseDateMs: 1729000000000,
    );
    controller.add(currentStatus);
    return currentStatus;
  }

  @override
  Future<ProUnlockStatusEntity> restorePurchases() async {
    if (failMessage != null) {
      throw BillingFailureException(failMessage!);
    }
    currentStatus = const ProUnlockStatusEntity(
      isUnlocked: true,
      orderId: 'GPA.RESTORE-5678',
      purchaseDateMs: 1729000000000,
    );
    controller.add(currentStatus);
    return currentStatus;
  }

  @override
  Future<bool> isProPurchased() async => currentStatus.isUnlocked;

  @override
  Future<ProUnlockStatusEntity> getCachedProStatus() async => currentStatus;

  @override
  Future<void> dispose() async => controller.close();
}

class _StubShieldNotifier extends Fake implements ShieldNotifier {
  bool unlockedLifetimeCalled = false;

  @override
  Future<void> unlockLifetimePro({bool activatePendingCandidate = true}) async {
    unlockedLifetimeCalled = true;
  }
}

class _StubAudioNotifier extends Fake implements AudioNotifier {
  bool? proUnlockedValue;

  @override
  void setProUnlocked(bool unlocked) {
    proUnlockedValue = unlocked;
  }
}

class _StubScheduleNotifier extends Fake implements ScheduleNotifier {
  bool unlockedLifetimeCalled = false;

  @override
  Future<void> unlockLifetimePro() async {
    unlockedLifetimeCalled = true;
  }
}

class _StubThemeNotifier extends Fake implements ThemeNotifier {
  bool? validatedProAccessArg;

  @override
  Future<void> validateProAccess({required bool isLifetimePro}) async {
    validatedProAccessArg = isLifetimePro;
  }
}

void main() {
  group('BillingNotifier', () {
    late _FakeBillingRepo repo;
    late GetProductDetailsUseCase getProductDetailsUseCase;
    late PurchaseLifetimeProUseCase purchaseLifetimeProUseCase;
    late RestorePurchasesUseCase restorePurchasesUseCase;
    late _StubShieldNotifier shieldNotifier;
    late _StubAudioNotifier audioNotifier;
    late _StubScheduleNotifier scheduleNotifier;
    late _StubThemeNotifier themeNotifier;

    setUp(() {
      repo = _FakeBillingRepo();
      getProductDetailsUseCase = GetProductDetailsUseCase(repo);
      purchaseLifetimeProUseCase = PurchaseLifetimeProUseCase(repo);
      restorePurchasesUseCase = RestorePurchasesUseCase(repo);
      shieldNotifier = _StubShieldNotifier();
      audioNotifier = _StubAudioNotifier();
      scheduleNotifier = _StubScheduleNotifier();
      themeNotifier = _StubThemeNotifier();
    });

    tearDown(() async {
      await repo.dispose();
    });

    BillingNotifier createNotifier({bool autoInitialize = false}) {
      return BillingNotifier(
        getProductDetailsUseCase: getProductDetailsUseCase,
        purchaseLifetimeProUseCase: purchaseLifetimeProUseCase,
        restorePurchasesUseCase: restorePurchasesUseCase,
        repository: repo,
        shieldNotifier: shieldNotifier,
        audioNotifier: audioNotifier,
        scheduleNotifier: scheduleNotifier,
        themeNotifier: themeNotifier,
        autoInitialize: autoInitialize,
      );
    }

    test('initial status reflects cached Pro purchase state when locked',
        () async {
      final notifier = createNotifier();
      await notifier.initialize();

      expect(notifier.status, BillingStatus.initial);
      expect(notifier.isProUnlocked, isFalse);
      expect(notifier.productDetails.price, r'$9.99');
      expect(shieldNotifier.unlockedLifetimeCalled, isFalse);
      expect(scheduleNotifier.unlockedLifetimeCalled, isFalse);
    });

    test(
        'initial status reflects cached Pro purchase state when already unlocked',
        () async {
      repo.currentStatus = const ProUnlockStatusEntity(
        isUnlocked: true,
        orderId: 'PREVIOUS_ORDER',
      );

      final notifier = createNotifier();
      await notifier.initialize();

      expect(notifier.status, BillingStatus.purchased);
      expect(notifier.isProUnlocked, isTrue);
      expect(shieldNotifier.unlockedLifetimeCalled, isTrue);
      expect(audioNotifier.proUnlockedValue, isTrue);
      expect(scheduleNotifier.unlockedLifetimeCalled, isTrue);
    });

    test(
        'purchase success dispatches isProUnlocked = true and unlocks dependent notifiers',
        () async {
      final notifier = createNotifier();
      await notifier.initialize();

      final success = await notifier.buyLifetimePro();

      expect(success, isTrue);
      expect(notifier.status, BillingStatus.purchased);
      expect(notifier.isProUnlocked, isTrue);
      expect(notifier.unlockStatus.orderId, 'GPA.BUY-1234');
      expect(shieldNotifier.unlockedLifetimeCalled, isTrue);
      expect(audioNotifier.proUnlockedValue, isTrue);
      expect(scheduleNotifier.unlockedLifetimeCalled, isTrue);
    });

    test('purchase cancellation resets state without error banner', () async {
      repo.shouldCancel = true;
      final notifier = createNotifier();
      await notifier.initialize();

      final success = await notifier.buyLifetimePro();

      expect(success, isFalse);
      expect(notifier.status, BillingStatus.initial);
      expect(notifier.errorMessage, isNull);
      expect(notifier.isProUnlocked, isFalse);
    });

    test('purchase failure sets BillingStatus.error and records errorMessage',
        () async {
      repo.failMessage = 'Payment declined by card issuer.';
      final notifier = createNotifier();
      await notifier.initialize();

      final success = await notifier.buyLifetimePro();

      expect(success, isFalse);
      expect(notifier.status, BillingStatus.error);
      expect(notifier.errorMessage, 'Payment declined by card issuer.');
      expect(notifier.isProUnlocked, isFalse);

      notifier.clearError();
      expect(notifier.status, BillingStatus.initial);
      expect(notifier.errorMessage, isNull);
    });

    test(
        'restore purchases fetches valid past purchase and updates local state',
        () async {
      final notifier = createNotifier();
      await notifier.initialize();

      final success = await notifier.restorePurchases();

      expect(success, isTrue);
      expect(notifier.status, BillingStatus.purchased);
      expect(notifier.isProUnlocked, isTrue);
      expect(notifier.unlockStatus.orderId, 'GPA.RESTORE-5678');
      expect(scheduleNotifier.unlockedLifetimeCalled, isTrue);
      expect(shieldNotifier.unlockedLifetimeCalled, isTrue);
      expect(audioNotifier.proUnlockedValue, isTrue);
    });

    test('attachThemeNotifier validates Pro access when non-pro', () async {
      final customThemeNotifier = _StubThemeNotifier();
      final notifier = createNotifier();
      await notifier.initialize();

      notifier.attachThemeNotifier(customThemeNotifier);

      expect(customThemeNotifier.validatedProAccessArg, isFalse);
    });

    test(
        'attachThemeNotifier before initialize does not validate Pro access prematurely',
        () async {
      final customThemeNotifier = _StubThemeNotifier();
      final notifier = createNotifier();

      notifier.attachThemeNotifier(customThemeNotifier);

      expect(customThemeNotifier.validatedProAccessArg, isNull);
    });

    test(
        'attaching identical notifiers repeatedly does not trigger duplicate unlock calls',
        () async {
      repo.currentStatus = const ProUnlockStatusEntity(
        isUnlocked: true,
        orderId: 'GPA.TEST',
      );
      final notifier = createNotifier();
      await notifier.initialize();

      shieldNotifier.unlockedLifetimeCalled = false;
      notifier.attachShieldNotifier(shieldNotifier);
      expect(shieldNotifier.unlockedLifetimeCalled, isFalse);

      audioNotifier.proUnlockedValue = null;
      notifier.attachAudioNotifier(audioNotifier);
      expect(audioNotifier.proUnlockedValue, isNull);

      scheduleNotifier.unlockedLifetimeCalled = false;
      notifier.attachScheduleNotifier(scheduleNotifier);
      expect(scheduleNotifier.unlockedLifetimeCalled, isFalse);
    });
  });
}
