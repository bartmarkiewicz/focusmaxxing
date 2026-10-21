import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_daily_summary_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/widget/domain/services/i_widget_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TimerStatus {
  idle,
  running,
  paused,
  completed,
  breakRunning,
  breakCompleted,
}

class TimerNotifier extends ChangeNotifier {
  static const int defaultFocusSeconds = 25 * 60;
  static const int defaultBreakSeconds = 5 * 60;
  static const int cancelHoldTotalMs = 5000;
  static const String recentGoalsKey = 'recent_focus_goals';
  static const String singleSessionModeKey = 'is_single_session_mode';

  final StartSessionUseCase startSessionUseCase;
  final CompleteSessionUseCase completeSessionUseCase;
  final CancelSessionUseCase cancelSessionUseCase;
  final NotificationService notificationService;
  final MarkTaskCompletedUseCase? markTaskCompletedUseCase;
  final SharedPreferences? prefs;
  final IWidgetSyncService? widgetSyncService;
  final GetDailySummaryUseCase? getDailySummaryUseCase;
  BacklogNotifier? backlogNotifier;

  TimerNotifier({
    required this.startSessionUseCase,
    required this.completeSessionUseCase,
    required this.cancelSessionUseCase,
    required this.notificationService,
    this.markTaskCompletedUseCase,
    this.prefs,
    this.widgetSyncService,
    this.getDailySummaryUseCase,
    this.backlogNotifier,
  }) {
    _isSingleSessionMode = prefs?.getBool(singleSessionModeKey) ?? false;
    unawaited(_loadRecentGoals());
  }

  void attachBacklogNotifier(BacklogNotifier? notifier) {
    backlogNotifier = notifier;
  }

  void clearLinkedBacklogTaskIfMatches(int taskId) {
    if (_linkedBacklogTaskId == taskId) {
      _linkedBacklogTaskId = null;
      notifyListeners();
    }
  }

  TimerStatus _status = TimerStatus.idle;
  int _focusDurationSeconds = defaultFocusSeconds;
  int _targetDurationSeconds = defaultFocusSeconds;
  int _remainingSeconds = defaultFocusSeconds;
  Duration _remainingDuration = const Duration(seconds: defaultFocusSeconds);
  DateTime? _targetEndTime;
  String _currentTaskGoal = '';
  int? _linkedBacklogTaskId;
  int? _activeSessionId;
  final ValueNotifier<double> cancelHoldProgressNotifier =
      ValueNotifier<double>(0.0);
  List<String> _recentGoals = const [];
  bool _isSingleSessionMode = false;
  bool _hasUserModifiedSingleSessionMode = false;
  String? _errorMessage;

  Timer? _periodicTicker;
  Timer? _cancelHoldTimer;
  DateTime? _cancelHoldStartTime;
  bool _isStarting = false;
  bool _isCancelling = false;
  bool _isCheckingIn = false;
  bool _isDisposed = false;

  TimerStatus get status => _status;
  int get focusDurationSeconds => _focusDurationSeconds;
  int get targetDurationSeconds => _targetDurationSeconds;
  int get remainingSeconds => _remainingSeconds;
  String get currentTaskGoal => _currentTaskGoal;
  int? get linkedBacklogTaskId => _linkedBacklogTaskId;
  List<String> get recentGoals => _recentGoals;
  bool get isSingleSessionMode => _isSingleSessionMode;
  double get cancelHoldProgress => cancelHoldProgressNotifier.value;
  int? get activeSessionId => _activeSessionId;
  String? get errorMessage => _errorMessage;
  DateTime? get targetEndTime => _targetEndTime;

