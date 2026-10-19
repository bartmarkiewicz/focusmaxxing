import 'package:flutter/foundation.dart';
import 'package:focusmaxxing/core/theme/pro_accent_variant.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({
    SharedPreferences? sharedPreferences,
  }) : _prefs = sharedPreferences {
    _loadAccent();
  }

  static const String prefThemeAccentColorKey = 'theme_accent_color';

  SharedPreferences? _prefs;
  ProAccentVariant _currentAccent = ProAccentVariant.electricEmerald;
  bool _hasExplicitAccent = false;

  ProAccentVariant get currentAccent => _currentAccent;

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      if (!_hasExplicitAccent) {
        _loadAccent();
      }
    }
    return _prefs!;
  }

  void _loadAccent() {
    final prefs = _prefs;
    if (prefs != null && !_hasExplicitAccent) {
      final savedId = prefs.getString(prefThemeAccentColorKey);
      _currentAccent = ProAccentVariant.fromId(savedId);
    }
  }

  Future<bool> setAccent(
    ProAccentVariant variant, {
    required bool isLifetimePro,
  }) async {
    if (variant.isProOnly && !isLifetimePro) {
      return false;
    }

    if (_currentAccent == variant) {
      return true;
    }

    _hasExplicitAccent = true;
    _currentAccent = variant;
    final prefs = await _getPrefs();
    await prefs.setString(prefThemeAccentColorKey, variant.id);
    notifyListeners();
    return true;
  }

  Future<void> validateProAccess({required bool isLifetimePro}) async {
    if (!isLifetimePro && _currentAccent.isProOnly) {
      _hasExplicitAccent = true;
      _currentAccent = ProAccentVariant.electricEmerald;
      final prefs = await _getPrefs();
      await prefs.remove(prefThemeAccentColorKey);
      notifyListeners();
    }
  }
}
