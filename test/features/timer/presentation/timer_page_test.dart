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
    testWidgets('renders title, dial, presets, and LOCK IN button when idle', (tester) async {
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

    testWidgets('selecting duration preset updates dial countdown', (tester) async {
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

    testWidgets('tapping goal anchor pill opens GoalInputDialog for editing without starting timer', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Single Focus Anchor'));
      await tester.pumpAndSettle();

      expect(find.text('What ONE thing are you locking in on?'), findsOneWidget);
      expect(timerNotifier.status, TimerStatus.idle);
    });
  });
}
