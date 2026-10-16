import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/theme/app_theme.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/upgrade_modal_sheet.dart';

void main() {
  final activeApps = [
    ShieldedAppEntity(
      packageName: 'com.instagram.android',
      appName: 'Instagram',
      isActive: true,
      isPreset: true,
      createdAt: DateTime.utc(2026, 10, 16),
    ),
    ShieldedAppEntity(
      packageName: 'com.zhiliaoapp.musically',
      appName: 'TikTok',
      isActive: true,
      isPreset: true,
      createdAt: DateTime.utc(2026, 10, 16),
    ),
  ];

  group('UpgradeModalSheetTest', () {
    testWidgets(
      'displays 2-app cap explanation text and \$9.99 Lifetime Pro button',
      (tester) async {
        var proUnlocked = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildDarkTheme(null),
            home: Scaffold(
              body: UpgradeModalSheet(
                activeApps: activeApps,
                candidateAppName: 'Reddit',
                onUnlockPro: () => proUnlocked = true,
                onConfirmSwap: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('2-App Free Cap Reached'), findsOneWidget);
        expect(find.text('Attempting to shield Reddit'), findsOneWidget);
        expect(
          find.textContaining('The Free Tier shields up to 2 apps'),
          findsOneWidget,
        );
        expect(find.text('Unlock Lifetime Pro — \$9.99'), findsOneWidget);
        expect(find.text('Swap Free App'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('unlock_lifetime_pro_button')),
        );
        await tester.pump();
        expect(proUnlocked, isTrue);
      },
    );

    testWidgets(
      'tapping Swap Free App displays active apps with radio selectors and confirms swap',
      (tester) async {
        String? swappedOutPackage;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildDarkTheme(null),
            home: Scaffold(
              body: UpgradeModalSheet(
                activeApps: activeApps,
                candidateAppName: 'Reddit',
                onUnlockPro: () {},
                onConfirmSwap: (pkg) => swappedOutPackage = pkg,
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('swap_free_app_button')));
        await tester.pumpAndSettle();

        expect(find.text('Swap With Reddit'), findsOneWidget);
        expect(find.text('Instagram'), findsOneWidget);
        expect(find.text('TikTok'), findsOneWidget);
        expect(find.byType(Radio<String>), findsNWidgets(2));

        await tester.tap(
          find.byKey(const ValueKey('swap_option_com.zhiliaoapp.musically')),
        );
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('confirm_swap_button')));
        await tester.pump();

        expect(swappedOutPackage, 'com.zhiliaoapp.musically');
      },
    );
  });
}
