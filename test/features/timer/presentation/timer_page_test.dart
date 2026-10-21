import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/add_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/delete_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/get_pending_tasks_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/pages/timer_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSessionRepository implements ISessionRepository {
  SessionEntity? lastCreatedSession;

  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async {
    lastCreatedSession = session;
    return const Right<Failure, int>(1);
  }

  @override
  Future<Either<Failure, void>> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async =>
      const Right<Failure, List<SessionEntity>>([]);
}

class _FakeBacklogRepository implements IBacklogRepository {
  @override
  Future<Either<Failure, int>> addTask(String title) async =>
      const Right<Failure, int>(1);

  @override
  Future<Either<Failure, void>> deleteTask(int id) async =>
      const Right<Failure, void>(null);

  @override
  Future<Either<Failure, List<BacklogTaskEntity>>> getPendingTasks() async =>
      const Right<Failure, List<BacklogTaskEntity>>([]);

  @override
  Future<Either<Failure, void>> markCompleted(int id, int sessionId) async =>
      const Right<Failure, void>(null);
}

class _MockNotificationService extends NotificationService {
  @override
  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
  }) async {}

  @override
  Future<void> cancelTimerNotification() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSessionRepository sessionRepository;
  late _FakeBacklogRepository backlogRepository;
  late _MockNotificationService notificationService;
  late TimerNotifier timerNotifier;
  late BacklogNotifier backlogNotifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    sessionRepository = _FakeSessionRepository();
    backlogRepository = _FakeBacklogRepository();
    notificationService = _MockNotificationService();

    timerNotifier = TimerNotifier(
      startSessionUseCase: StartSessionUseCase(sessionRepository),
      completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
      cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
      markTaskCompletedUseCase: MarkTaskCompletedUseCase(backlogRepository),
      notificationService: notificationService,
      prefs: prefs,
    );

    backlogNotifier = BacklogNotifier(
      getPendingTasksUseCase: GetPendingTasksUseCase(backlogRepository),
      addBacklogTaskUseCase: AddBacklogTaskUseCase(backlogRepository),
      deleteBacklogTaskUseCase: DeleteBacklogTaskUseCase(backlogRepository),
      markTaskCompletedUseCase: MarkTaskCompletedUseCase(backlogRepository),
    );
  });

  tearDown(() {
    timerNotifier.dispose();
    backlogNotifier.dispose();
  });

  Widget buildWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TimerNotifier>.value(value: timerNotifier),
        ChangeNotifierProvider<BacklogNotifier>.value(value: backlogNotifier),
      ],
      child: const MaterialApp(
        home: TimerPage(),
      ),
    );
  }

  group('TimerPage', () {
    testWidgets('renders title, dial, presets, and LOCK IN button when idle',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('FOCUSMAXXING'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('15m'), findsOneWidget);
      expect(find.text('25m'), findsOneWidget);
      expect(find.text('45m'), findsOneWidget);
      expect(find.text('60m'), findsOneWidget);
      expect(find.text('🚀 LOCK IN'), findsOneWidget);
    });

    testWidgets('selecting duration preset updates dial countdown',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('45m'));
      await tester.pumpAndSettle();

      expect(find.text('45:00'), findsOneWidget);
    });

    testWidgets('tapping backlog icon opens BacklogModalSheet', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.inbox_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Backlog (Focus Scratchpad)'), findsOneWidget);
    });

    testWidgets(
        'tapping goal anchor pill opens GoalInputDialog for editing without starting timer',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Single Focus Anchor'));
      await tester.pumpAndSettle();

      expect(
          find.text('What ONE thing are you locking in on?'), findsOneWidget);
      expect(timerNotifier.status, TimerStatus.idle);
    });

    testWidgets(
        '1-tap lock-in starts session immediately with Deep Work default and shows active lock-in banner',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('🚀 LOCK IN'));
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.running);
      expect(timerNotifier.currentTaskGoal, 'Deep Work');
      expect(sessionRepository.lastCreatedSession?.taskGoal, 'Deep Work');
      expect(find.text('🔒 LOCKED IN · ACTIVE FOCUS'), findsOneWidget);

      timerNotifier.pause();
      await tester.pumpAndSettle();
      expect(find.text('⏸ FOCUS SESSION PAUSED'), findsOneWidget);

      await timerNotifier.cancelSession();
      await tester.pumpAndSettle();
      expect(find.text('🔒 LOCKED IN · ACTIVE FOCUS'), findsNothing);
    });

    testWidgets('tapping Custom duration opens bottom sheet and updates preset',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      expect(find.text('Set Custom Duration'), findsOneWidget);
      expect(find.text('APPLY DURATION'), findsOneWidget);

      await tester.tap(find.text('+15'));
      await tester.pumpAndSettle();
      expect(find.text('40 min'), findsOneWidget);

      await tester.tap(find.text('APPLY DURATION'));
      await tester.pumpAndSettle();

      expect(timerNotifier.targetDurationSeconds, 40 * 60);
      expect(find.text('40:00'), findsOneWidget);
    });

    testWidgets('tapping ambient soundscapes pill opens bottom sheet',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Ambient Audio: Off'), findsOneWidget);
      await tester.tap(find.text('Ambient Audio: Off'));
      await tester.pumpAndSettle();

      expect(find.text('🎧 Ambient Soundscapes'), findsOneWidget);
    });

    testWidgets(
        'recent goal chips render and tapping a chip updates the anchor',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_focus_goals', ['Coding', 'Deep Work']);

      final testNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        markTaskCompletedUseCase: MarkTaskCompletedUseCase(backlogRepository),
        notificationService: notificationService,
        prefs: prefs,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TimerNotifier>.value(value: testNotifier),
            ChangeNotifierProvider<BacklogNotifier>.value(
                value: backlogNotifier),
          ],
          child: const MaterialApp(
            home: TimerPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coding'), findsOneWidget);
      expect(find.text('Deep Work'), findsOneWidget);

      await tester.tap(find.text('Coding'));
      await tester.pumpAndSettle();

      expect(testNotifier.currentTaskGoal, 'Coding');
      expect(find.text('Coding'), findsWidgets); // chip and anchor pill
      testNotifier.dispose();
    });

    testWidgets('tapping I\'M READY TO FOCUS during break returns to idle',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Start session and check-in to trigger break
      await timerNotifier.startFocusSession('Review PR');
      await tester.pumpAndSettle();
      expect(timerNotifier.status, TimerStatus.running);

      await timerNotifier.checkInSession(lockedIn: true);
      await tester.pumpAndSettle();
      expect(timerNotifier.status, TimerStatus.breakRunning);
      expect(find.text('I\'M READY TO FOCUS'), findsOneWidget);

      // Tap ready to focus
      await tester.tap(find.text('I\'M READY TO FOCUS'));
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.idle);
      expect(find.text('🚀 LOCK IN'), findsOneWidget);
    });

    testWidgets(
        'tapping Single Session pill toggles singleSessionMode on TimerNotifier',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Single Session: OFF'), findsOneWidget);
      expect(timerNotifier.isSingleSessionMode, isFalse);

      await tester.tap(find.byKey(const Key('timer_single_session_mode_pill')));
      await tester.pumpAndSettle();

      expect(find.text('Single Session: ON'), findsOneWidget);
      expect(timerNotifier.isSingleSessionMode, isTrue);
    });

    testWidgets(
        'tapping END ALL SESSIONS during break returns to idle',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await timerNotifier.startFocusSession('Lock In Phase');
      await tester.pumpAndSettle();

      await timerNotifier.checkInSession(lockedIn: true);
      await tester.pumpAndSettle();
      expect(timerNotifier.status, TimerStatus.breakRunning);
      final endAllButton =
          find.byKey(const Key('timer_end_all_sessions_button'));
      expect(endAllButton, findsOneWidget);

      await tester.ensureVisible(endAllButton);
      await tester.pumpAndSettle();
      await tester.tap(endAllButton);
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.idle);
      expect(find.text('🚀 LOCK IN'), findsOneWidget);
    });

    testWidgets(
        'check-in dialog in Single Session Mode still prompts user and returns directly to idle upon check-in',
        (tester) async {
      await timerNotifier.setSingleSessionMode(true);
      timerNotifier.setDurationPreset(1);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('🚀 LOCK IN'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      });
      timerNotifier.syncWithWallClock();
      await tester.pumpAndSettle();

      expect(find.text('Did you lock in?'), findsOneWidget);
      await tester.tap(find.text('LOCKED IN 🚀'));
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.idle);
      expect(find.text('🚀 LOCK IN'), findsOneWidget);
    });

    testWidgets(
        'tapping LOCKED IN & END ALL SESSIONS in check-in dialog ends all sessions and returns to idle',
        (tester) async {
      expect(timerNotifier.isSingleSessionMode, isFalse);
      timerNotifier.setDurationPreset(1);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('🚀 LOCK IN'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      });
      timerNotifier.syncWithWallClock();
      await tester.pumpAndSettle();

      expect(find.text('Did you lock in?'), findsOneWidget);
      final endAllBtn =
          find.byKey(const Key('checkin_end_all_sessions_button'));
      await tester.ensureVisible(endAllBtn);
      await tester.pumpAndSettle();
      await tester.tap(endAllBtn);
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.idle);
      expect(find.text('🚀 LOCK IN'), findsOneWidget);
    });
  });
}
