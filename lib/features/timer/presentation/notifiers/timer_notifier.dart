import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
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

  final StartSessionUseCase startSessionUseCase;
  final CompleteSessionUseCase completeSessionUseCase;
  final CancelSessionUseCase cancelSessionUseCase;
  final NotificationService notificationService;
  final MarkTaskCompletedUseCase? markTaskCompletedUseCase;
  final SharedPreferences? prefs;

  TimerNotifier({
    required this.startSessionUseCase,
    required this.completeSessionUseCase,
    required this.cancelSessionUseCase,
    required this.notificationService,
    this.markTaskCompletedUseCase,
    this.prefs,
  }) {
    unawaited(_loadRecentGoals());
  }

  TimerStatus _status = TimerStatus.idle;
  int _targetDurationSeconds = defaultFocusSeconds;
  int _remainingSeconds = defaultFocusSeconds;
  Duration _remainingDuration = const Duration(seconds: defaultFocusSeconds);
  DateTime? _targetEndTime;
  String _currentTaskGoal = '';
  int? _linkedBacklogTaskId;
  int? _activeSessionId;
  double _cancelHoldProgress = 0.0;
  List<String> _recentGoals = const [];
  String? _errorMessage;

  Timer? _periodicTicker;
  Timer? _cancelHoldTimer;
  DateTime? _cancelHoldStartTime;
  bool _isStarting = false;
  bool _isCancelling = false;
  bool _isDisposed = false;

  TimerStatus get status => _status;
  int get targetDurationSeconds => _targetDurationSeconds;
  int get remainingSeconds => _remainingSeconds;
  String get currentTaskGoal => _currentTaskGoal;
  int? get linkedBacklogTaskId => _linkedBacklogTaskId;
  List<String> get recentGoals => _recentGoals;
  double get cancelHoldProgress => _cancelHoldProgress;
  int? get activeSessionId => _activeSessionId;
  String? get errorMessage => _errorMessage;

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
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void setDurationPreset(int seconds) {
    if (_status != TimerStatus.idle) return;
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

  Future<bool> startFocusSession(String goal, {int? backlogTaskId}) async {
    if (_status != TimerStatus.idle || _isStarting) return false;
    _isStarting = true;

    try {
      final trimmed = goal.trim();
      _currentTaskGoal = trimmed.isNotEmpty ? trimmed : 'Deep Work';
      _linkedBacklogTaskId = backlogTaskId;
      _remainingSeconds = _targetDurationSeconds;
      _remainingDuration = Duration(seconds: _remainingSeconds);
      _targetEndTime = DateTime.now().add(_remainingDuration);
      _cancelHoldProgress = 0.0;
      _errorMessage = null;

      await _cacheRecentGoal(_currentTaskGoal);

      final result = await startSessionUseCase(
        taskGoal: _currentTaskGoal,
        sessionType: SessionType.focus,
        targetDurationSeconds: _targetDurationSeconds,
      );

      final isSuccess = result.fold(
        (failure) {
          _errorMessage = failure.message;
          _status = TimerStatus.idle;
          notifyListeners();
          return false;
        },
        (sessionId) {
          _activeSessionId = sessionId;
          _status = TimerStatus.running;
          _startTicker();
          _updateNotification();
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

    _periodicTicker?.cancel();
    final targetEnd = _targetEndTime;
    if (targetEnd != null) {
      _remainingDuration = targetEnd.difference(DateTime.now());
      if (_remainingDuration.isNegative) _remainingDuration = Duration.zero;
    }
    _remainingSeconds = (_remainingDuration.inMilliseconds / 1000).ceil();
    _status = TimerStatus.paused;
    _updateNotification();
    notifyListeners();
  }

  void resume() {
    if (_status != TimerStatus.paused) return;

    _targetEndTime = DateTime.now().add(_remainingDuration);
    _status = TimerStatus.running;
    _cancelHoldProgress = 0.0;
    _startTicker();
    _updateNotification();
    notifyListeners();
  }

  void startHoldToCancel() {
    if (_status != TimerStatus.paused) return;

    _cancelHoldStartTime = DateTime.now();
    _cancelHoldProgress = 0.0;
    _cancelHoldTimer?.cancel();

    _cancelHoldTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        final startTime = _cancelHoldStartTime;
        if (startTime == null) {
          timer.cancel();
          return;
        }

        final elapsedMs =
            DateTime.now().difference(startTime).inMilliseconds;
        final progress = (elapsedMs / cancelHoldTotalMs).clamp(0.0, 1.0);
        _cancelHoldProgress = progress;
        notifyListeners();

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
        DateTime.now().difference(startTime).inMilliseconds >= cancelHoldTotalMs) {
      unawaited(cancelSession());
      return;
    }

    if (_cancelHoldProgress > 0.0 && _cancelHoldProgress < 1.0) {
      _cancelHoldProgress = 0.0;
      notifyListeners();
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
      _cancelHoldProgress = 0.0;

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

      await notificationService.cancelTimerNotification();
      _status = TimerStatus.idle;
      _remainingSeconds = _targetDurationSeconds;
      _remainingDuration = Duration(seconds: _targetDurationSeconds);
      notifyListeners();
    } finally {
      _isCancelling = false;
    }
  }

  Future<void> checkInSession({required bool lockedIn}) async {
    if (_status != TimerStatus.completed && _status != TimerStatus.running) return;
    final sessionId = _activeSessionId;
    final actualDuration = _targetDurationSeconds;
    final outcomeStatus =
        lockedIn ? SessionStatus.lockedIn : SessionStatus.derailed;
    final completeTask = markTaskCompletedUseCase;
    final taskId = _linkedBacklogTaskId;

    _activeSessionId = null;
    _linkedBacklogTaskId = null;

    if (sessionId != null) {
      final completeResult = await completeSessionUseCase(
        sessionId: sessionId,
        status: outcomeStatus,
        actualDurationSeconds: actualDuration,
      );
      completeResult.fold(
        (failure) => _errorMessage = failure.message,
        (_) {},
      );

      // Auto-complete linked backlog task if one was promoted to this session
      if (taskId != null && completeTask != null) {
        final taskResult = await completeTask(
          id: taskId,
          sessionId: sessionId,
        );
        taskResult.fold(
          (failure) => _errorMessage = failure.message,
          (_) {},
        );
      }
    }

    await notificationService.cancelTimerNotification();

    // Transition into 5-minute rest mode
    _status = TimerStatus.breakRunning;
    _targetDurationSeconds = defaultBreakSeconds;
    _remainingSeconds = defaultBreakSeconds;
    _remainingDuration = const Duration(seconds: defaultBreakSeconds);
    _targetEndTime = DateTime.now().add(_remainingDuration);
    _startTicker();
    notifyListeners();
  }

  void readyToFocusFromBreak() {
    _periodicTicker?.cancel();
    _status = TimerStatus.idle;
    _targetDurationSeconds = defaultFocusSeconds;
    _remainingSeconds = defaultFocusSeconds;
    _remainingDuration = const Duration(seconds: defaultFocusSeconds);
    _activeSessionId = null;
    _currentTaskGoal = '';
    _linkedBacklogTaskId = null;
    notifyListeners();
  }

  void _startTicker() {
    _periodicTicker?.cancel();
    _periodicTicker = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _onTick(),
    );
  }

  void _onTick() {
    final targetEnd = _targetEndTime;
    if (targetEnd == null) return;

    final diff = targetEnd.difference(DateTime.now());
    final isFinished = diff.isNegative || diff.inMilliseconds <= 0;
    final secondsLeft = isFinished ? 0 : (diff.inMilliseconds / 1000).ceil();

    if (secondsLeft != _remainingSeconds) {
      _remainingSeconds = secondsLeft;
      notifyListeners();
    }

    if (isFinished) {
      _periodicTicker?.cancel();
      _remainingSeconds = 0;
      _remainingDuration = Duration.zero;
      if (_status == TimerStatus.running) {
        _status = TimerStatus.completed;
        unawaited(notificationService.cancelTimerNotification());
      } else if (_status == TimerStatus.breakRunning) {
        _status = TimerStatus.breakCompleted;
        unawaited(notificationService.cancelTimerNotification());
      }
      notifyListeners();
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
    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    final cached = sharedPrefs.getStringList(recentGoalsKey) ?? const [];
    _recentGoals = List.unmodifiable(cached);
    notifyListeners();
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
