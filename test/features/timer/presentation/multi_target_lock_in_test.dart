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
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/active_lock_in_banner.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/goal_anchor_pill.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/multi_target_picker_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSessionRepository implements ISessionRepository {
  SessionEntity? lastCreatedSession;
  int? lastUpdatedSessionId;
  String? lastUpdatedStatus;
  int? lastUpdatedDuration;

  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async {
    lastCreatedSession = session;
    return const Right(101);
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
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async =>
      const Right([]);
}

class _FakeBacklogRepository implements IBacklogRepository {
  List<BacklogTaskEntity> tasks = [];
  final List<int> completedTaskIds = [];

  @override
  Future<Either<Failure, List<BacklogTaskEntity>>> getPendingTasks() async {
    return Right(tasks.where((t) => !t.isCompleted).toList());
  }

  @override
  Future<Either<Failure, int>> addTask(String title) async {
    final task = BacklogTaskEntity(
      id: tasks.length + 1,
      title: title,
      createdAt: DateTime.now(),
    );
    tasks.add(task);
    return Right(task.id!);
  }

  @override
  Future<Either<Failure, void>> deleteTask(int id) async {
    tasks.removeWhere((t) => t.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> markCompleted(int id, [int? sessionId]) async {
    completedTaskIds.add(id);
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      tasks[idx] = tasks[idx].copyWith(isCompleted: true, completedSessionId: sessionId);
    }
    return const Right(null);
  }
}

class _MockNotificationService extends NotificationService {
  @override
  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
    bool isBreak = false,
  }) async {}

  @override
  Future<void> cancelTimerNotification() async {}

  @override
  Future<void> cancelSessionCompletionNotification() async {}

  @override
  Future<void> scheduleSessionCompletionNotification({
    required DateTime targetEndTime,
    required String goal,
    bool isBreak = false,
  }) async {}
}

