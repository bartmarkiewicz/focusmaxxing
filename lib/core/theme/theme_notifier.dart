import 'dart:async';

import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/pro_accent_variant.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/watch_pro_entitlement_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({
    SharedPreferences? sharedPreferences,
    this.watchProEntitlementUseCase,
  }) : _prefs = sharedPreferences {
    _loadPreferences();
    _bindEntitlementStream();
  }

  static const String prefThemeAccentColorKey = 'theme_accent_color';
  static const String prefThemeModeKey = 'theme_mode_preference';

  final WatchProEntitlementUseCase? watchProEntitlementUseCase;
  StreamSubscription<ProUnlockStatusEntity>? _entitlementSubscription;
  SharedPreferences? _prefs;

  AccentFinish _currentFinish = AccentFinish.brass;
  ThemeMode _themeMode = ThemeMode.system;
  bool _hasExplicitFinish = false;
  bool _hasExplicitThemeMode = false;
  bool _isDisposed = false;

  AccentFinish get currentFinish => _currentFinish;
  ProAccentVariant get currentAccent => ProAccentVariant.fromId(_currentFinish.id);
  ThemeMode get themeMode => _themeMode;

  void _bindEntitlementStream() {
    final watchEntitlement = watchProEntitlementUseCase;
    if (watchEntitlement == null) return;
    _entitlementSubscription = watchEntitlement().listen(
      (status) {
        if (!_isDisposed) {
          unawaited(validateProAccess(isLifetimePro: status.isUnlocked));
        }
      },
      onError: (Object _) {},
    );
  }

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      if (!_hasExplicitFinish || !_hasExplicitThemeMode) {
        _loadPreferences();
      }
    }
    return _prefs!;
  }

  void _loadPreferences() {
    final prefs = _prefs;
    if (prefs == null) return;

    if (!_hasExplicitFinish) {
      final savedId = prefs.getString(prefThemeAccentColorKey);
      _currentFinish = AccentFinish.fromId(savedId);
    }

    if (!_hasExplicitThemeMode) {
      final savedMode = prefs.getString(prefThemeModeKey);
      if (savedMode == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (savedMode == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _hasExplicitThemeMode = true;
    _themeMode = mode;
    final prefs = await _getPrefs();
    final modeString = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
    await prefs.setString(prefThemeModeKey, modeString);
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<bool> setFinish(
    AccentFinish finish, {
    required bool isLifetimePro,
  }) async {
    if (finish.isProOnly && !isLifetimePro) {
      return false;
    }

    if (_currentFinish == finish) {
      return true;
    }

    _hasExplicitFinish = true;
    _currentFinish = finish;
    final prefs = await _getPrefs();
    await prefs.setString(prefThemeAccentColorKey, finish.id);
    if (!_isDisposed) {
      notifyListeners();
    }
    return true;
  }

  Future<bool> setAccent(
    ProAccentVariant variant, {
    required bool isLifetimePro,
  }) async {
    return setFinish(variant.finish, isLifetimePro: isLifetimePro);
  }

  Future<void> validateProAccess({required bool isLifetimePro}) async {
    if (!isLifetimePro && _currentFinish.isProOnly) {
      _hasExplicitFinish = true;
      _currentFinish = AccentFinish.brass;
      final prefs = await _getPrefs();
      await prefs.remove(prefThemeAccentColorKey);
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_entitlementSubscription?.cancel());
    _entitlementSubscription = null;
    super.dispose();
  }
}
