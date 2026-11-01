import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_daily_summary_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/entities/active_session_tombstone_entity.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/recover_active_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/utils/target_allocation_balancer.dart';
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
  static const String sessionTombstoneKey = 'active_session_tombstone_v1';

  final StartSessionUseCase startSessionUseCase;
  final CompleteSessionUseCase completeSessionUseCase;
  final CancelSessionUseCase cancelSessionUseCase;
  final NotificationService notificationService;
  final MarkTaskCompletedUseCase? markTaskCompletedUseCase;
  final RecoverActiveSessionUseCase? recoverActiveSessionUseCase;
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
    this.recoverActiveSessionUseCase,
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
    var modified = false;
    if (_linkedBacklogTaskId == taskId) {
      _linkedBacklogTaskId = null;
      modified = true;
    }
    if (_linkedBacklogTaskIds.contains(taskId)) {
      _linkedBacklogTaskIds =
          _linkedBacklogTaskIds.where((id) => id != taskId).toList();
      modified = true;
    }
    if (modified) {
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
  List<SessionTargetAllocation> _currentTargets = const [];
  int? _linkedBacklogTaskId;
  List<int> _linkedBacklogTaskIds = const [];
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
  int get focusDurationMinutes => (_focusDurationSeconds / 60).round();
  int get targetDurationSeconds => _targetDurationSeconds;
  int get remainingSeconds => _remainingSeconds;
  String get currentTaskGoal => _currentTaskGoal;
  List<SessionTargetAllocation> get currentTargets => _currentTargets;
  int? get linkedBacklogTaskId => _linkedBacklogTaskId;
  List<int> get linkedBacklogTaskIds => _linkedBacklogTaskIds;
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
    if (goal.trim().isNotEmpty) {
      _currentTargets = [
        SessionTargetAllocation(
          targetName: goal.trim(),
          percentage: 100,
          backlogTaskId: backlogTaskId,
        ),
      ];
      _linkedBacklogTaskIds =
          backlogTaskId != null ? [backlogTaskId] : const [];
    } else {
      _currentTargets = const [];
      _linkedBacklogTaskIds = const [];
    }
    notifyListeners();
  }

  void setTargets(
    List<SessionTargetAllocation> targets, {
    List<int>? backlogTaskIds,
  }) {
    _currentTargets = List.unmodifiable(targets);
    if (backlogTaskIds != null) {
      _linkedBacklogTaskIds = List.unmodifiable(backlogTaskIds);
      _linkedBacklogTaskId =
          backlogTaskIds.isNotEmpty ? backlogTaskIds.first : null;
    } else {
      final taskIds = targets
          .map((t) => t.backlogTaskId)
          .whereType<int>()
          .toList();
      _linkedBacklogTaskIds = List.unmodifiable(taskIds);
      _linkedBacklogTaskId = taskIds.isNotEmpty ? taskIds.first : null;
    }
    _currentTaskGoal = TargetAllocationBalancer.formatGoalSummary(targets);
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

  Future<bool> startFocusSessionWithTargets(
    List<SessionTargetAllocation> targets, {
    List<int>? backlogTaskIds,
  }) async {
    final summary = TargetAllocationBalancer.formatGoalSummary(targets);
    return startFocusSession(
      summary,
      backlogTaskId: backlogTaskIds?.isNotEmpty == true
          ? backlogTaskIds!.first
          : (targets.isNotEmpty ? targets.first.backlogTaskId : null),
      targets: targets,
      backlogTaskIds: backlogTaskIds,
    );
  }

  Future<bool> startFocusSession(
    String goal, {
    int? backlogTaskId,
    List<SessionTargetAllocation>? targets,
    List<int>? backlogTaskIds,
  }) async {
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

      final effectiveTargets = (targets != null && targets.isNotEmpty)
          ? targets
          : (_currentTargets.isNotEmpty &&
                  (trimmed.isEmpty || trimmed == _currentTaskGoal.trim())
              ? _currentTargets
              : [
                  SessionTargetAllocation(
                    targetName: effectiveGoal,
                    percentage: 100,
                    backlogTaskId: backlogTaskId,
                  ),
                ]);

      final result = await startSessionUseCase(
        taskGoal: effectiveGoal,
        sessionType: SessionType.focus,
        targetDurationSeconds: _focusDurationSeconds,
        targets: effectiveTargets,
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
          _currentTargets = List.unmodifiable(effectiveTargets);

          final taskIdsSet = <int>{
            if (backlogTaskId != null) backlogTaskId,
            if (backlogTaskIds != null) ...backlogTaskIds,
            ...effectiveTargets.map((t) => t.backlogTaskId).whereType<int>(),
          };
          _linkedBacklogTaskIds = List.unmodifiable(taskIdsSet.toList());
          _linkedBacklogTaskId =
              taskIdsSet.isNotEmpty ? taskIdsSet.first : null;

          _targetDurationSeconds = _focusDurationSeconds;
          _remainingSeconds = _targetDurationSeconds;
          _remainingDuration = Duration(seconds: _remainingSeconds);
          _targetEndTime = DateTime.now().add(_remainingDuration);
          cancelHoldProgressNotifier.value = 0.0;
          _errorMessage = null;

          for (final target in effectiveTargets) {
            if (target.targetName.trim().isNotEmpty) {
              await _cacheRecentGoal(target.targetName.trim());
            }
          }

          _activeSessionId = sessionId;
          _status = TimerStatus.running;
          await _persistTombstone();
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
            final syncService = widgetSyncService;
            if (syncService != null) {
              unawaited(
                syncService.updateGlanceableWidget(
                  isRunning: true,
                  targetEndTimeEpochMs: targetEnd.millisecondsSinceEpoch,
                  taskGoal: _currentTaskGoal,
                ),
              );
            }
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
    unawaited(_persistTombstone());
    _updateNotification();
    unawaited(notificationService.cancelSessionCompletionNotification());
    final syncService = widgetSyncService;
    if (syncService != null) {
      unawaited(
        syncService.updateGlanceableWidget(
          isRunning: false,
          targetEndTimeEpochMs: 0,
          taskGoal: '',
        ),
      );
    }
    notifyListeners();
  }

  void resume() {
    if (_status != TimerStatus.paused) return;

    _targetEndTime = DateTime.now().add(_remainingDuration);
    _status = TimerStatus.running;
    cancelHoldProgressNotifier.value = 0.0;
    unawaited(_persistTombstone());
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
      final syncService = widgetSyncService;
      if (syncService != null) {
        unawaited(
          syncService.updateGlanceableWidget(
            isRunning: true,
            targetEndTimeEpochMs: targetEnd.millisecondsSinceEpoch,
            taskGoal: _currentTaskGoal,
          ),
        );
      }
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
      _currentTaskGoal = '';
      _currentTargets = const [];
      _linkedBacklogTaskId = null;
      _linkedBacklogTaskIds = const [];
      await _clearTombstone();
      notifyListeners();

      final syncService = widgetSyncService;
      if (syncService != null) {
        unawaited(
          syncService.updateGlanceableWidget(
            isRunning: false,
            targetEndTimeEpochMs: 0,
            taskGoal: '',
          ),
        );
      }

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
      _linkedBacklogTaskIds = const [];
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

        // Batch auto-complete all linked backlog tasks only if session was locked in
        if (lockedIn && completeTask != null) {
          final taskIds = <int>{
            if (taskId != null) taskId,
            ..._linkedBacklogTaskIds,
            ..._currentTargets.map((t) => t.backlogTaskId).whereType<int>(),
          }.toList();

          for (final id in taskIds) {
            try {
              final taskResult = await completeTask(
                id: id,
                sessionId: sessionId,
              );
              taskResult.fold(
                (failure) => _errorMessage = failure.message,
                (_) {},
              );
            } catch (_) {}
          }
          if (taskIds.isNotEmpty) {
            unawaited(backlogNotifier?.loadPendingTasks(showLoading: false));
          }
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
                    isRunning: false,
                    targetEndTimeEpochMs: 0,
                    taskGoal: '',
                  );
                },
              );
            } else {
              final sessionMinutes = (actualDuration / 60).round();
              await syncService.updateGlanceableWidget(
                todayMinutes: sessionMinutes,
                activeStreak: lockedIn ? 1 : 0,
                isRunning: false,
                targetEndTimeEpochMs: 0,
                taskGoal: '',
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
        _currentTargets = const [];
        _linkedBacklogTaskId = null;
        _linkedBacklogTaskIds = const [];
        await _clearTombstone();
        notifyListeners();
      } else {
        // Transition into 5-minute rest mode so UI never stays stuck at 00:00
        _status = TimerStatus.breakRunning;
        _targetDurationSeconds = defaultBreakSeconds;
        _remainingSeconds = defaultBreakSeconds;
        _remainingDuration = const Duration(seconds: defaultBreakSeconds);
        _targetEndTime = DateTime.now().add(_remainingDuration);
        await _persistTombstone();
        final breakEnd = _targetEndTime;
        if (breakEnd != null) {
          unawaited(
            notificationService.scheduleSessionCompletionNotification(
              targetEndTime: breakEnd,
              goal: _currentTaskGoal,
              isBreak: true,
            ),
          );
        }
        _updateBreakNotification();
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
    final sessionId = _activeSessionId;
    if (sessionId != null &&
        (_status == TimerStatus.running || _status == TimerStatus.paused)) {
      final elapsed = (_targetDurationSeconds - _remainingSeconds)
          .clamp(0, _targetDurationSeconds);
      unawaited(
        cancelSessionUseCase(
          sessionId: sessionId,
          actualDurationSeconds: elapsed,
        ).then((_) {}, onError: (_) {}),
      );
    }
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
    unawaited(_clearTombstone());
    notifyListeners();
  }

  Future<bool> startNextFocusFromBreak([String? overrideGoal]) async {
    final effectiveCandidate = overrideGoal?.trim() ?? _currentTaskGoal.trim();
    final goal =
        effectiveCandidate.isNotEmpty ? effectiveCandidate : 'Deep Work';
    final linkedTaskId = _linkedBacklogTaskId;
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
    final preserveTargets =
        overrideGoal == null || overrideGoal.trim() == _currentTaskGoal.trim();
    final targetsToPass = preserveTargets ? _currentTargets : null;
    final backlogIdsToPass =
        preserveTargets && _linkedBacklogTaskIds.isNotEmpty
            ? _linkedBacklogTaskIds
            : null;
    return startFocusSession(
      goal,
      backlogTaskId: linkedTaskId,
      targets: targetsToPass,
      backlogTaskIds: backlogIdsToPass,
    );
  }

  void endAllSessions() {
    _periodicTicker?.cancel();
    _cancelHoldTimer?.cancel();
    _cancelHoldTimer = null;
    _cancelHoldStartTime = null;
    cancelHoldProgressNotifier.value = 0.0;
    _targetEndTime = null;
    final sessionId = _activeSessionId;
    if (sessionId != null &&
        (_status == TimerStatus.running || _status == TimerStatus.paused)) {
      final elapsed = (_targetDurationSeconds - _remainingSeconds)
          .clamp(0, _targetDurationSeconds);
      unawaited(
        cancelSessionUseCase(
          sessionId: sessionId,
          actualDurationSeconds: elapsed,
        ).then((_) {}, onError: (_) {}),
      );
    }
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
    _currentTargets = const [];
    _linkedBacklogTaskId = null;
    _linkedBacklogTaskIds = const [];
    unawaited(_clearTombstone());
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
        unawaited(_persistTombstone());
        final sessionId = _activeSessionId;
        if (sessionId != null) {
          unawaited(
            completeSessionUseCase(
              sessionId: sessionId,
              status: SessionStatus.lockedIn,
              actualDurationSeconds: _targetDurationSeconds,
            ).then((_) {}, onError: (_) {}),
          );
        }
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
        unawaited(_persistTombstone());
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

  /// Recovers an active or interrupted session from a persisted crash tombstone
  /// in [SharedPreferences] or an unfinalized session in SQLite via [recoverActiveSessionUseCase].
  Future<bool> recoverActiveSession({DateTime? now}) async {
    if (_status != TimerStatus.idle) return true;
    final effectiveNow = now ?? DateTime.now();

    try {
      final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
      final rawTombstone = sharedPrefs.getString(sessionTombstoneKey);
      final tombstone = ActiveSessionTombstoneEntity.tryFromJson(rawTombstone);
      if (tombstone != null) {
        return await _applyTombstoneRecovery(
          tombstone,
          now: effectiveNow,
          notify: true,
        );
      }
    } on Exception catch (_) {}

    final recoverUseCase = recoverActiveSessionUseCase;
    if (recoverUseCase == null) return false;

    try {
      final result = await recoverUseCase(now: effectiveNow);
      final session = result.fold<SessionEntity?>(
        (_) => null,
        (recovered) => recovered,
      );
      if (session == null || _status != TimerStatus.idle) return false;
      final fallbackTombstone = ActiveSessionTombstoneEntity(
        sessionId: session.id,
        status: TombstoneSessionStatus.running,
        taskGoal: session.taskGoal,
        focusDurationSeconds: session.targetDurationSeconds,
        targetDurationSeconds: session.targetDurationSeconds,
        remainingSeconds: session.targetDurationSeconds,
        targetEndTimeEpochMs: session.endTimeEpochMs,
        savedAtEpochMs: session.startTimeEpochMs,
      );
      return await _applyTombstoneRecovery(
        fallbackTombstone,
        now: effectiveNow,
        notify: true,
      );
    } on Exception catch (_) {
      return false;
    }
  }

  Future<bool> _applyTombstoneRecovery(
    ActiveSessionTombstoneEntity tombstone, {
    required DateTime now,
    required bool notify,
  }) async {
    final nowMs = now.millisecondsSinceEpoch;
    switch (tombstone.status) {
      case TombstoneSessionStatus.running:
        _activeSessionId = tombstone.sessionId;
        _currentTaskGoal = tombstone.taskGoal;
        _linkedBacklogTaskId = tombstone.linkedBacklogTaskId;
        _focusDurationSeconds = tombstone.focusDurationSeconds;
        _targetDurationSeconds = tombstone.targetDurationSeconds;

        final targetEndMs = tombstone.targetEndTimeEpochMs;
        if (targetEndMs != null && targetEndMs > nowMs) {
          final targetEnd = DateTime.fromMillisecondsSinceEpoch(targetEndMs);
          final diff = targetEnd.difference(now);
          _targetEndTime = targetEnd;
          _remainingDuration = diff;
          _remainingSeconds = (diff.inMilliseconds / 1000).ceil();
          _status = TimerStatus.running;
          _startTicker();
          _updateNotification();
          unawaited(
            notificationService.scheduleSessionCompletionNotification(
              targetEndTime: targetEnd,
              goal: _currentTaskGoal,
            ),
          );
          final syncService = widgetSyncService;
          if (syncService != null) {
            unawaited(
              syncService.updateGlanceableWidget(
                isRunning: true,
                targetEndTimeEpochMs: targetEndMs,
                taskGoal: _currentTaskGoal,
              ),
            );
          }
          await _persistTombstone();
        } else {
          _targetEndTime = null;
          _remainingDuration = Duration.zero;
          _remainingSeconds = 0;
          _status = TimerStatus.completed;
          final sessionId = _activeSessionId;
          if (sessionId != null) {
            try {
              await completeSessionUseCase(
                sessionId: sessionId,
                status: SessionStatus.lockedIn,
                actualDurationSeconds: _targetDurationSeconds,
              );
            } on Exception catch (_) {}
          }
          await _persistTombstone();
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
        }
        if (notify) notifyListeners();
        return true;

      case TombstoneSessionStatus.paused:
        _activeSessionId = tombstone.sessionId;
        _currentTaskGoal = tombstone.taskGoal;
        _linkedBacklogTaskId = tombstone.linkedBacklogTaskId;
        _focusDurationSeconds = tombstone.focusDurationSeconds;
        _targetDurationSeconds = tombstone.targetDurationSeconds;
        _remainingSeconds =
            tombstone.remainingSeconds.clamp(1, tombstone.targetDurationSeconds);
        _remainingDuration = Duration(seconds: _remainingSeconds);
        _targetEndTime = null;
        _status = TimerStatus.paused;
        _updateNotification();
        if (notify) notifyListeners();
        return true;

      case TombstoneSessionStatus.completed:
        _activeSessionId = tombstone.sessionId;
        _currentTaskGoal = tombstone.taskGoal;
        _linkedBacklogTaskId = tombstone.linkedBacklogTaskId;
        _focusDurationSeconds = tombstone.focusDurationSeconds;
        _targetDurationSeconds = tombstone.targetDurationSeconds;
        _remainingSeconds = 0;
        _remainingDuration = Duration.zero;
        _targetEndTime = null;
        _status = TimerStatus.completed;
        if (notify) notifyListeners();
        return true;

      case TombstoneSessionStatus.breakRunning:
        _activeSessionId = null;
        _currentTaskGoal = tombstone.taskGoal;
        _linkedBacklogTaskId = tombstone.linkedBacklogTaskId;
        _focusDurationSeconds = tombstone.focusDurationSeconds;
        _targetDurationSeconds = tombstone.targetDurationSeconds;

        final targetEndMs = tombstone.targetEndTimeEpochMs;
        if (targetEndMs != null && targetEndMs > nowMs) {
          final targetEnd = DateTime.fromMillisecondsSinceEpoch(targetEndMs);
          final diff = targetEnd.difference(now);
          _targetEndTime = targetEnd;
          _remainingDuration = diff;
          _remainingSeconds = (diff.inMilliseconds / 1000).ceil();
          _status = TimerStatus.breakRunning;
          _startTicker();
          _updateBreakNotification();
        } else {
          _targetEndTime = null;
          _remainingDuration = Duration.zero;
          _remainingSeconds = 0;
          _status = TimerStatus.breakCompleted;
          await _persistTombstone();
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
        }
        if (notify) notifyListeners();
        return true;

      case TombstoneSessionStatus.breakCompleted:
        _activeSessionId = null;
        _currentTaskGoal = tombstone.taskGoal;
        _linkedBacklogTaskId = tombstone.linkedBacklogTaskId;
        _focusDurationSeconds = tombstone.focusDurationSeconds;
        _targetDurationSeconds = tombstone.targetDurationSeconds;
        _remainingSeconds = 0;
        _remainingDuration = Duration.zero;
        _targetEndTime = null;
        _status = TimerStatus.breakCompleted;
        if (notify) notifyListeners();
        return true;
    }
  }

  TombstoneSessionStatus? _toTombstoneStatus(TimerStatus status) {
    switch (status) {
      case TimerStatus.idle:
        return null;
      case TimerStatus.running:
        return TombstoneSessionStatus.running;
      case TimerStatus.paused:
        return TombstoneSessionStatus.paused;
      case TimerStatus.completed:
        return TombstoneSessionStatus.completed;
      case TimerStatus.breakRunning:
        return TombstoneSessionStatus.breakRunning;
      case TimerStatus.breakCompleted:
        return TombstoneSessionStatus.breakCompleted;
    }
  }

  Future<void> _persistTombstone() async {
    final sharedPrefs = prefs;
    if (sharedPrefs == null) return;
    final tombstoneStatus = _toTombstoneStatus(_status);
    if (tombstoneStatus == null) {
      await _clearTombstone();
      return;
    }
    try {
      final tombstone = ActiveSessionTombstoneEntity(
        sessionId: _activeSessionId,
        status: tombstoneStatus,
        taskGoal: _currentTaskGoal.isNotEmpty ? _currentTaskGoal : 'Deep Work',
        linkedBacklogTaskId: _linkedBacklogTaskId,
        focusDurationSeconds: _focusDurationSeconds,
        targetDurationSeconds: _targetDurationSeconds,
        remainingSeconds: _remainingSeconds,
        targetEndTimeEpochMs: _targetEndTime?.millisecondsSinceEpoch,
        savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );
      await sharedPrefs.setString(sessionTombstoneKey, tombstone.toJson());
    } on Exception catch (_) {}
  }

  Future<void> _clearTombstone() async {
    final sharedPrefs = prefs;
    if (sharedPrefs == null) return;
    try {
      await sharedPrefs.remove(sessionTombstoneKey);
    } on Exception catch (_) {}
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
    syncWithWallClock();
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

  void _updateBreakNotification() {
    final formattedTime = TimeFormatter.formatMMSS(_remainingSeconds);
    unawaited(
      notificationService.showOngoingTimer(
        taskGoal: 'Feeds remain locked · Recharge stamina',
        formattedTimeRemaining: formattedTime,
        isPaused: false,
        targetEndTimeEpochMs: _targetEndTime?.millisecondsSinceEpoch,
        isBreak: true,
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
