import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_daily_summary_usecase.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_recent_sessions_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/widget/domain/services/i_widget_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InsightsNotifier extends ChangeNotifier {
  static const String keyStreakEnabled = 'insights_streak_enabled';
  static const String keyIncludeWeekends = 'insights_include_weekends';
  static const String keyDailyReminderEnabled =
      'insights_daily_reminder_enabled';
  static const String keyDailyReminderHour = 'insights_reminder_hour';
  static const String keyDailyReminderMinute = 'insights_reminder_minute';

  final GetDailySummaryUseCase getDailySummaryUseCase;
  final GetRecentSessionsUseCase getRecentSessionsUseCase;
  final NotificationService notificationService;
  final SharedPreferences? sharedPreferences;
  final IWidgetSyncService? widgetSyncService;

  DailySummaryEntity? _dailySummary;
  List<SessionEntity> _recentSessions = const [];
  bool _isLoading = false;
  String? _errorMessage;

  bool _isStreakEnabled = true;
  bool _includeWeekendsInStreak = false;
  bool _isDailyReminderEnabled = false;
  int _dailyReminderHour = 9;
  int _dailyReminderMinute = 0;

  InsightsNotifier({
    required this.getDailySummaryUseCase,
    required this.getRecentSessionsUseCase,
    required this.notificationService,
    this.sharedPreferences,
    this.widgetSyncService,
  }) {
    if (sharedPreferences != null) {
      _applyPreferences(sharedPreferences!);
    } else {
      unawaited(_loadPreferencesAsync());
    }
  }

  DailySummaryEntity? get dailySummary => _dailySummary;
  List<SessionEntity> get recentSessions => _recentSessions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isStreakEnabled => _isStreakEnabled;
  bool get includeWeekendsInStreak => _includeWeekendsInStreak;
  bool get isDailyReminderEnabled => _isDailyReminderEnabled;
  int get dailyReminderHour => _dailyReminderHour;
  int get dailyReminderMinute => _dailyReminderMinute;

  TimeOfDay get dailyReminderTime =>
      TimeOfDay(hour: _dailyReminderHour, minute: _dailyReminderMinute);

  Future<void> _loadPreferencesAsync() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_isDisposed) {
      _applyPreferences(prefs);
      notifyListeners();
    }
  }

  void _applyPreferences(SharedPreferences prefs) {
    _isStreakEnabled = prefs.getBool(keyStreakEnabled) ?? true;
    _includeWeekendsInStreak = prefs.getBool(keyIncludeWeekends) ?? false;
    _isDailyReminderEnabled = prefs.getBool(keyDailyReminderEnabled) ?? false;
    _dailyReminderHour = prefs.getInt(keyDailyReminderHour) ?? 9;
    _dailyReminderMinute = prefs.getInt(keyDailyReminderMinute) ?? 0;
  }

  bool _isDisposed = false;

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

  Future<void> loadInsights({DateTime? targetDate}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final date = targetDate ?? DateTime.now();

    final summaryResult = await getDailySummaryUseCase(
      date,
      includeWeekendsInStreak: _includeWeekendsInStreak,
    );
    if (_isDisposed) return;

    final sessionsResult = await getRecentSessionsUseCase(days: 7);
    if (_isDisposed) return;

    summaryResult.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (summary) {
        _dailySummary = summary;
        unawaited(widgetSyncService?.updateGlanceableWidget(
          todayMinutes: summary.totalFocusMinutes,
          activeStreak: summary.currentStreakDays,
        ));
      },
    );

    sessionsResult.fold(
      (failure) {
        _errorMessage = _errorMessage ?? failure.message;
      },
      (sessions) {
        _recentSessions = List.unmodifiable(sessions);
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setStreakEnabled(bool enabled) async {
    if (_isStreakEnabled == enabled) return;
    _isStreakEnabled = enabled;
    notifyListeners();

    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(keyStreakEnabled, enabled);
  }

  Future<void> setIncludeWeekendsInStreak(bool include) async {
    if (_includeWeekendsInStreak == include) return;
    _includeWeekendsInStreak = include;
    notifyListeners();

    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(keyIncludeWeekends, include);

    await loadInsights();
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    if (_isDailyReminderEnabled == enabled) return;
    _isDailyReminderEnabled = enabled;
    notifyListeners();

    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(keyDailyReminderEnabled, enabled);

    if (enabled) {
      await notificationService.scheduleDailyReminder(
        hour: _dailyReminderHour,
        minute: _dailyReminderMinute,
      );
    } else {
      await notificationService.cancelDailyReminder();
    }
  }

  Future<void> setDailyReminderTime(int hour, int minute) async {
    _dailyReminderHour = hour;
    _dailyReminderMinute = minute;
    notifyListeners();

    final prefs = sharedPreferences ?? await SharedPreferences.getInstance();
    await prefs.setInt(keyDailyReminderHour, hour);
    await prefs.setInt(keyDailyReminderMinute, minute);

    if (_isDailyReminderEnabled) {
      await notificationService.scheduleDailyReminder(
        hour: hour,
        minute: minute,
      );
    }
  }

  Future<void> refresh() => loadInsights();
}
