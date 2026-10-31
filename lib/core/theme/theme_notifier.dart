import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:focusmaxxing/core/theme/pro_accent_variant.dart';
import 'package:focusmaxxing/features/billing/domain/entities/pro_unlock_status_entity.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/watch_pro_entitlement_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({
    SharedPreferences? sharedPreferences,
    this.watchProEntitlementUseCase,
  }) : _prefs = sharedPreferences {
    _loadAccent();
    _bindEntitlementStream();
  }

  static const String prefThemeAccentColorKey = 'theme_accent_color';

  final WatchProEntitlementUseCase? watchProEntitlementUseCase;
  StreamSubscription<ProUnlockStatusEntity>? _entitlementSubscription;
  SharedPreferences? _prefs;
  ProAccentVariant _currentAccent = ProAccentVariant.electricEmerald;
  bool _hasExplicitAccent = false;
  bool _isDisposed = false;

  ProAccentVariant get currentAccent => _currentAccent;

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
    if (!_isDisposed) {
      notifyListeners();
    }
    return true;
  }

  Future<void> validateProAccess({required bool isLifetimePro}) async {
    if (!isLifetimePro && _currentAccent.isProOnly) {
      _hasExplicitAccent = true;
      _currentAccent = ProAccentVariant.electricEmerald;
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
