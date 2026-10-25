import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:focusmaxxing/core/constants/schedule_constants.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/check_schedule_active_now_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/check_shield_permissions_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_installed_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_shielded_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/request_permission_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/sync_shield_with_overlay_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/toggle_shield_app_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ShieldToggleResult {
  toggled,
  upgradeRequired,
  failed,
}

class ShieldNotifier extends ChangeNotifier {
  static const int freeTierAppCap = 2;
  static const String proUnlockedPrefsKey = 'is_lifetime_pro';
  static const String maximumFocusPrefsKey = 'is_maximum_focus_enabled';

  final GetShieldedAppsUseCase getShieldedAppsUseCase;
  final GetInstalledAppsUseCase getInstalledAppsUseCase;
  final ToggleShieldAppUseCase toggleShieldAppUseCase;
  final CheckShieldPermissionsUseCase checkShieldPermissionsUseCase;
  final RequestPermissionUseCase requestPermissionUseCase;
  final SyncShieldWithOverlayUseCase syncShieldWithOverlayUseCase;
  final IShieldRepository repository;
  final CheckScheduleActiveNowUseCase? checkScheduleActiveNowUseCase;
  final SharedPreferences? sharedPreferences;

  ShieldNotifier({
    required this.getShieldedAppsUseCase,
    required this.getInstalledAppsUseCase,
    required this.toggleShieldAppUseCase,
    required this.checkShieldPermissionsUseCase,
    required this.requestPermissionUseCase,
    required this.syncShieldWithOverlayUseCase,
    required this.repository,
    this.checkScheduleActiveNowUseCase,
    this.sharedPreferences,
    bool autoInitialize = true,
  }) {
    _isPro = sharedPreferences?.getBool(proUnlockedPrefsKey) ?? false;
    _isMaximumFocusEnabled =
        sharedPreferences?.getBool(maximumFocusPrefsKey) ?? false;
    _bindOverlayEvents();
    if (autoInitialize) {
      unawaited(refresh());
    }
  }

  List<ShieldedAppEntity> _shieldedApps = const [];
  List<ShieldedAppEntity> _installedApps = const [];
  ShieldPermissionStatus _permissionStatus =
      const ShieldPermissionStatus.allGranted();
  String _searchQuery = '';
  bool _isPro = false;
  bool _isMaximumFocusEnabled = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _requiresUpgradePrompt = false;
  ShieldedAppEntity? _pendingSwapCandidate;

  final StreamController<ShieldedAppEntity> _upgradeEventController =
      StreamController<ShieldedAppEntity>.broadcast();
  StreamSubscription<dynamic>? _overlaySubscription;
  TimerNotifier? _attachedTimerNotifier;

  bool _isSessionShieldActive = false;
  bool _isScheduledShieldActive = false;
  TimerStatus? _lastSyncedStatus;
  int? _lastSyncedRemainingSeconds;
  int? _lastSyncedTargetEndTimeMs;
  String? _lastSyncedGoal;
  bool? _lastSyncedMaximumFocus;
  bool _isDisposed = false;

  List<ShieldedAppEntity> get shieldedApps => _shieldedApps;
  List<ShieldedAppEntity> get allInstalledApps => _installedApps;
  ShieldPermissionStatus get permissionStatus => _permissionStatus;
  String get searchQuery => _searchQuery;
  bool get isPro => _isPro;
  bool get isMaximumFocusEnabled => _isMaximumFocusEnabled;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get requiresUpgradePrompt => _requiresUpgradePrompt;
  ShieldedAppEntity? get pendingSwapCandidate => _pendingSwapCandidate;
  Stream<ShieldedAppEntity> get upgradeEvents => _upgradeEventController.stream;
  bool get isSessionShieldActive => _isSessionShieldActive;
  bool get isScheduledShieldActive => _isScheduledShieldActive;

  List<ShieldedAppEntity> get activeShieldedApps =>
      _shieldedApps.where((app) => app.isActive).toList(growable: false);

  Set<String> get activePackageNames => {
        for (final app in _shieldedApps)
          if (app.isActive) app.packageName,
      };

