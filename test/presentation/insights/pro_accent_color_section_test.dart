import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/theme/pro_accent_variant.dart';
import 'package:focusmaxxing/core/theme/theme_notifier.dart';
import 'package:focusmaxxing/features/billing/presentation/widgets/lifetime_pro_banner.dart';
import 'package:focusmaxxing/features/insights/presentation/widgets/pro_accent_color_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required ThemeNotifier themeNotifier,
    bool isProUnlocked = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProAccentColorSection(
            themeNotifier: themeNotifier,
            isProUnlocked: isProUnlocked,
          ),
        ),
      ),
    );
  }

  group('ProAccentColorSection Widget Tests', () {
    testWidgets('renders header, all 4 accent variants, and correct default selection',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final themeNotifier = ThemeNotifier(sharedPreferences: prefs);

      await tester.pumpWidget(
        buildTestWidget(
          themeNotifier: themeNotifier,
          isProUnlocked: false,
        ),
      );

      expect(find.text('Focus Accent Color'), findsOneWidget);
      expect(find.text('Electric Emerald · Default Focus'), findsOneWidget);

      // Verify all 4 variants are present
      expect(find.byKey(const ValueKey('accent_variant_electric_emerald')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('accent_variant_cyber_amber')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('accent_variant_hyper_violet')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('accent_variant_glacier_blue')),
          findsOneWidget);

      // Initially Electric Emerald has checkmark
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // In non-pro mode, 3 Pro variants have PRO badges
      expect(find.text('PRO'), findsNWidgets(3));
    });

    testWidgets('hides all PRO badges when isProUnlocked is true',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final themeNotifier = ThemeNotifier(sharedPreferences: prefs);

      await tester.pumpWidget(
        buildTestWidget(
          themeNotifier: themeNotifier,
          isProUnlocked: true,
        ),
      );

      expect(find.text('PRO'), findsNothing);
    });

    testWidgets(
        'tapping locked Pro accent variant prompts LifetimeProBanner bottom sheet',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final themeNotifier = ThemeNotifier(sharedPreferences: prefs);

      await tester.pumpWidget(
        buildTestWidget(
          themeNotifier: themeNotifier,
          isProUnlocked: false,
        ),
      );

      // Tap Cyber Amber (Pro only)
      await tester.tap(find.byKey(const ValueKey('accent_variant_cyber_amber')));
      await tester.pumpAndSettle();

      // Modal bottom sheet with LifetimeProBanner opens
      expect(find.byType(LifetimeProBanner), findsOneWidget);

      // Accent was not changed
      expect(themeNotifier.currentAccent, ProAccentVariant.electricEmerald);
    });

    testWidgets(
        'tapping Pro accent variant when unlocked applies selection immediately',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final themeNotifier = ThemeNotifier(sharedPreferences: prefs);

      await tester.pumpWidget(
        buildTestWidget(
          themeNotifier: themeNotifier,
          isProUnlocked: true,
        ),
      );

      // Tap Hyper Violet
      await tester.tap(find.byKey(const ValueKey('accent_variant_hyper_violet')));
      await tester.pumpAndSettle();

      // No modal sheet opened
      expect(find.byType(LifetimeProBanner), findsNothing);

      // Current accent updated
      expect(themeNotifier.currentAccent, ProAccentVariant.hyperViolet);
      expect(find.text('Hyper Violet · Deep Meditative Flow'), findsOneWidget);
    });

    testWidgets(
        'tapping Electric Emerald when non-pro works without triggering upgrade banner',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        ThemeNotifier.prefThemeAccentColorKey: 'electric_emerald',
      });
      final prefs = await SharedPreferences.getInstance();
      final themeNotifier = ThemeNotifier(sharedPreferences: prefs);

      await tester.pumpWidget(
        buildTestWidget(
          themeNotifier: themeNotifier,
          isProUnlocked: false,
        ),
      );

      await tester
          .tap(find.byKey(const ValueKey('accent_variant_electric_emerald')));
      await tester.pumpAndSettle();

      expect(find.byType(LifetimeProBanner), findsNothing);
      expect(themeNotifier.currentAccent, ProAccentVariant.electricEmerald);
    });
  });
}
