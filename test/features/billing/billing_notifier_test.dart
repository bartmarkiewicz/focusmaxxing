import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/theme/pro_accent_variant.dart';
import 'package:focusmaxxing/core/theme/theme_notifier.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/play_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/set_audio_volume_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/stop_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/get_product_details_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/purchase_lifetime_pro_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/restore_purchases_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/watch_pro_entitlement_usecase.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/save_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/toggle_auto_shield_usecase.dart';
import 'package:focusmaxxing/features/schedule/presentation/notifiers/schedule_notifier.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/bring_app_to_foreground_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/check_shield_permissions_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_installed_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_shielded_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/request_permission_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/start_shield_service_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/stop_shield_service_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/swap_shield_app_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/sync_shield_with_overlay_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/toggle_shield_app_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/watch_overlay_events_usecase.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _StubShieldRepo extends Fake implements IShieldRepository {
  @override
  Stream<dynamic> get overlayEvents => const Stream.empty();
}

class _StubAudioRepo extends Fake implements IAudioRepository {}

class _StubScheduleRepo extends Fake implements IScheduleRepository {
  @override
  Future<Either<Failure, ScheduleConfigEntity>> getSchedule() async =>
      const Right(ScheduleConfigEntity.initial);
}

void main() {
  group('BillingNotifier & WatchProEntitlementUseCase', () {
    late _FakeBillingRepo repo;
    late GetProductDetailsUseCase getProductDetailsUseCase;
    late PurchaseLifetimeProUseCase purchaseLifetimeProUseCase;
    late RestorePurchasesUseCase restorePurchasesUseCase;
    late WatchProEntitlementUseCase watchProEntitlementUseCase;
    late ShieldNotifier shieldNotifier;
    late AudioNotifier audioNotifier;
    late ScheduleNotifier scheduleNotifier;
    late ThemeNotifier themeNotifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      repo = _FakeBillingRepo();
      getProductDetailsUseCase = GetProductDetailsUseCase(repo);
      purchaseLifetimeProUseCase = PurchaseLifetimeProUseCase(repo);
      restorePurchasesUseCase = RestorePurchasesUseCase(repo);
      watchProEntitlementUseCase = WatchProEntitlementUseCase(repo);

      final shieldRepo = _StubShieldRepo();
      shieldNotifier = ShieldNotifier(
        getShieldedAppsUseCase: GetShieldedAppsUseCase(shieldRepo),
        getInstalledAppsUseCase: GetInstalledAppsUseCase(shieldRepo),
        toggleShieldAppUseCase: ToggleShieldAppUseCase(shieldRepo),
        swapShieldAppUseCase: SwapShieldAppUseCase(shieldRepo),
        checkShieldPermissionsUseCase:
            CheckShieldPermissionsUseCase(shieldRepo),
        requestPermissionUseCase: RequestPermissionUseCase(shieldRepo),
        startShieldServiceUseCase: StartShieldServiceUseCase(shieldRepo),
        stopShieldServiceUseCase: StopShieldServiceUseCase(shieldRepo),
        syncShieldWithOverlayUseCase: SyncShieldWithOverlayUseCase(shieldRepo),
        bringAppToForegroundUseCase: BringAppToForegroundUseCase(shieldRepo),
        watchOverlayEventsUseCase: WatchOverlayEventsUseCase(shieldRepo),
        watchProEntitlementUseCase: watchProEntitlementUseCase,
        sharedPreferences: prefs,
        autoInitialize: false,
      );

      final audioRepo = _StubAudioRepo();
      audioNotifier = AudioNotifier(
        playSoundscapeUseCase: PlaySoundscapeUseCase(audioRepo),
        stopSoundscapeUseCase: StopSoundscapeUseCase(audioRepo),
        setAudioVolumeUseCase: SetAudioVolumeUseCase(audioRepo),
        watchProEntitlementUseCase: watchProEntitlementUseCase,
        sharedPreferences: prefs,
      );

      final scheduleRepo = _StubScheduleRepo();
      scheduleNotifier = ScheduleNotifier(
        getScheduleUseCase: GetScheduleUseCase(scheduleRepo),
        saveScheduleUseCase: SaveScheduleUseCase(scheduleRepo),
        toggleAutoShieldUseCase: ToggleAutoShieldUseCase(scheduleRepo),
        watchProEntitlementUseCase: watchProEntitlementUseCase,
        sharedPreferences: prefs,
        autoInitialize: false,
      );

      themeNotifier = ThemeNotifier(
        sharedPreferences: prefs,
        watchProEntitlementUseCase: watchProEntitlementUseCase,
      );
    });

    tearDown(() async {
      shieldNotifier.dispose();
      audioNotifier.dispose();
      scheduleNotifier.dispose();
      themeNotifier.dispose();
      await repo.dispose();
    });

    BillingNotifier createNotifier({bool autoInitialize = false}) {
      return BillingNotifier(
        getProductDetailsUseCase: getProductDetailsUseCase,
        purchaseLifetimeProUseCase: purchaseLifetimeProUseCase,
        restorePurchasesUseCase: restorePurchasesUseCase,
        watchProEntitlementUseCase: watchProEntitlementUseCase,
        autoInitialize: autoInitialize,
      );
    }

    test('initial status reflects cached Pro purchase state when locked',
        () async {
      final notifier = createNotifier();
      addTearDown(notifier.dispose);
      await notifier.initialize();

      expect(notifier.status, BillingStatus.initial);
      expect(notifier.isProUnlocked, isFalse);
      expect(notifier.productDetails.price, r'$9.99');
      expect(shieldNotifier.isPro, isFalse);
      expect(scheduleNotifier.isPro, isFalse);
    });

    test(
        'initial status reflects cached Pro purchase state when already unlocked and broadcasts via WatchProEntitlementUseCase',
        () async {
      repo.currentStatus = const ProUnlockStatusEntity(
        isUnlocked: true,
        orderId: 'PREVIOUS_ORDER',
      );

      final notifier = createNotifier();
      addTearDown(notifier.dispose);
      await notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.status, BillingStatus.purchased);
      expect(notifier.isProUnlocked, isTrue);
      expect(shieldNotifier.isPro, isTrue);
      expect(audioNotifier.isProUnlocked, isTrue);
      expect(scheduleNotifier.isPro, isTrue);
    });

    test(
        'purchase success dispatches isProUnlocked = true and unlocks dependent notifiers via stream',
        () async {
      final notifier = createNotifier();
      addTearDown(notifier.dispose);
      await notifier.initialize();

      final success = await notifier.buyLifetimePro();
      await Future<void>.delayed(Duration.zero);

      expect(success, isTrue);
      expect(notifier.status, BillingStatus.purchased);
      expect(notifier.isProUnlocked, isTrue);
      expect(notifier.unlockStatus.orderId, 'GPA.BUY-1234');
      expect(shieldNotifier.isPro, isTrue);
      expect(audioNotifier.isProUnlocked, isTrue);
      expect(scheduleNotifier.isPro, isTrue);
    });

    test('purchase cancellation resets state without error banner', () async {
      repo.shouldCancel = true;
      final notifier = createNotifier();
      addTearDown(notifier.dispose);
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
      addTearDown(notifier.dispose);
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
      addTearDown(notifier.dispose);
      await notifier.initialize();

      final success = await notifier.restorePurchases();
      await Future<void>.delayed(Duration.zero);

      expect(success, isTrue);
      expect(notifier.status, BillingStatus.purchased);
      expect(notifier.isProUnlocked, isTrue);
      expect(notifier.unlockStatus.orderId, 'GPA.RESTORE-5678');
      expect(scheduleNotifier.isPro, isTrue);
      expect(shieldNotifier.isPro, isTrue);
      expect(audioNotifier.isProUnlocked, isTrue);
    });

    test('ThemeNotifier validates Pro access when entitlement stream emits locked',
        () async {
      await themeNotifier.setAccent(
        ProAccentVariant.cyberAmber,
        isLifetimePro: true,
      );
      expect(themeNotifier.currentAccent, ProAccentVariant.cyberAmber);

      final notifier = createNotifier();
      addTearDown(notifier.dispose);
      await notifier.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(themeNotifier.currentAccent, ProAccentVariant.electricEmerald);
    });

    test('ThemeNotifier does not reset Pro accent before initialize runs',
        () async {
      await themeNotifier.setAccent(
        ProAccentVariant.cyberAmber,
        isLifetimePro: true,
      );

      final notifier = createNotifier();
      addTearDown(notifier.dispose);

      expect(themeNotifier.currentAccent, ProAccentVariant.cyberAmber);
    });
  });
}
