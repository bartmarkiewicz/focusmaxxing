import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/theme/app_theme.dart';
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
      theme: AppTheme.buildDarkTheme(null),
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
    testWidgets(
        'renders header, all 4 accent finishes, and correct default selection',
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
      expect(find.text('Brass · Classic Instrument'), findsOneWidget);

      // Verify all 4 variants are present
      expect(find.byKey(const ValueKey('accent_variant_brass')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('accent_variant_signal')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('accent_variant_ink')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('accent_variant_moss')),
          findsOneWidget);

      // Initially Brass has checkmark
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

      // Tap Signal (Pro only)
      await tester
          .tap(find.byKey(const ValueKey('accent_variant_signal')));
      await tester.pumpAndSettle();

      // Modal bottom sheet with LifetimeProBanner opens
      expect(find.byType(LifetimeProBanner), findsOneWidget);

      // Accent was not changed
      expect(themeNotifier.currentAccent, ProAccentVariant.cyberAmber);
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

      // Tap Ink (hyperViolet)
      await tester
          .tap(find.byKey(const ValueKey('accent_variant_ink')));
      await tester.pumpAndSettle();

      // No modal sheet opened
      expect(find.byType(LifetimeProBanner), findsNothing);

      // Current accent updated
      expect(themeNotifier.currentAccent, ProAccentVariant.hyperViolet);
      expect(find.text('Ink · Muted Technical Slate'), findsOneWidget);
    });

    testWidgets(
        'tapping Brass when non-pro works without triggering upgrade banner',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        ThemeNotifier.prefThemeAccentColorKey: 'brass',
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
          .tap(find.byKey(const ValueKey('accent_variant_brass')));
      await tester.pumpAndSettle();

      expect(find.byType(LifetimeProBanner), findsNothing);
      expect(themeNotifier.currentAccent, ProAccentVariant.cyberAmber);
    });
  });
}
