import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:focusmaxxing/core/constants/schedule_constants.dart';
import 'package:focusmaxxing/core/security/pro_receipt_verifier.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/check_schedule_active_now_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/save_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/toggle_auto_shield_usecase.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleNotifier extends ChangeNotifier {
  static const String proUnlockedPrefsKey =
      ScheduleConstants.proUnlockedPrefsKey;

  final GetScheduleUseCase getScheduleUseCase;
  final SaveScheduleUseCase saveScheduleUseCase;
  final ToggleAutoShieldUseCase toggleAutoShieldUseCase;
  final CheckScheduleActiveNowUseCase? checkScheduleActiveNowUseCase;
  final IScheduleRepository? repository;
  final SharedPreferences? sharedPreferences;

  ShieldNotifier? shieldNotifier;

  ScheduleConfigEntity _schedule = ScheduleConfigEntity.initial;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPro = false;
  bool _requiresProPrompt = false;
  bool _isDisposed = false;

  ScheduleNotifier({
    required this.getScheduleUseCase,
    required this.saveScheduleUseCase,
    required this.toggleAutoShieldUseCase,
    this.checkScheduleActiveNowUseCase,
    this.repository,
    this.shieldNotifier,
    this.sharedPreferences,
    bool autoInitialize = true,
  }) {
    final prefs = sharedPreferences;
    _isPro = prefs != null && ProReceiptVerifier.isProUnlockedInPrefs(prefs);
    if (autoInitialize) {
      unawaited(loadSchedule());
    }
  }

  ScheduleConfigEntity get schedule => _schedule;
  bool get isEnabled => _schedule.isEnabled;
  int get startHour => _schedule.startHour;
  int get startMinute => _schedule.startMinute;
  int get endHour => _schedule.endHour;
  int get endMinute => _schedule.endMinute;
  List<int> get activeDays => _schedule.activeDays;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPro => _isPro;
  bool get requiresProPrompt => _requiresProPrompt;
  bool get isValid => _schedule.isValid;
  String get formattedTimeRange => _schedule.formattedTimeRange;

  void attachShieldNotifier(ShieldNotifier? notifier) {
    shieldNotifier = notifier;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> loadSchedule() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await _loadProStatus();

    final result = await getScheduleUseCase();
    result.fold(
      (failure) => _errorMessage = failure.message,
      (loadedSchedule) => _schedule = loadedSchedule,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> setEnabled(bool enabled) async {
    await _loadProStatus();

    if (enabled && !_isPro) {
      _requiresProPrompt = true;
      notifyListeners();
      return false;
    }

    _requiresProPrompt = false;
    _errorMessage = null;

    final result = await toggleAutoShieldUseCase(enabled);
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (updatedSchedule) {
        _schedule = updatedSchedule;
        if (enabled) {
          final now = DateTime.now();
          if (updatedSchedule.isWithinSchedule(now)) {
            unawaited(
              shieldNotifier?.startShieldForSchedule(
                timeRange: updatedSchedule.formattedTimeRange,
              ),
            );
          }
        } else {
          unawaited(shieldNotifier?.stopShieldForSchedule());
        }
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> setStartTime(int hour, int minute) async {
    final newStartMinutes = hour * 60 + minute;
    if (newStartMinutes == _schedule.endTotalMinutes) {
      _errorMessage = 'Start time and end time cannot be identical';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    final updated = _schedule.copyWith(
      startHour: hour,
      startMinute: minute,
    );

    return _persistUpdatedSchedule(updated);
  }

  Future<bool> setEndTime(int hour, int minute) async {
    final newEndMinutes = hour * 60 + minute;
    if (_schedule.startTotalMinutes == newEndMinutes) {
      _errorMessage = 'Start time and end time cannot be identical';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    final updated = _schedule.copyWith(
      endHour: hour,
      endMinute: minute,
    );

    return _persistUpdatedSchedule(updated);
  }

  Future<bool> toggleWeekday(int weekday) async {
    if (weekday < 1 || weekday > 7) return false;

    final currentDays = List<int>.from(_schedule.activeDays);
    if (currentDays.contains(weekday)) {
      if (currentDays.length == 1 && _schedule.isEnabled) {
        _errorMessage = 'Schedule must include at least one active day';
        notifyListeners();
        return false;
      }
      currentDays.remove(weekday);
    } else {
      currentDays.add(weekday);
      currentDays.sort();
    }

    _errorMessage = null;
    final updated = _schedule.copyWith(activeDays: currentDays);
    return _persistUpdatedSchedule(updated);
  }

  void dismissProPrompt() {
    if (!_requiresProPrompt) return;
    _requiresProPrompt = false;
    notifyListeners();
  }

  Future<void> unlockLifetimePro() async {
    if (_isPro && !_requiresProPrompt) return;
    _isPro = true;
    _requiresProPrompt = false;
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    await ProReceiptVerifier.ensureUnlockedInPrefs(prefs);
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _persistUpdatedSchedule(ScheduleConfigEntity updated) async {
    final result = await saveScheduleUseCase(updated);
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        _schedule = updated;
        if (updated.isEnabled) {
          final now = DateTime.now();
          if (updated.isWithinSchedule(now)) {
            unawaited(
              shieldNotifier?.startShieldForSchedule(
                timeRange: updated.formattedTimeRange,
              ),
            );
          } else {
            unawaited(shieldNotifier?.stopShieldForSchedule());
          }
        } else {
          unawaited(shieldNotifier?.stopShieldForSchedule());
        }
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> _loadProStatus() async {
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    _isPro = ProReceiptVerifier.isProUnlockedInPrefs(prefs) || _isPro;
  }
}
