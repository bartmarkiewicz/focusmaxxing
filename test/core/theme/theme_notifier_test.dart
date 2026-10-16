import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/theme/pro_accent_variant.dart';
import 'package:focusmaxxing/core/theme/theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeNotifier Unit Tests', () {
    test('defaults to electricEmerald when SharedPreferences has no saved value',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeNotifier(sharedPreferences: prefs);

      expect(notifier.currentAccent, ProAccentVariant.electricEmerald);
    });

    test('loads saved accent variant from SharedPreferences on initialization',
        () async {
      SharedPreferences.setMockInitialValues({
        ThemeNotifier.prefThemeAccentColorKey: 'hyper_violet',
      });
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeNotifier(sharedPreferences: prefs);

      expect(notifier.currentAccent, ProAccentVariant.hyperViolet);
    });

    test('falls back to electricEmerald if saved id is invalid or unknown',
        () async {
      SharedPreferences.setMockInitialValues({
        ThemeNotifier.prefThemeAccentColorKey: 'non_existent_variant',
      });
      final prefs = await SharedPreferences.getInstance();

      final notifier = ThemeNotifier(sharedPreferences: prefs);

      expect(notifier.currentAccent, ProAccentVariant.electricEmerald);
    });

    test(
        'rejects setting Pro-only accent when isLifetimePro is false and does not notify',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeNotifier(sharedPreferences: prefs);

      var notified = false;
      notifier.addListener(() => notified = true);

      final result = await notifier.setAccent(
        ProAccentVariant.cyberAmber,
        isLifetimePro: false,
      );

      expect(result, isFalse);
      expect(notifier.currentAccent, ProAccentVariant.electricEmerald);
      expect(notified, isFalse);
      expect(
        prefs.getString(ThemeNotifier.prefThemeAccentColorKey),
        isNull,
      );
    });

    test(
        'allows setting Pro-only accent when isLifetimePro is true, persists and notifies',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeNotifier(sharedPreferences: prefs);

      var notified = false;
      notifier.addListener(() => notified = true);

      final result = await notifier.setAccent(
        ProAccentVariant.glacierBlue,
        isLifetimePro: true,
      );

      expect(result, isTrue);
      expect(notifier.currentAccent, ProAccentVariant.glacierBlue);
      expect(notified, isTrue);
      expect(
        prefs.getString(ThemeNotifier.prefThemeAccentColorKey),
        'glacier_blue',
      );
    });

    test(
        'allows non-pro user to select electricEmerald without error',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeNotifier(sharedPreferences: prefs);

      final result = await notifier.setAccent(
        ProAccentVariant.electricEmerald,
        isLifetimePro: false,
      );

      expect(result, isTrue);
      expect(notifier.currentAccent, ProAccentVariant.electricEmerald);
    });

    test(
        'does not re-persist or notify if setting current accent variant',
        () async {
      SharedPreferences.setMockInitialValues({
        ThemeNotifier.prefThemeAccentColorKey: 'cyber_amber',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeNotifier(sharedPreferences: prefs);

      var notified = false;
      notifier.addListener(() => notified = true);

      final result = await notifier.setAccent(
        ProAccentVariant.cyberAmber,
        isLifetimePro: true,
      );

      expect(result, isTrue);
      expect(notified, isFalse);
    });

    test(
        'validateProAccess resets to electricEmerald and clears prefs if non-pro has pro accent',
        () async {
      SharedPreferences.setMockInitialValues({
        ThemeNotifier.prefThemeAccentColorKey: 'hyper_violet',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeNotifier(sharedPreferences: prefs);

      expect(notifier.currentAccent, ProAccentVariant.hyperViolet);

      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.validateProAccess(isLifetimePro: false);

      expect(notifier.currentAccent, ProAccentVariant.electricEmerald);
      expect(notified, isTrue);
      expect(
        prefs.getString(ThemeNotifier.prefThemeAccentColorKey),
        isNull,
      );
    });

    test(
        'validateProAccess does nothing if user has Lifetime Pro entitlement',
        () async {
      SharedPreferences.setMockInitialValues({
        ThemeNotifier.prefThemeAccentColorKey: 'hyper_violet',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeNotifier(sharedPreferences: prefs);

      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.validateProAccess(isLifetimePro: true);

      expect(notifier.currentAccent, ProAccentVariant.hyperViolet);
      expect(notified, isFalse);
      expect(
        prefs.getString(ThemeNotifier.prefThemeAccentColorKey),
        'hyper_violet',
      );
    });
  });
}
