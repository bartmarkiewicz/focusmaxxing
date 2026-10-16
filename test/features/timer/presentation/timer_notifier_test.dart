import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSessionRepository implements ISessionRepository {
  SessionEntity? lastCreatedSession;
  int? lastUpdatedSessionId;
  String? lastUpdatedStatus;
  int? lastUpdatedDuration;

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
      const Right<Failure, List<SessionEntity>>([]);
}

class _FakeBacklogRepository implements IBacklogRepository {
  int? lastCompletedTaskId;
  int? lastCompletedSessionId;

  @override
  Future<Either<Failure, void>> markCompleted(int id, int sessionId) async {
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
  bool isCancelled = false;

  @override
  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
  }) async {
    lastShownGoal = taskGoal;
    isCancelled = false;
  }

  @override
  Future<void> cancelTimerNotification() async {
    isCancelled = true;
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
    test('initial state defaults to 25 minutes, idle, and loads cached goals', () async {
      expect(notifier.status, TimerStatus.idle);
      expect(notifier.targetDurationSeconds, 1500);
      expect(notifier.remainingSeconds, 1500);
      expect(notifier.cancelHoldProgress, 0.0);
      expect(notifier.recentGoals, contains('Recent 1'));
    });

    test('setDurationPreset updates duration while idle but ignores while running', () async {
      notifier.setDurationPreset(45 * 60);
      expect(notifier.targetDurationSeconds, 2700);
      expect(notifier.remainingSeconds, 2700);

      await notifier.startFocusSession('Coding');
      expect(notifier.status, TimerStatus.running);

      notifier.setDurationPreset(15 * 60);
      expect(notifier.targetDurationSeconds, 2700);
    });

    test('startFocusSession starts active countdown and notification', () async {
      final success = await notifier.startFocusSession('Fix Memory Leak');

      expect(success, isTrue);
      expect(notifier.status, TimerStatus.running);
      expect(notifier.currentTaskGoal, 'Fix Memory Leak');
      expect(notifier.activeSessionId, 101);
      expect(notificationService.lastShownGoal, 'Fix Memory Leak');
      expect(notifier.recentGoals.first, 'Fix Memory Leak');
    });

    test('pause and resume correctly toggle running and paused states', () async {
      await notifier.startFocusSession('Deep Study');

      notifier.pause();
      expect(notifier.status, TimerStatus.paused);

      notifier.resume();
      expect(notifier.status, TimerStatus.running);
    });

    test('releaseHoldToCancel resets progress to 0.0 without side effects', () async {
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

    test('cancelSession updates session to CANCELLED and resets to idle', () async {
      await notifier.startFocusSession('Abort Test');
      notifier.pause();

      await notifier.cancelSession();

      expect(notifier.status, TimerStatus.idle);
      expect(notifier.activeSessionId, isNull);
      expect(sessionRepository.lastUpdatedStatus, SessionStatus.cancelled);
      expect(notificationService.isCancelled, isTrue);
    });

    test('checkInSession records outcome, completes backlog task, and starts break', () async {
      await notifier.startFocusSession('Finish Feature', backlogTaskId: 42);

      await notifier.checkInSession(lockedIn: true);

      expect(sessionRepository.lastUpdatedStatus, SessionStatus.lockedIn);
      expect(backlogRepository.lastCompletedTaskId, 42);
      expect(backlogRepository.lastCompletedSessionId, 101);
      expect(notifier.status, TimerStatus.breakRunning);
      expect(notifier.targetDurationSeconds, TimerNotifier.defaultBreakSeconds);

      notifier.readyToFocusFromBreak();
      expect(notifier.status, TimerStatus.idle);
      expect(notifier.targetDurationSeconds, TimerNotifier.defaultFocusSeconds);
    });

    test('checkInSession with lockedIn false records DERAILED and leaves backlog task pending (MED-03)', () async {
      await notifier.startFocusSession('Unfinished Task', backlogTaskId: 99);

      await notifier.checkInSession(lockedIn: false);

      expect(sessionRepository.lastUpdatedStatus, SessionStatus.derailed);
      expect(backlogRepository.lastCompletedTaskId, isNull);
      expect(backlogRepository.lastCompletedSessionId, isNull);
      expect(notifier.status, TimerStatus.breakRunning);
    });

    test('startFocusSession can start directly from break mode with saved focus duration preset (CRIT-02)', () async {
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

    test('startHoldToCancel updates cancelHoldProgressNotifier without calling notifyListeners on TimerNotifier (MED-02)', () async {
      await notifier.startFocusSession('No Rebuild Storm');
      notifier.pause();

      var timerNotifierCallCount = 0;
      notifier.addListener(() => timerNotifierCallCount++);

      final progressValues = <double>[];
      void onProgress() => progressValues.add(notifier.cancelHoldProgressNotifier.value);
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
  });
}