  int get activeAppCount => activePackageNames.length;

  bool isPackageActive(String packageName) =>
      activePackageNames.contains(packageName);

  List<ShieldedAppEntity> get filteredInstalledApps {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _installedApps;
    return _installedApps
        .where(
          (app) =>
              app.appName.toLowerCase().contains(query) ||
              app.packageName.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _attachedTimerNotifier?.removeListener(_onTimerChanged);
    final sub = _overlaySubscription;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    unawaited(_upgradeEventController.close());
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void attachTimerNotifier(TimerNotifier timerNotifier) {
    if (identical(_attachedTimerNotifier, timerNotifier)) return;
    _attachedTimerNotifier?.removeListener(_onTimerChanged);
    _attachedTimerNotifier = timerNotifier;
    timerNotifier.addListener(_onTimerChanged);
  }

  void _onTimerChanged() {
    final timer = _attachedTimerNotifier;
    if (timer != null) {
      unawaited(syncWithTimer(timer));
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _loadProStatus();

    final permissionsResult = await checkShieldPermissionsUseCase();
    permissionsResult.fold(
      (failure) => _errorMessage = failure.message,
      (status) => _permissionStatus = status,
    );

    final installedResult = await getInstalledAppsUseCase();
    installedResult.fold(
      (failure) => _errorMessage = failure.message,
      (apps) => _installedApps = List.unmodifiable(apps),
    );

    final shieldedResult = await getShieldedAppsUseCase();
    shieldedResult.fold(
      (failure) => _errorMessage = failure.message,
      (apps) => _shieldedApps = List.unmodifiable(apps),
    );

    _syncInstalledAppsActiveFlags();
    await _reconcileNativeShieldForActiveSession();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkPermissions() async {
    final result = await checkShieldPermissionsUseCase();
    result.fold(
      (failure) => _errorMessage = failure.message,
      (status) => _permissionStatus = status,
    );
    notifyListeners();
  }

  Future<bool> requestPermission(ShieldPermissionType permissionType) async {
    final result = await requestPermissionUseCase(permissionType);
    final granted = result.fold(
      (failure) {
        _errorMessage = failure.message;
        return false;
      },
      (success) => success,
    );
    await checkPermissions();
    return granted;
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void dismissUpgradePrompt() {
    if (!_requiresUpgradePrompt && _pendingSwapCandidate == null) return;
    _requiresUpgradePrompt = false;
    _pendingSwapCandidate = null;
    notifyListeners();
  }

  Future<ShieldToggleResult> toggleApp({
    required String packageName,
    required String appName,
    bool isPreset = false,
    Uint8List? iconBytes,
  }) async {
    final trimmedPackage = packageName.trim();
    final currentlyActive = isPackageActive(trimmedPackage);
    final nextActive = !currentlyActive;

    if (nextActive && !_isPro && activeAppCount >= freeTierAppCap) {
      final candidate = ShieldedAppEntity(
        packageName: trimmedPackage,
        appName: appName.trim().isNotEmpty ? appName.trim() : trimmedPackage,
        iconBytes: iconBytes,
        isActive: false,
        isPreset: isPreset,
        createdAt: DateTime.now().toUtc(),
      );
      _pendingSwapCandidate = candidate;
      _requiresUpgradePrompt = true;
      if (!_upgradeEventController.isClosed) {
        _upgradeEventController.add(candidate);
      }
      notifyListeners();
      return ShieldToggleResult.upgradeRequired;
    }

    _requiresUpgradePrompt = false;
    _pendingSwapCandidate = null;
    _errorMessage = null;

    final result = await toggleShieldAppUseCase(
      packageName: trimmedPackage,
      appName: appName,
      isActive: nextActive,
      isPreset: isPreset,
      iconBytes: iconBytes,
    );

    return await result.fold(
      (failure) async {
        _errorMessage = failure.message;
        notifyListeners();
        return ShieldToggleResult.failed;
      },
      (updatedApp) async {
        _upsertLocalShieldedApp(updatedApp);
        _syncInstalledAppsActiveFlags();
        await _reconcileNativeShieldForActiveSession();
        notifyListeners();
        return ShieldToggleResult.toggled;
      },
    );
  }

  Future<bool> swapFreeApp({
    required String deactivatePackageName,
    String? activatePackageName,
    String? activateAppName,
    bool? activateIsPreset,
  }) async {
    final targetPackage =
        activatePackageName ?? _pendingSwapCandidate?.packageName;
    final targetName =
        activateAppName ?? _pendingSwapCandidate?.appName ?? targetPackage;
    final targetPreset =
        activateIsPreset ?? _pendingSwapCandidate?.isPreset ?? false;

    if (targetPackage == null || targetName == null) {
      return false;
    }

    final swapResult = await repository.swapShieldApp(
      deactivatePackageName: deactivatePackageName,
      activatePackageName: targetPackage,
      activateAppName: targetName,
      activateIsPreset: targetPreset,
    );

    return await swapResult.fold(
      (failure) async {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) async {
        _requiresUpgradePrompt = false;
        _pendingSwapCandidate = null;
        final shieldedResult = await getShieldedAppsUseCase();
        shieldedResult.fold(
          (failure) => _errorMessage = failure.message,
          (apps) => _shieldedApps = List.unmodifiable(apps),
        );
        _syncInstalledAppsActiveFlags();
        await _reconcileNativeShieldForActiveSession();
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> unlockLifetimePro({bool activatePendingCandidate = true}) async {
    _isPro = true;
    _requiresUpgradePrompt = false;
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(proUnlockedPrefsKey, true);

    final candidate = _pendingSwapCandidate;
    _pendingSwapCandidate = null;

    if (activatePendingCandidate && candidate != null) {
      await toggleApp(
        packageName: candidate.packageName,
        appName: candidate.appName,
        isPreset: candidate.isPreset,
        iconBytes: candidate.iconBytes,
      );
      return;
    }

    notifyListeners();
  }

  Future<void> startShieldForSchedule({required String timeRange}) async {
    _isScheduledShieldActive = true;
    final activePackages = activePackageNames.toList();
    if (activePackages.isNotEmpty) {
      await repository.startShieldService(
        activePackages,
        isScheduled: true,
        timeRange: timeRange,
      );
    }
    notifyListeners();
  }

  Future<void> stopShieldForSchedule() async {
    _isScheduledShieldActive = false;
    if (!_isSessionShieldActive) {
      await repository.stopShieldService(force: true);
    }
    notifyListeners();
  }

  Future<bool> _checkIfScheduleActive() async {
    if (checkScheduleActiveNowUseCase == null) {
      return _isScheduledShieldActive;
    }
    final result = await checkScheduleActiveNowUseCase!();
    return result.getOrElse(() => false);
  }

  Future<void> setMaximumFocusEnabled(bool enabled) async {
    if (_isMaximumFocusEnabled == enabled) return;
    _isMaximumFocusEnabled = enabled;
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(maximumFocusPrefsKey, enabled);

    final timer = _attachedTimerNotifier;
    if (timer != null && _isSessionShieldActive) {
      await syncWithTimer(timer);
      await _reconcileNativeShieldForActiveSession();
    }
    notifyListeners();
  }

  Future<void> syncWithTimer(TimerNotifier timer) async {
    _attachedTimerNotifier ??= timer;
    final status = timer.status;

    if (status == TimerStatus.idle) {
      if (_isSessionShieldActive || _lastSyncedStatus != TimerStatus.idle) {
        _isSessionShieldActive = false;
        _lastSyncedStatus = TimerStatus.idle;
        _lastSyncedRemainingSeconds = null;
        _lastSyncedTargetEndTimeMs = null;
        _lastSyncedGoal = null;
        _lastSyncedMaximumFocus = null;

        final isScheduleActive = await _checkIfScheduleActive();
        if (!isScheduleActive && !_isScheduledShieldActive) {
          await repository.stopShieldService(force: true);
        } else {
          await repository.stopShieldService(force: false);
        }
        notifyListeners();
      }
      return;
    }

    final isBreak = status == TimerStatus.breakRunning ||
        status == TimerStatus.breakCompleted;
    final isPaused = status == TimerStatus.paused;
    final remaining = (status == TimerStatus.completed ||
            status == TimerStatus.breakCompleted)
        ? 0
        : timer.remainingSeconds;
    final targetEndMs = timer.targetEndTime?.millisecondsSinceEpoch;
    final goal =
        timer.currentTaskGoal.isNotEmpty ? timer.currentTaskGoal : 'Deep Work';
    final effectiveMaximumFocus = _isMaximumFocusEnabled &&
        (status == TimerStatus.running || status == TimerStatus.paused);

    final shouldSyncOverlay = _lastSyncedStatus != status ||
        _lastSyncedGoal != goal ||
        _lastSyncedMaximumFocus != effectiveMaximumFocus ||
        _lastSyncedTargetEndTimeMs != targetEndMs ||
        (isPaused && _lastSyncedRemainingSeconds != remaining);

    if (shouldSyncOverlay) {
      _lastSyncedStatus = status;
      _lastSyncedRemainingSeconds = remaining;
      _lastSyncedTargetEndTimeMs = targetEndMs;
      _lastSyncedGoal = goal;
      _lastSyncedMaximumFocus = effectiveMaximumFocus;
      await syncShieldWithOverlayUseCase(
        goal: goal,
        remainingSeconds: remaining,
        isBreak: isBreak,
        isMaximumFocus: effectiveMaximumFocus,
        isPaused: isPaused,
        targetEndTimeEpochMs: targetEndMs,
      );
    }

    if (!_isSessionShieldActive) {
      _isSessionShieldActive = true;
      await _reconcileNativeShieldForActiveSession();
      notifyListeners();
    }
  }

  Future<void> _reconcileNativeShieldForActiveSession() async {
    if (!_isSessionShieldActive) return;
    final blocked = activePackageNames.toList();
    if (blocked.isEmpty && !_isMaximumFocusEnabled) {
      await repository.stopShieldService(force: true);
    } else {
      await repository.startShieldService(blocked);
    }
  }

  Future<void> _loadProStatus() async {
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    _isPro = prefs.getBool(proUnlockedPrefsKey) ?? _isPro;
    _isMaximumFocusEnabled =
        prefs.getBool(maximumFocusPrefsKey) ?? _isMaximumFocusEnabled;
  }

  void _upsertLocalShieldedApp(ShieldedAppEntity updatedApp) {
    final updatedList = <ShieldedAppEntity>[];
    var replaced = false;
    for (final existing in _shieldedApps) {
      if (existing.packageName == updatedApp.packageName) {
        updatedList.add(updatedApp);
        replaced = true;
      } else {
        updatedList.add(existing);
      }
    }
    if (!replaced) {
      updatedList.add(updatedApp);
    }
    _shieldedApps = List.unmodifiable(updatedList);
  }

  void _syncInstalledAppsActiveFlags() {
    unawaited(_persistScheduledPackages());
    if (_installedApps.isEmpty) return;
    final activeSet = activePackageNames;
    _installedApps = List.unmodifiable(
      _installedApps.map(
        (app) => app.copyWith(isActive: activeSet.contains(app.packageName)),
      ),
    );
  }

  Future<void> _persistScheduledPackages() async {
    try {
      final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
      await prefs.setStringList(
        ScheduleConstants.schedulePackagesPrefsKey,
        activePackageNames.toList(),
      );
    } catch (_) {}
  }

  void _bindOverlayEvents() {
    // ignore: cancel_subscriptions
    final sub = repository.overlayEvents.listen(_handleOverlayEvent);
    _overlaySubscription = sub;
  }

  void _handleOverlayEvent(dynamic rawEvent) {
    final map = _decodePayload(rawEvent);
    if (map == null) return;
    if (map['action'] == 'returnToFocusmaxxing') {
      unawaited(repository.bringAppToForeground());
    } else if (map['action'] == 'cancelSessionFromOverlay') {
      final timer = _attachedTimerNotifier;
      if (timer != null) {
        unawaited(timer.cancelSession());
      }
      unawaited(repository.bringAppToForeground());
    }
  }

  Map<String, dynamic>? _decodePayload(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
