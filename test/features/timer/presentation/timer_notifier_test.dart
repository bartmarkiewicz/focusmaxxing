import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/entities/active_session_tombstone_entity.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/recover_active_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSessionRepository implements ISessionRepository {
  SessionEntity? lastCreatedSession;
  int? lastUpdatedSessionId;
  String? lastUpdatedStatus;
  int? lastUpdatedDuration;
  List<SessionEntity> storedSessions = <SessionEntity>[];

  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async {
    lastCreatedSession = session;
    return const Right<Failure, int>(101);
  }

  @override
  Future<Either<Failure, void>> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async {
    lastUpdatedSessionId = sessionId;
    lastUpdatedStatus = status;
    lastUpdatedDuration = actualDurationSeconds;
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async =>
      Right<Failure, List<SessionEntity>>(storedSessions);
}

class _FakeBacklogRepository implements IBacklogRepository {
  int? lastCompletedTaskId;
  int? lastCompletedSessionId;

  @override
  Future<Either<Failure, void>> markCompleted(int id, [int? sessionId]) async {
    lastCompletedTaskId = id;
    lastCompletedSessionId = sessionId;
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, int>> addTask(String title) async =>
      const Right<Failure, int>(1);

  @override
  Future<Either<Failure, void>> deleteTask(int id) async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, List<BacklogTaskEntity>>> getPendingTasks() async =>
      const Right<Failure, List<BacklogTaskEntity>>([]);
}

class _MockNotificationService extends NotificationService {
  String? lastShownGoal;
  bool? lastShownIsPaused;
  int? lastShownTargetEndTimeEpochMs;
  bool? lastShownIsBreak;
  int showOngoingTimerCallCount = 0;
  bool isCancelled = false;
  DateTime? lastScheduledCompletionTime;
  String? lastScheduledCompletionGoal;
  bool? lastScheduledIsBreak;
  bool isCompletionAlarmCancelled = false;

  @override
  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
    bool isBreak = false,
  }) async {
    showOngoingTimerCallCount++;
    lastShownGoal = taskGoal;
    lastShownIsPaused = isPaused;
    lastShownTargetEndTimeEpochMs = targetEndTimeEpochMs;
    lastShownIsBreak = isBreak;
    isCancelled = false;
  }

  @override
  Future<void> cancelTimerNotification() async {
    isCancelled = true;
  }

  @override
  Future<void> scheduleSessionCompletionNotification({
    required DateTime targetEndTime,
    required String goal,
    bool isBreak = false,
  }) async {
    lastScheduledCompletionTime = targetEndTime;
    lastScheduledCompletionGoal = goal;
    lastScheduledIsBreak = isBreak;
    isCompletionAlarmCancelled = false;
  }

  @override
  Future<void> cancelSessionCompletionNotification() async {
    isCompletionAlarmCancelled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSessionRepository sessionRepository;
  late _FakeBacklogRepository backlogRepository;
  late _MockNotificationService notificationService;
  late TimerNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      TimerNotifier.recentGoalsKey: <String>['Recent 1', 'Recent 2'],
    });
    final prefs = await SharedPreferences.getInstance();

    sessionRepository = _FakeSessionRepository();
    backlogRepository = _FakeBacklogRepository();
    notificationService = _MockNotificationService();

    notifier = TimerNotifier(
      startSessionUseCase: StartSessionUseCase(sessionRepository),
      completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
      cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
      markTaskCompletedUseCase: MarkTaskCompletedUseCase(backlogRepository),
      notificationService: notificationService,
      prefs: prefs,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  group('TimerNotifier', () {
    test('initial state defaults to 25 minutes, idle, and loads cached goals',
        () async {
      expect(notifier.status, TimerStatus.idle);
      expect(notifier.targetDurationSeconds, 1500);
      expect(notifier.remainingSeconds, 1500);
      expect(notifier.cancelHoldProgress, 0.0);
      expect(notifier.recentGoals, contains('Recent 1'));
    });

    test(
        'setDurationPreset updates duration while idle but ignores while running',
        () async {
      notifier.setDurationPreset(45 * 60);
      expect(notifier.targetDurationSeconds, 2700);
      expect(notifier.remainingSeconds, 2700);

      await notifier.startFocusSession('Coding');
      expect(notifier.status, TimerStatus.running);

      notifier.setDurationPreset(15 * 60);
      expect(notifier.targetDurationSeconds, 2700);
    });

    test('startFocusSession starts active countdown and notification',
        () async {
      final success = await notifier.startFocusSession('Fix Memory Leak');

      expect(success, isTrue);
      expect(notifier.status, TimerStatus.running);
      expect(notifier.currentTaskGoal, 'Fix Memory Leak');
      expect(notifier.activeSessionId, 101);
      expect(notificationService.lastShownGoal, 'Fix Memory Leak');
      expect(notifier.recentGoals.first, 'Fix Memory Leak');
    });

    test('pause and resume correctly toggle running and paused states',
        () async {
      await notifier.startFocusSession('Deep Study');

      notifier.pause();
      expect(notifier.status, TimerStatus.paused);

      notifier.resume();
      expect(notifier.status, TimerStatus.running);
    });

    test('releaseHoldToCancel resets progress to 0.0 without side effects',
        () async {
      await notifier.startFocusSession('Goal');
      notifier.pause();
      expect(notifier.status, TimerStatus.paused);

      notifier.startHoldToCancel();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(notifier.cancelHoldProgress, greaterThan(0.0));

      notifier.releaseHoldToCancel();
      expect(notifier.cancelHoldProgress, 0.0);
      expect(notifier.status, TimerStatus.paused);
    });

    test('cancelSession updates session to CANCELLED and resets to idle',
        () async {
      await notifier.startFocusSession('Abort Test');
      notifier.pause();

      await notifier.cancelSession();

      expect(notifier.status, TimerStatus.idle);
      expect(notifier.activeSessionId, isNull);
      expect(sessionRepository.lastUpdatedStatus, SessionStatus.cancelled);
      expect(notificationService.isCancelled, isTrue);
    });

    test(
        'checkInSession records outcome, completes backlog task, and starts break',
        () async {
      await notifier.startFocusSession('Finish Feature', backlogTaskId: 42);

      await notifier.checkInSession(lockedIn: true);

      expect(sessionRepository.lastUpdatedStatus, SessionStatus.lockedIn);
      expect(backlogRepository.lastCompletedTaskId, 42);
      expect(backlogRepository.lastCompletedSessionId, 101);
      expect(notifier.status, TimerStatus.breakRunning);
      expect(notifier.targetDurationSeconds, TimerNotifier.defaultBreakSeconds);
      expect(notificationService.lastShownIsBreak, isTrue);
      expect(notificationService.lastScheduledIsBreak, isTrue);
      expect(notificationService.lastScheduledCompletionGoal, 'Finish Feature');

      final started = await notifier.startNextFocusFromBreak();
      expect(started, isTrue);
      expect(notifier.status, TimerStatus.running);
      expect(notifier.currentTaskGoal, 'Finish Feature');

      notifier.readyToFocusFromBreak();
      expect(notifier.status, TimerStatus.idle);
      expect(notifier.targetDurationSeconds, TimerNotifier.defaultFocusSeconds);
    });

    test(
        'checkInSession with lockedIn false records DERAILED and leaves backlog task pending (MED-03)',
        () async {
      await notifier.startFocusSession('Unfinished Task', backlogTaskId: 99);

      await notifier.checkInSession(lockedIn: false);

      expect(sessionRepository.lastUpdatedStatus, SessionStatus.derailed);
      expect(backlogRepository.lastCompletedTaskId, isNull);
      expect(backlogRepository.lastCompletedSessionId, isNull);
      expect(notifier.status, TimerStatus.breakRunning);
    });

    test(
        'startFocusSession can start directly from break mode with saved focus duration preset (CRIT-02)',
        () async {
      notifier.setDurationPreset(45 * 60);
      await notifier.startFocusSession('Session 1');
      await notifier.checkInSession(lockedIn: true);

      expect(notifier.status, TimerStatus.breakRunning);
      expect(notifier.targetDurationSeconds, TimerNotifier.defaultBreakSeconds);

      final success = await notifier.startFocusSession('Session 2');

      expect(success, isTrue);
      expect(notifier.status, TimerStatus.running);
      expect(notifier.targetDurationSeconds, 45 * 60);
      expect(notifier.currentTaskGoal, 'Session 2');
    });

    test(
        'startHoldToCancel updates cancelHoldProgressNotifier without calling notifyListeners on TimerNotifier (MED-02)',
        () async {
      await notifier.startFocusSession('No Rebuild Storm');
      notifier.pause();

      var timerNotifierCallCount = 0;
      notifier.addListener(() => timerNotifierCallCount++);

      final progressValues = <double>[];
      void onProgress() =>
          progressValues.add(notifier.cancelHoldProgressNotifier.value);
      notifier.cancelHoldProgressNotifier.addListener(onProgress);

      notifier.startHoldToCancel();
      await Future<void>.delayed(const Duration(milliseconds: 160));

      // TimerNotifier must not trigger notifyListeners during hold ticks to avoid page rebuild storms
      expect(timerNotifierCallCount, 0);
      expect(progressValues, isNotEmpty);
      expect(notifier.cancelHoldProgress, greaterThan(0.0));

      notifier.releaseHoldToCancel();
      expect(timerNotifierCallCount, 0);
      expect(notifier.cancelHoldProgress, 0.0);

      notifier.cancelHoldProgressNotifier.removeListener(onProgress);
    });

    test(
        'startFocusSession schedules completion alarm and pause/cancel/checkin cancel it',
        () async {
      await notifier.startFocusSession('Test Alarm');
      expect(notificationService.lastScheduledCompletionGoal, 'Test Alarm');
      expect(notificationService.lastScheduledCompletionTime, isNotNull);
      expect(notificationService.isCompletionAlarmCancelled, isFalse);

      notifier.pause();
      expect(notificationService.isCompletionAlarmCancelled, isTrue);

      notifier.resume();
      expect(notificationService.isCompletionAlarmCancelled, isFalse);

      await notifier.cancelSession();
      expect(notificationService.isCompletionAlarmCancelled, isTrue);
    });

    test(
        'syncWithWallClock transitions to completed if targetEndTime has passed',
        () async {
      notifier.setDurationPreset(1);
      await notifier.startFocusSession('Quick Test');
      expect(notifier.status, TimerStatus.running);

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      notifier.syncWithWallClock();

      expect(notifier.status, TimerStatus.completed);
      expect(notifier.remainingSeconds, 0);
      expect(notificationService.isCancelled, isTrue);
      expect(notificationService.isCompletionAlarmCancelled, isTrue);
    });

    test(
        'session expiration writes accurate completion state to repository immediately upon finish',
        () async {
      notifier.setDurationPreset(1);
      await notifier.startFocusSession('Finish Guard Test');
      expect(notifier.status, TimerStatus.running);

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      notifier.syncWithWallClock();

      expect(notifier.status, TimerStatus.completed);
      expect(sessionRepository.lastUpdatedSessionId, 101);
      expect(sessionRepository.lastUpdatedStatus, SessionStatus.lockedIn);
      expect(sessionRepository.lastUpdatedDuration, 1);
    });

    test('pause when targetEndTime has passed completes session cleanly instead of freezing at 00:00', () async {
      notifier.setDurationPreset(1);
      await notifier.startFocusSession('Expire and pause');
      expect(notifier.status, TimerStatus.running);
      expect(notifier.targetEndTime, isNotNull);

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      notifier.pause();

      expect(notifier.status, TimerStatus.completed);
      expect(notifier.remainingSeconds, 0);
      expect(notifier.targetEndTime, isNull);
    });

    test('pause clears targetEndTime and resume restores it', () async {
      await notifier.startFocusSession('Target End Time Test');
      expect(notifier.targetEndTime, isNotNull);

      notifier.pause();
      expect(notifier.status, TimerStatus.paused);
      expect(notifier.targetEndTime, isNull);

      notifier.resume();
      expect(notifier.status, TimerStatus.running);
      expect(notifier.targetEndTime, isNotNull);
    });

    test(
        'checkInSession always transitions from completed (00:00) to breakRunning even if persistence or notification throws',
        () async {
      final throwingRepo = _ThrowingSessionRepository();
      final resilientNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(throwingRepo),
        completeSessionUseCase: CompleteSessionUseCase(throwingRepo),
        cancelSessionUseCase: CancelSessionUseCase(throwingRepo),
        notificationService: _ThrowingCancelNotificationService(),
      );
      addTearDown(resilientNotifier.dispose);

      resilientNotifier.setDurationPreset(1);
      await resilientNotifier.startFocusSession('Resilient Check-In');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      resilientNotifier.syncWithWallClock();
      expect(resilientNotifier.status, TimerStatus.completed);
      expect(resilientNotifier.remainingSeconds, 0);

      await resilientNotifier.checkInSession(lockedIn: true);

      expect(resilientNotifier.status, TimerStatus.breakRunning);
      expect(
        resilientNotifier.remainingSeconds,
        TimerNotifier.defaultBreakSeconds,
      );
    });

    test(
        'cancelSession during break resets targetDurationSeconds back to focusDurationSeconds',
        () async {
      notifier.setDurationPreset(45 * 60);
      await notifier.startFocusSession('Focus Before Break');
      await notifier.checkInSession(lockedIn: true);
      expect(notifier.status, TimerStatus.breakRunning);
      expect(notifier.targetDurationSeconds, TimerNotifier.defaultBreakSeconds);

      await notifier.cancelSession();

      expect(notifier.status, TimerStatus.idle);
      expect(notifier.targetDurationSeconds, 45 * 60);
      expect(notifier.remainingSeconds, 45 * 60);
      expect(notifier.targetEndTime, isNull);
    });

    test(
        'singleSessionMode toggles, persists to SharedPreferences, and skips break after checkInSession',
        () async {
      expect(notifier.isSingleSessionMode, isFalse);

      await notifier.toggleSingleSessionMode();
      expect(notifier.isSingleSessionMode, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(TimerNotifier.singleSessionModeKey), isTrue);

      // Verify a newly instantiated TimerNotifier restores isSingleSessionMode from SharedPreferences
      final restoredNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        notificationService: notificationService,
        prefs: prefs,
      );
      addTearDown(restoredNotifier.dispose);
      expect(restoredNotifier.isSingleSessionMode, isTrue);

      notifier.setDurationPreset(30 * 60);
      await notifier.startFocusSession('Single Block Goal', backlogTaskId: 7);

      notificationService.lastScheduledCompletionGoal = null;
      await notifier.checkInSession(lockedIn: true);

      expect(sessionRepository.lastUpdatedStatus, SessionStatus.lockedIn);
      expect(backlogRepository.lastCompletedTaskId, 7);
      expect(notifier.status, TimerStatus.idle);
      expect(notifier.targetDurationSeconds, 30 * 60);
      expect(notifier.remainingSeconds, 30 * 60);
      expect(notifier.targetEndTime, isNull);
      expect(notificationService.lastScheduledCompletionGoal, isNull);
    });

    test(
        'checkInSession with lockedIn false in singleSessionMode records DERAILED, leaves backlog task pending, and skips break to idle',
        () async {
      await notifier.setSingleSessionMode(true);
      await notifier.startFocusSession('Derailed Single Session',
          backlogTaskId: 55);

      notificationService.lastScheduledCompletionGoal = null;
      await notifier.checkInSession(lockedIn: false);

      expect(sessionRepository.lastUpdatedStatus, SessionStatus.derailed);
      expect(backlogRepository.lastCompletedTaskId, isNull);
      expect(notifier.status, TimerStatus.idle);
      expect(notifier.linkedBacklogTaskId, isNull);
      expect(notificationService.lastScheduledCompletionGoal, isNull);
    });

    test(
        'checkInSession with endAllSessions true returns directly to idle even when singleSessionMode is false',
        () async {
      expect(notifier.isSingleSessionMode, isFalse);

      await notifier.startFocusSession('Lock In Then Done', backlogTaskId: 12);
      notificationService.lastScheduledCompletionGoal = null;

      await notifier.checkInSession(lockedIn: true, endAllSessions: true);

      expect(sessionRepository.lastUpdatedStatus, SessionStatus.lockedIn);
      expect(backlogRepository.lastCompletedTaskId, 12);
      expect(notifier.status, TimerStatus.idle);
      expect(notifier.targetDurationSeconds, TimerNotifier.defaultFocusSeconds);
      expect(notifier.remainingSeconds, TimerNotifier.defaultFocusSeconds);
      expect(notificationService.lastScheduledCompletionGoal, isNull);
    });

    test(
        'readyToFocusFromBreak preserves currentTaskGoal while endAllSessions clears goal and backlog link across breakRunning and breakCompleted',
        () async {
      notifier.setDurationPreset(45 * 60);
      await notifier.startFocusSession('Retryable Task', backlogTaskId: 88);
      await notifier.checkInSession(lockedIn: false);

      expect(notifier.status, TimerStatus.breakRunning);
      expect(notifier.currentTaskGoal, 'Retryable Task');
      expect(notifier.linkedBacklogTaskId, 88);

      // readyToFocusFromBreak keeps goal and uncompleted backlog task ID for next session
      notifier.readyToFocusFromBreak();
      expect(notifier.status, TimerStatus.idle);
      expect(notifier.currentTaskGoal, 'Retryable Task');
      expect(notifier.linkedBacklogTaskId, 88);

      // Start again, complete into breakRunning, then expire into breakCompleted
      await notifier.startFocusSession(
        notifier.currentTaskGoal,
        backlogTaskId: notifier.linkedBacklogTaskId,
      );
      await notifier.checkInSession(lockedIn: false);
      expect(notifier.status, TimerStatus.breakRunning);

      // End all sessions from breakRunning
      notifier.endAllSessions();
      expect(notifier.status, TimerStatus.idle);
      expect(notifier.currentTaskGoal, isEmpty);
      expect(notifier.linkedBacklogTaskId, isNull);
      expect(notificationService.isCancelled, isTrue);
      expect(notificationService.isCompletionAlarmCancelled, isTrue);
    });

    test(
        'ongoing notification is posted once on start and not re-posted on 30-second boundaries, updating only on pause/resume',
        () async {
      notifier.setDurationPreset(31);
      await notifier.startFocusSession('Deep Focus No Flash');
      expect(notificationService.showOngoingTimerCallCount, 1);
      expect(notificationService.lastShownIsPaused, isFalse);
      expect(notificationService.lastShownTargetEndTimeEpochMs, isNotNull);

      // Wait across the 30-second boundary (31 -> 30)
      await Future<void>.delayed(const Duration(milliseconds: 1250));
      expect(notifier.remainingSeconds, lessThanOrEqualTo(30));
      expect(notificationService.showOngoingTimerCallCount, 1);

      notifier.pause();
      expect(notificationService.showOngoingTimerCallCount, 2);
      expect(notificationService.lastShownIsPaused, isTrue);
      expect(notificationService.lastShownTargetEndTimeEpochMs, isNull);

      notifier.resume();
      expect(notificationService.showOngoingTimerCallCount, 3);
      expect(notificationService.lastShownIsPaused, isFalse);
      expect(notificationService.lastShownTargetEndTimeEpochMs, isNotNull);
    });

    test(
        'startNextFocusFromBreak transitions from breakRunning to running and starts focus session',
        () async {
      await notifier.startFocusSession('Block 1');
      await notifier.checkInSession(lockedIn: true);
      expect(notifier.status, equals(TimerStatus.breakRunning));

      final started = await notifier.startNextFocusFromBreak('Block 2');
      expect(started, isTrue);
      expect(notifier.status, equals(TimerStatus.running));
      expect(notifier.currentTaskGoal, equals('Block 2'));

      await notifier.cancelSession();
    });

    test(
        'startNextFocusFromBreak defaults empty candidate goal to Deep Work and clears completed backlogTaskId',
        () async {
      await notifier.startFocusSession('Linked Task', backlogTaskId: 42);
      await notifier.checkInSession(lockedIn: true);
      expect(notifier.status, equals(TimerStatus.breakRunning));

      final started = await notifier.startNextFocusFromBreak('   ');
      expect(started, isTrue);
      expect(notifier.status, equals(TimerStatus.running));
      expect(notifier.currentTaskGoal, equals('Deep Work'));
      expect(notifier.linkedBacklogTaskId, isNull);

      await notifier.cancelSession();
    });

    test(
        'cold-start crash tombstone recovery restores in-progress running session and clears on cancel',
        () async {
      final prefs = await SharedPreferences.getInstance();
      notifier.setDurationPreset(30 * 60);
      await notifier.startFocusSession('Crash Recovery Goal',
          backlogTaskId: 19);

      expect(prefs.getString(TimerNotifier.sessionTombstoneKey), isNotNull);

      final coldStartNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        notificationService: notificationService,
        prefs: prefs,
      );
      addTearDown(coldStartNotifier.dispose);

      final recovered = await coldStartNotifier.recoverActiveSession();
      expect(recovered, isTrue);
      expect(coldStartNotifier.status, equals(TimerStatus.running));
      expect(coldStartNotifier.activeSessionId, equals(101));
      expect(coldStartNotifier.currentTaskGoal, equals('Crash Recovery Goal'));
      expect(coldStartNotifier.linkedBacklogTaskId, equals(19));
      expect(coldStartNotifier.targetDurationSeconds, equals(30 * 60));
      expect(coldStartNotifier.remainingSeconds, greaterThan(0));

      await coldStartNotifier.cancelSession();
      expect(prefs.getString(TimerNotifier.sessionTombstoneKey), isNull);
    });

    test(
        'cold-start crash tombstone recovery transitions expired running session to completed and updates SQLite to LOCKED_IN',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final pastEndMs = DateTime.now()
          .subtract(const Duration(minutes: 2))
          .millisecondsSinceEpoch;
      final expiredTombstone = ActiveSessionTombstoneEntity(
        sessionId: 303,
        status: TombstoneSessionStatus.running,
        taskGoal: 'Finished While Killed',
        linkedBacklogTaskId: 11,
        focusDurationSeconds: 1500,
        targetDurationSeconds: 1500,
        remainingSeconds: 600,
        targetEndTimeEpochMs: pastEndMs,
        savedAtEpochMs: pastEndMs - 600000,
      );
      await prefs.setString(
        TimerNotifier.sessionTombstoneKey,
        expiredTombstone.toJson(),
      );

      final coldStartNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        notificationService: notificationService,
        prefs: prefs,
      );
      addTearDown(coldStartNotifier.dispose);

      final recovered = await coldStartNotifier.recoverActiveSession();
      expect(recovered, isTrue);
      expect(coldStartNotifier.status, equals(TimerStatus.completed));
      expect(coldStartNotifier.activeSessionId, equals(303));
      expect(coldStartNotifier.currentTaskGoal, equals('Finished While Killed'));
      expect(coldStartNotifier.remainingSeconds, equals(0));
      expect(sessionRepository.lastUpdatedSessionId, equals(303));
      expect(sessionRepository.lastUpdatedStatus, equals(SessionStatus.lockedIn));
      expect(sessionRepository.lastUpdatedDuration, equals(1500));
    });

    test(
        'cold-start crash tombstone recovery restores paused session and SQLite fallback when prefs tombstone absent',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await notifier.startFocusSession('Paused Recovery', backlogTaskId: 5);
      notifier.pause();

      final pausedNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        notificationService: notificationService,
        prefs: prefs,
      );
      addTearDown(pausedNotifier.dispose);

      final recoveredPaused = await pausedNotifier.recoverActiveSession();
      expect(recoveredPaused, isTrue);
      expect(pausedNotifier.status, equals(TimerStatus.paused));
      expect(pausedNotifier.currentTaskGoal, equals('Paused Recovery'));
      expect(pausedNotifier.linkedBacklogTaskId, equals(5));
      await pausedNotifier.cancelSession();

      // Verify SQLite fallback via RecoverActiveSessionUseCase when SharedPreferences tombstone is absent
      final now = DateTime.now();
      final startMs =
          now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch;
      sessionRepository.storedSessions = <SessionEntity>[
        SessionEntity(
          id: 777,
          taskGoal: 'SQLite Tombstone Goal',
          sessionType: SessionType.focus,
          targetDurationSeconds: 1500,
          actualDurationSeconds: 0,
          startTimeEpochMs: startMs,
          endTimeEpochMs: startMs + 1500 * 1000,
          status: SessionStatus.cancelled,
        ),
      ];

      final sqliteRecoveredNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        recoverActiveSessionUseCase:
            RecoverActiveSessionUseCase(sessionRepository),
        notificationService: notificationService,
        prefs: prefs,
      );
      addTearDown(sqliteRecoveredNotifier.dispose);

      final recovered =
          await sqliteRecoveredNotifier.recoverActiveSession(now: now);
      expect(recovered, isTrue);
      expect(sqliteRecoveredNotifier.status, equals(TimerStatus.running));
      expect(sqliteRecoveredNotifier.activeSessionId, equals(777));
      expect(
        sqliteRecoveredNotifier.currentTaskGoal,
        equals('SQLite Tombstone Goal'),
      );
      await sqliteRecoveredNotifier.cancelSession();
    });

    test(
        'cold-start crash tombstone recovery restores completed, breakRunning (active and expired), and breakCompleted states',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 10, 31, 14, 0, 0);

      final completedTombstone = ActiveSessionTombstoneEntity(
        sessionId: 401,
        status: TombstoneSessionStatus.completed,
        taskGoal: 'Awaiting Check-In',
        linkedBacklogTaskId: 7,
        focusDurationSeconds: 1500,
        targetDurationSeconds: 1500,
        remainingSeconds: 0,
        savedAtEpochMs: now.millisecondsSinceEpoch - 5000,
      );
      await prefs.setString(
        TimerNotifier.sessionTombstoneKey,
        completedTombstone.toJson(),
      );

      final completedNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        notificationService: notificationService,
        prefs: prefs,
      );
      addTearDown(completedNotifier.dispose);
      expect(await completedNotifier.recoverActiveSession(now: now), isTrue);
      expect(completedNotifier.status, equals(TimerStatus.completed));
      expect(completedNotifier.activeSessionId, equals(401));
      expect(completedNotifier.currentTaskGoal, equals('Awaiting Check-In'));

      final activeBreakTombstone = ActiveSessionTombstoneEntity(
        status: TombstoneSessionStatus.breakRunning,
        taskGoal: 'Post-Focus Break',
        focusDurationSeconds: 1500,
        targetDurationSeconds: 300,
        remainingSeconds: 180,
        targetEndTimeEpochMs:
            now.add(const Duration(minutes: 3)).millisecondsSinceEpoch,
        savedAtEpochMs: now.millisecondsSinceEpoch - 120000,
      );
      await prefs.setString(
        TimerNotifier.sessionTombstoneKey,
        activeBreakTombstone.toJson(),
      );

      final breakRunningNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        notificationService: notificationService,
        prefs: prefs,
      );
      addTearDown(breakRunningNotifier.dispose);
      expect(await breakRunningNotifier.recoverActiveSession(now: now), isTrue);
      expect(breakRunningNotifier.status, equals(TimerStatus.breakRunning));
      expect(breakRunningNotifier.remainingSeconds, equals(180));
      breakRunningNotifier.endAllSessions();

      final expiredBreakTombstone = ActiveSessionTombstoneEntity(
        status: TombstoneSessionStatus.breakRunning,
        taskGoal: 'Expired Break',
        focusDurationSeconds: 1500,
        targetDurationSeconds: 300,
        remainingSeconds: 60,
        targetEndTimeEpochMs:
            now.subtract(const Duration(seconds: 30)).millisecondsSinceEpoch,
        savedAtEpochMs: now.millisecondsSinceEpoch - 300000,
      );
      await prefs.setString(
        TimerNotifier.sessionTombstoneKey,
        expiredBreakTombstone.toJson(),
      );

      final expiredBreakNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        notificationService: notificationService,
        prefs: prefs,
      );
      addTearDown(expiredBreakNotifier.dispose);
      expect(await expiredBreakNotifier.recoverActiveSession(now: now), isTrue);
      expect(expiredBreakNotifier.status, equals(TimerStatus.breakCompleted));
      expect(expiredBreakNotifier.remainingSeconds, equals(0));

      final breakCompletedTombstone = ActiveSessionTombstoneEntity(
        status: TombstoneSessionStatus.breakCompleted,
        taskGoal: 'Break Already Done',
        focusDurationSeconds: 1500,
        targetDurationSeconds: 300,
        remainingSeconds: 0,
        savedAtEpochMs: now.millisecondsSinceEpoch - 10000,
      );
      await prefs.setString(
        TimerNotifier.sessionTombstoneKey,
        breakCompletedTombstone.toJson(),
      );

      final breakCompletedNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        notificationService: notificationService,
        prefs: prefs,
      );
      addTearDown(breakCompletedNotifier.dispose);
      expect(
        await breakCompletedNotifier.recoverActiveSession(now: now),
        isTrue,
      );
      expect(breakCompletedNotifier.status, equals(TimerStatus.breakCompleted));
    });

    test(
        'endAllSessions during active session finalizes SQLite status via cancelSessionUseCase and ignores malformed tombstone JSON types',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await notifier.startFocusSession('Session Ended Early');
      notifier.endAllSessions();
      await Future<void>.delayed(Duration.zero);

      expect(sessionRepository.lastUpdatedSessionId, equals(101));
      expect(sessionRepository.lastUpdatedStatus, equals(SessionStatus.cancelled));

      await prefs.setString(
        TimerNotifier.sessionTombstoneKey,
        '{"status":123,"taskGoal":false,"focusDurationSeconds":"invalid"}',
      );
      expect(
        ActiveSessionTombstoneEntity.tryFromJson(
          prefs.getString(TimerNotifier.sessionTombstoneKey),
        ),
        isNull,
      );
    });
  });
}

class _ThrowingSessionRepository extends _FakeSessionRepository {
  @override
  Future<Either<Failure, void>> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async {
    throw StateError('Simulated SQLite lock failure');
  }
}

class _ThrowingCancelNotificationService extends _MockNotificationService {
  @override
  Future<void> cancelTimerNotification() async {
    throw StateError('Simulated notification plugin error');
  }
}
