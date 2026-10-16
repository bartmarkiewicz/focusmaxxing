import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/repositories/i_billing_repository.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/get_product_details_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/purchase_lifetime_pro_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/restore_purchases_usecase.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:focusmaxxing/features/billing/presentation/widgets/lifetime_pro_banner.dart';
import 'package:provider/provider.dart';

class _MockBillingRepository implements IBillingRepository {
  final StreamController<ProUnlockStatusEntity> _controller =
      StreamController<ProUnlockStatusEntity>.broadcast();

  ProUnlockStatusEntity currentStatus = ProUnlockStatusEntity.locked;
  ProProductDetailsEntity details = ProProductDetailsEntity.fallback;
  bool buyCalled = false;
  bool restoreCalled = false;

  @override
  Stream<ProUnlockStatusEntity> get purchaseStatusStream => _controller.stream;

  @override
  Future<ProProductDetailsEntity> getProDetails() async => details;

  @override
  Future<ProUnlockStatusEntity> purchaseLifetimePro() async {
    buyCalled = true;
    currentStatus = const ProUnlockStatusEntity(
      isUnlocked: true,
      orderId: 'GPA.WIDGET-TEST',
    );
    _controller.add(currentStatus);
    return currentStatus;
  }

  @override
  Future<ProUnlockStatusEntity> restorePurchases() async {
    restoreCalled = true;
    currentStatus = const ProUnlockStatusEntity(
      isUnlocked: true,
      orderId: 'GPA.WIDGET-RESTORE',
    );
    _controller.add(currentStatus);
    return currentStatus;
  }

  @override
  Future<bool> isProPurchased() async => currentStatus.isUnlocked;

  @override
  Future<ProUnlockStatusEntity> getCachedProStatus() async => currentStatus;

  @override
  Future<void> dispose() async => _controller.close();
}

void main() {
  group('LifetimeProBanner & ProSupporterBadge Widget Tests', () {
    late _MockBillingRepository repo;
    late BillingNotifier notifier;

    setUp(() {
      repo = _MockBillingRepository();
      notifier = BillingNotifier(
        getProductDetailsUseCase: GetProductDetailsUseCase(repo),
        purchaseLifetimeProUseCase: PurchaseLifetimeProUseCase(repo),
        restorePurchasesUseCase: RestorePurchasesUseCase(repo),
        repository: repo,
        autoInitialize: false,
      );
    });

    tearDown(() async {
      notifier.dispose();
      await repo.dispose();
    });

    Widget buildSubject() {
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: const [
              ProSupporterBadge(),
            ],
          ),
          body: SingleChildScrollView(
            child: LifetimeProBanner(notifier: notifier),
          ),
        ),
      );
    }

    testWidgets('displays \$9.99 price when locked and ProSupporterBadge is hidden',
        (tester) async {
      await notifier.initialize();
      await tester.pumpWidget(
        ChangeNotifierProvider<BillingNotifier>.value(
          value: notifier,
          child: buildSubject(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Unlock Unlimited Shielding & Audio for \$9.99'),
        findsOneWidget,
      );
      expect(
        find.text('Unlock Lifetime Pro — \$9.99'),
        findsOneWidget,
      );
      expect(find.text('Restore Purchases'), findsOneWidget);

      // ProSupporterBadge should not be visible when locked
      expect(find.text('LIFETIME PRO'), findsNothing);
    });

    testWidgets('transitions to ⭐ Lifetime Pro Unlocked badge when purchased',
        (tester) async {
      await notifier.initialize();
      await tester.pumpWidget(
        ChangeNotifierProvider<BillingNotifier>.value(
          value: notifier,
          child: buildSubject(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap buy button
      await tester.tap(find.byKey(const ValueKey('buy_lifetime_pro_button')));
      await tester.pumpAndSettle();

      expect(repo.buyCalled, isTrue);
      expect(find.text('⭐ Lifetime Pro Unlocked'), findsOneWidget);
      expect(find.text('LIFETIME PRO: ACTIVE'), findsOneWidget);
      expect(find.text('Order ID: GPA.WIDGET-TEST'), findsOneWidget);

      // ProSupporterBadge is now rendered in the AppBar
      expect(find.text('LIFETIME PRO'), findsOneWidget);
    });

    testWidgets('tapping Restore Purchases invokes restore flow',
        (tester) async {
      await notifier.initialize();
      await tester.pumpWidget(
        ChangeNotifierProvider<BillingNotifier>.value(
          value: notifier,
          child: buildSubject(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap restore purchases button
      await tester.tap(find.byKey(const ValueKey('restore_purchases_button')));
      await tester.pumpAndSettle();

      expect(repo.restoreCalled, isTrue);
      expect(find.text('⭐ Lifetime Pro Unlocked'), findsOneWidget);
    });
  });
}
