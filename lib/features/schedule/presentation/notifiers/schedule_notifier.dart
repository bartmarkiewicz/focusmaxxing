import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/save_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/toggle_auto_shield_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleNotifier extends ChangeNotifier {
  static const String proUnlockedPrefsKey = 'is_lifetime_pro';

  final GetScheduleUseCase getScheduleUseCase;
  final SaveScheduleUseCase saveScheduleUseCase;
  final ToggleAutoShieldUseCase toggleAutoShieldUseCase;
  final IScheduleRepository repository;
  final SharedPreferences? sharedPreferences;

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
    required this.repository,
    this.sharedPreferences,
    bool autoInitialize = true,
  }) {
    _isPro = sharedPreferences?.getBool(proUnlockedPrefsKey) ?? false;
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
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> setStartTime(int hour, int minute) async {
    final newStartMinutes = hour * 60 + minute;
    if (newStartMinutes >= _schedule.endTotalMinutes) {
      _errorMessage = 'Start time must precede end time';
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
    if (_schedule.startTotalMinutes >= newEndMinutes) {
      _errorMessage = 'Start time must precede end time';
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

  void unlockLifetimePro() {
    _isPro = true;
    _requiresProPrompt = false;
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
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> _loadProStatus() async {
    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    _isPro = prefs.getBool(proUnlockedPrefsKey) ?? _isPro;
  }
}