  double get timerProgress {
    if (_targetDurationSeconds == 0) return 0.0;
    final elapsed = _targetDurationSeconds - _remainingSeconds;
    final progress = elapsed / _targetDurationSeconds;
    return progress.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _periodicTicker?.cancel();
    _cancelHoldTimer?.cancel();
    cancelHoldProgressNotifier.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void setDurationPreset(int seconds) {
    if (_status != TimerStatus.idle || seconds <= 0) return;
    _focusDurationSeconds = seconds;
    _targetDurationSeconds = seconds;
    _remainingSeconds = seconds;
    _remainingDuration = Duration(seconds: seconds);
    notifyListeners();
  }

  void setTaskGoal(String goal, {int? backlogTaskId}) {
    _currentTaskGoal = goal;
    _linkedBacklogTaskId = backlogTaskId;
    notifyListeners();
  }

  Future<void> setSingleSessionMode(bool enabled) async {
    _hasUserModifiedSingleSessionMode = true;
    if (_isSingleSessionMode == enabled) return;
    _isSingleSessionMode = enabled;
    notifyListeners();
    try {
      final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
      await sharedPrefs.setBool(singleSessionModeKey, enabled);
    } on Exception catch (_) {}
  }

  Future<void> toggleSingleSessionMode() async {
    await setSingleSessionMode(!_isSingleSessionMode);
  }

  Future<bool> startFocusSession(String goal, {int? backlogTaskId}) async {
    if ((_status != TimerStatus.idle &&
            _status != TimerStatus.breakCompleted &&
            _status != TimerStatus.breakRunning) ||
        _isStarting) {
      return false;
    }
    _isStarting = true;
    final previousStatus = _status;

    try {
      final trimmed = goal.trim();
      final effectiveGoal = trimmed.isNotEmpty ? trimmed : 'Deep Work';

      final result = await startSessionUseCase(
        taskGoal: effectiveGoal,
        sessionType: SessionType.focus,
        targetDurationSeconds: _focusDurationSeconds,
      );

      final isSuccess = await result.fold(
        (failure) async {
          _errorMessage = failure.message;
          _status = (previousStatus == TimerStatus.idle)
              ? TimerStatus.idle
              : TimerStatus.breakCompleted;
          notifyListeners();
          return false;
        },
        (sessionId) async {
          _periodicTicker?.cancel();
          _currentTaskGoal = effectiveGoal;
          _linkedBacklogTaskId = backlogTaskId;
          _targetDurationSeconds = _focusDurationSeconds;
          _remainingSeconds = _targetDurationSeconds;
          _remainingDuration = Duration(seconds: _remainingSeconds);
          _targetEndTime = DateTime.now().add(_remainingDuration);
          cancelHoldProgressNotifier.value = 0.0;
          _errorMessage = null;

          await _cacheRecentGoal(_currentTaskGoal);

          _activeSessionId = sessionId;
          _status = TimerStatus.running;
          _startTicker();
          _updateNotification();
          final targetEnd = _targetEndTime;
          if (targetEnd != null) {
            unawaited(
              notificationService.scheduleSessionCompletionNotification(
                targetEndTime: targetEnd,
                goal: _currentTaskGoal,
              ),
            );
          }
          notifyListeners();
          return true;
        },
      );
      return isSuccess;
    } finally {
      _isStarting = false;
    }
  }

  void pause() {
    if (_status != TimerStatus.running) return;

    final targetEnd = _targetEndTime;
    if (targetEnd != null) {
      final diff = targetEnd.difference(DateTime.now());
      if (diff.isNegative || diff.inMilliseconds <= 0) {
        syncWithWallClock();
        return;
      }
      _remainingDuration = diff;
    }
    _periodicTicker?.cancel();
    _targetEndTime = null;
    _remainingSeconds = (_remainingDuration.inMilliseconds / 1000).ceil();
    _status = TimerStatus.paused;
    _updateNotification();
    unawaited(notificationService.cancelSessionCompletionNotification());
    notifyListeners();
  }

  void resume() {
    if (_status != TimerStatus.paused) return;

    _targetEndTime = DateTime.now().add(_remainingDuration);
    _status = TimerStatus.running;
    cancelHoldProgressNotifier.value = 0.0;
    _startTicker();
    _updateNotification();
    final targetEnd = _targetEndTime;
    if (targetEnd != null) {
      unawaited(
        notificationService.scheduleSessionCompletionNotification(
          targetEndTime: targetEnd,
          goal: _currentTaskGoal,
        ),
      );
    }
    notifyListeners();
  }

  void startHoldToCancel() {
    if (_status != TimerStatus.paused) return;

    _cancelHoldStartTime = DateTime.now();
    cancelHoldProgressNotifier.value = 0.0;
    _cancelHoldTimer?.cancel();

    _cancelHoldTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        final startTime = _cancelHoldStartTime;
        if (startTime == null) {
          timer.cancel();
          return;
        }

        final elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
        final progress = (elapsedMs / cancelHoldTotalMs).clamp(0.0, 1.0);
        cancelHoldProgressNotifier.value = progress;

        if (elapsedMs >= cancelHoldTotalMs) {
          timer.cancel();
          _cancelHoldTimer = null;
          _cancelHoldStartTime = null;
          unawaited(cancelSession());
        }
      },
    );
  }

  void releaseHoldToCancel() {
    final startTime = _cancelHoldStartTime;
    _cancelHoldTimer?.cancel();
    _cancelHoldTimer = null;
    _cancelHoldStartTime = null;

    if (startTime != null &&
        DateTime.now().difference(startTime).inMilliseconds >=
            cancelHoldTotalMs) {
      unawaited(cancelSession());
      return;
    }

    if (cancelHoldProgressNotifier.value > 0.0 &&
        cancelHoldProgressNotifier.value < 1.0) {
      cancelHoldProgressNotifier.value = 0.0;
    }
  }

  Future<void> cancelSession() async {
    if (_isCancelling || _status == TimerStatus.idle) return;
    _isCancelling = true;

    try {
      _periodicTicker?.cancel();
      _cancelHoldTimer?.cancel();
      _cancelHoldTimer = null;
      _cancelHoldStartTime = null;
      cancelHoldProgressNotifier.value = 0.0;

      final actualDuration = _targetDurationSeconds - _remainingSeconds;
      final sessionId = _activeSessionId;
      _activeSessionId = null;
      _linkedBacklogTaskId = null;

      if (sessionId != null) {
        final result = await cancelSessionUseCase(
          sessionId: sessionId,
          actualDurationSeconds: actualDuration > 0 ? actualDuration : 0,
        );
        result.fold(
          (failure) => _errorMessage = failure.message,
          (_) {},
        );
      }

      _status = TimerStatus.idle;
      _targetEndTime = null;
      _targetDurationSeconds = _focusDurationSeconds;
      _remainingSeconds = _focusDurationSeconds;
      _remainingDuration = Duration(seconds: _focusDurationSeconds);
      notifyListeners();

      try {
        await notificationService.cancelTimerNotification();
        await notificationService.cancelSessionCompletionNotification();
      } catch (_) {}
    } finally {
      _isCancelling = false;
    }
  }

  Future<void> checkInSession({
    required bool lockedIn,
    bool endAllSessions = false,
  }) async {
    if (_isCheckingIn ||
        (_status != TimerStatus.completed && _status != TimerStatus.running)) {
      return;
    }
    _isCheckingIn = true;
    _periodicTicker?.cancel();

    final sessionId = _activeSessionId;
    final actualDuration = _targetDurationSeconds;
    final outcomeStatus =
        lockedIn ? SessionStatus.lockedIn : SessionStatus.derailed;
    final completeTask = markTaskCompletedUseCase;
    final taskId = _linkedBacklogTaskId;

    _activeSessionId = null;
    if (lockedIn || endAllSessions || _isSingleSessionMode) {
      _linkedBacklogTaskId = null;
    }
    _targetEndTime = null;

    try {
      if (sessionId != null) {
        try {
          final completeResult = await completeSessionUseCase(
            sessionId: sessionId,
            status: outcomeStatus,
            actualDurationSeconds: actualDuration,
          );
          completeResult.fold(
            (failure) => _errorMessage = failure.message,
            (_) {},
          );
        } catch (_) {}

        // Auto-complete linked backlog task only if session was locked in
        if (lockedIn && taskId != null && completeTask != null) {
          try {
            final taskResult = await completeTask(
              id: taskId,
              sessionId: sessionId,
            );
            taskResult.fold(
              (failure) => _errorMessage = failure.message,
              (_) {},
            );
            unawaited(backlogNotifier?.loadPendingTasks(showLoading: false));
          } catch (_) {}
        }

        final syncService = widgetSyncService;
        final summaryUseCase = getDailySummaryUseCase;
        if (syncService != null) {
          try {
            if (summaryUseCase != null) {
              final includeWeekends =
                  prefs?.getBool('insights_include_weekends') ?? false;
              final summaryResult = await summaryUseCase(
                DateTime.now(),
                includeWeekendsInStreak: includeWeekends,
              );
              await summaryResult.fold(
                (_) async {},
                (summary) async {
                  await syncService.updateGlanceableWidget(
                    todayMinutes: summary.totalFocusMinutes,
                    activeStreak: summary.currentStreakDays,
                  );
                },
              );
            } else {
              final sessionMinutes = (actualDuration / 60).round();
              await syncService.updateGlanceableWidget(
                todayMinutes: sessionMinutes,
                activeStreak: lockedIn ? 1 : 0,
              );
            }
          } catch (_) {}
        }
      }

      try {
        await notificationService.cancelTimerNotification();
        await notificationService.cancelSessionCompletionNotification();
      } catch (_) {}
    } finally {
      _isCheckingIn = false;

      if (endAllSessions || _isSingleSessionMode) {
        _status = TimerStatus.idle;
        _targetDurationSeconds = _focusDurationSeconds;
        _remainingSeconds = _focusDurationSeconds;
        _remainingDuration = Duration(seconds: _focusDurationSeconds);
        _targetEndTime = null;
        _currentTaskGoal = '';
        notifyListeners();
      } else {
        // Transition into 5-minute rest mode so UI never stays stuck at 00:00
        _status = TimerStatus.breakRunning;
        _targetDurationSeconds = defaultBreakSeconds;
        _remainingSeconds = defaultBreakSeconds;
        _remainingDuration = const Duration(seconds: defaultBreakSeconds);
        _targetEndTime = DateTime.now().add(_remainingDuration);
        final breakEnd = _targetEndTime;
        if (breakEnd != null) {
          unawaited(
            notificationService.scheduleSessionCompletionNotification(
              targetEndTime: breakEnd,
              goal: '5-Minute Recharge Break',
            ),
          );
        }
        _startTicker();
        notifyListeners();
      }
    }
  }

  void readyToFocusFromBreak() {
    _periodicTicker?.cancel();
    _cancelHoldTimer?.cancel();
    _cancelHoldTimer = null;
    _cancelHoldStartTime = null;
    cancelHoldProgressNotifier.value = 0.0;
    _targetEndTime = null;
    unawaited(
      notificationService.cancelTimerNotification().catchError((Object _) {}),
    );
    unawaited(
      notificationService
          .cancelSessionCompletionNotification()
          .catchError((Object _) {}),
    );
    _status = TimerStatus.idle;
    _targetDurationSeconds = _focusDurationSeconds;
    _remainingSeconds = _focusDurationSeconds;
    _remainingDuration = Duration(seconds: _focusDurationSeconds);
    _activeSessionId = null;
    notifyListeners();
  }

  void endAllSessions() {
    _periodicTicker?.cancel();
    _cancelHoldTimer?.cancel();
    _cancelHoldTimer = null;
    _cancelHoldStartTime = null;
    cancelHoldProgressNotifier.value = 0.0;
    _targetEndTime = null;
    unawaited(
      notificationService.cancelTimerNotification().catchError((Object _) {}),
    );
    unawaited(
      notificationService
          .cancelSessionCompletionNotification()
          .catchError((Object _) {}),
    );
    _status = TimerStatus.idle;
    _targetDurationSeconds = _focusDurationSeconds;
    _remainingSeconds = _focusDurationSeconds;
    _remainingDuration = Duration(seconds: _focusDurationSeconds);
    _activeSessionId = null;
    _currentTaskGoal = '';
    _linkedBacklogTaskId = null;
    notifyListeners();
  }

  void syncWithWallClock() {
    if (_status == TimerStatus.completed) {
      notifyListeners();
      return;
    }
    if (_status != TimerStatus.running && _status != TimerStatus.breakRunning) {
      return;
    }

    final targetEnd = _targetEndTime;
    if (targetEnd == null) return;

    final diff = targetEnd.difference(DateTime.now());
    final isFinished = diff.isNegative || diff.inMilliseconds <= 0;

    if (isFinished) {
      _periodicTicker?.cancel();
      _targetEndTime = null;
      _remainingSeconds = 0;
      _remainingDuration = Duration.zero;

      if (_status == TimerStatus.running) {
        _status = TimerStatus.completed;
        unawaited(
          notificationService
              .cancelTimerNotification()
              .catchError((Object _) {}),
        );
        unawaited(
          notificationService
              .cancelSessionCompletionNotification()
              .catchError((Object _) {}),
        );
        _triggerCompletionFeedback();
      } else if (_status == TimerStatus.breakRunning) {
        _status = TimerStatus.breakCompleted;
        unawaited(
          notificationService
              .cancelTimerNotification()
              .catchError((Object _) {}),
        );
        unawaited(
          notificationService
              .cancelSessionCompletionNotification()
              .catchError((Object _) {}),
        );
        _triggerCompletionFeedback();
      }
      notifyListeners();
    } else {
      final secondsLeft = (diff.inMilliseconds / 1000).ceil();
      if (secondsLeft != _remainingSeconds) {
        _remainingSeconds = secondsLeft;
        _remainingDuration = diff;
        notifyListeners();
      }
    }
  }

  void _triggerCompletionFeedback() {
    try {
      unawaited(HapticFeedback.heavyImpact());
    } catch (_) {}
  }

  void _startTicker() {
    _periodicTicker?.cancel();
    _periodicTicker = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _onTick(),
    );
  }

  void _onTick() {
    final previousSeconds = _remainingSeconds;
    syncWithWallClock();
    if (_status == TimerStatus.running &&
        _remainingSeconds != previousSeconds &&
        _remainingSeconds > 0 &&
        _remainingSeconds % 30 == 0) {
      _updateNotification();
    }
  }

  void _updateNotification() {
    final formattedTime = TimeFormatter.formatMMSS(_remainingSeconds);
    unawaited(
      notificationService.showOngoingTimer(
        taskGoal: _currentTaskGoal,
        formattedTimeRemaining: formattedTime,
        isPaused: _status == TimerStatus.paused,
        targetEndTimeEpochMs: _targetEndTime?.millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _loadRecentGoals() async {
    try {
      final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
      final cached = sharedPrefs.getStringList(recentGoalsKey) ?? const [];
      _recentGoals = List.unmodifiable(cached);
      if (!_hasUserModifiedSingleSessionMode) {
        _isSingleSessionMode =
            sharedPrefs.getBool(singleSessionModeKey) ?? _isSingleSessionMode;
      }
      notifyListeners();
    } on Exception catch (_) {}
  }

  Future<void> _cacheRecentGoal(String goal) async {
    final trimmed = goal.trim();
    if (trimmed.isEmpty || trimmed == 'Deep Work') return;

    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    final updated = [
      trimmed,
      ..._recentGoals.where((g) => g.toLowerCase() != trimmed.toLowerCase()),
    ].take(3).toList();

    _recentGoals = List.unmodifiable(updated);
    await sharedPrefs.setStringList(recentGoalsKey, updated);
  }
}