void main() {
  late _FakeSessionRepository sessionRepo;
  late _FakeBacklogRepository backlogRepo;
  late TimerNotifier timerNotifier;
  late BacklogNotifier backlogNotifier;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sessionRepo = _FakeSessionRepository();
    backlogRepo = _FakeBacklogRepository();

    final markTaskCompleted = MarkTaskCompletedUseCase(backlogRepo);
    backlogNotifier = BacklogNotifier(
      getPendingTasksUseCase: GetPendingTasksUseCase(backlogRepo),
      addBacklogTaskUseCase: AddBacklogTaskUseCase(backlogRepo),
      deleteBacklogTaskUseCase: DeleteBacklogTaskUseCase(backlogRepo),
      markTaskCompletedUseCase: markTaskCompleted,
    );

    timerNotifier = TimerNotifier(
      startSessionUseCase: StartSessionUseCase(sessionRepo),
      completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
      cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
      notificationService: _MockNotificationService(),
      markTaskCompletedUseCase: markTaskCompleted,
      backlogNotifier: backlogNotifier,
    );
  });

  tearDown(() {
    timerNotifier.dispose();
  });

  group('TimerNotifier Multi-Target and Batch Backlog Completion', () {
    test('startFocusSessionWithTargets creates session with targets', () async {
      const targets = [
        SessionTargetAllocation(
          targetName: 'Mobile UI',
          percentage: 60,
          colorHex: '#00E5FF',
        ),
        SessionTargetAllocation(
          targetName: 'API Refactor',
          percentage: 40,
          colorHex: '#FF4081',
        ),
      ];

      final success = await timerNotifier.startFocusSessionWithTargets(targets);
      expect(success, isTrue);
      expect(timerNotifier.status, TimerStatus.running);
      expect(timerNotifier.currentTargets.length, 2);
      expect(timerNotifier.currentTaskGoal, 'Mobile UI • API Refactor');
      expect(sessionRepo.lastCreatedSession?.targets.length, 2);
    });

    test('checkInSession(lockedIn: true) batch auto-completes ALL linked backlog tasks', () async {
      await backlogRepo.addTask('Fix auth crash');
      await backlogRepo.addTask('Implement caching');
      await backlogNotifier.loadPendingTasks();

      const targets = [
        SessionTargetAllocation(
          targetName: 'Fix auth crash',
          percentage: 50,
          backlogTaskId: 1,
        ),
        SessionTargetAllocation(
          targetName: 'Implement caching',
          percentage: 50,
          backlogTaskId: 2,
        ),
      ];

      await timerNotifier.startFocusSessionWithTargets(targets, backlogTaskIds: [1, 2]);
      expect(timerNotifier.linkedBacklogTaskIds, [1, 2]);

      // Check-in as locked in
      await timerNotifier.checkInSession(lockedIn: true);

      expect(backlogRepo.completedTaskIds, containsAll([1, 2]));
      expect(timerNotifier.linkedBacklogTaskIds, isEmpty);
    });

    test('checkInSession(lockedIn: false) leaves linked backlog tasks pending', () async {
      await backlogRepo.addTask('Fix auth crash');
      await backlogRepo.addTask('Implement caching');

      const targets = [
        SessionTargetAllocation(
          targetName: 'Fix auth crash',
          percentage: 50,
          backlogTaskId: 1,
        ),
        SessionTargetAllocation(
          targetName: 'Implement caching',
          percentage: 50,
          backlogTaskId: 2,
        ),
      ];

      await timerNotifier.startFocusSessionWithTargets(targets, backlogTaskIds: [1, 2]);

      // Check-in as derailed
      await timerNotifier.checkInSession(lockedIn: false);

      expect(backlogRepo.completedTaskIds, isEmpty);
    });
  });

  group('MultiTargetPickerSheet Widget Tests', () {
    Widget buildSheet({int durationMinutes = 25}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<TimerNotifier>.value(value: timerNotifier),
          ChangeNotifierProvider<BacklogNotifier>.value(value: backlogNotifier),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MultiTargetPickerSheet(
              durationMinutes: durationMinutes,
            ),
          ),
        ),
      );
    }

    testWidgets('enforces strict cap of 3 targets with warning message', (tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      final addBtn = find.byTooltip('Add Target');

      // Add target 1
      await tester.enterText(inputField, 'Target 1');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Add target 2
      await tester.enterText(inputField, 'Target 2');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Add target 3
      await tester.enterText(inputField, 'Target 3');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Chip, 'Target 1'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Target 2'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Target 3'), findsOneWidget);

      // Attempt target 4
      await tester.enterText(inputField, 'Target 4');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Max 3 anchors to protect focus depth'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Target 4'), findsNothing);
    });

    testWidgets('shows sliders card when 2 targets exist and Equalize Split button resets split', (tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      final inputField = find.byType(TextField);
      final addBtn = find.byTooltip('Add Target');

      await tester.enterText(inputField, 'Design');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('TIME ALLOCATION'), findsNothing);

      await tester.enterText(inputField, 'Coding');
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('TIME ALLOCATION'), findsOneWidget);
      expect(find.text('Equalize Split'), findsOneWidget);

      await tester.tap(find.text('Equalize Split'));
      await tester.pumpAndSettle();

      expect(find.text('50% · 13m'), findsNWidgets(2));
    });
  });

  group('GoalAnchorPill and ActiveLockInBanner Widget Tests', () {
    testWidgets('GoalAnchorPill renders multi-target text correctly', (tester) async {
      const targets2 = [
        SessionTargetAllocation(targetName: 'Code', percentage: 70),
        SessionTargetAllocation(targetName: 'Review', percentage: 30),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalAnchorPill(
              goal: 'Code • Review',
              targets: targets2,
              isIdle: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Code (70%) • Review (30%)'), findsOneWidget);
    });

    testWidgets('ActiveLockInBanner displays targets with percentage pills', (tester) async {
      const targets = [
        SessionTargetAllocation(targetName: 'Frontend', percentage: 60, colorHex: '#00E5FF'),
        SessionTargetAllocation(targetName: 'Backend', percentage: 40, colorHex: '#FF4081'),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActiveLockInBanner(
              isPaused: false,
              targets: targets,
            ),
          ),
        ),
      );

      expect(find.text('Frontend'), findsOneWidget);
      expect(find.text('Backend'), findsOneWidget);
      expect(find.textContaining('60%'), findsOneWidget);
      expect(find.textContaining('40%'), findsOneWidget);
    });
  });
}
