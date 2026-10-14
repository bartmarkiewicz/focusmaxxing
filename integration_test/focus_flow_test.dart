import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/features/backlog/data/datasources/backlog_local_data_source.dart';
import 'package:focusmaxxing/features/backlog/data/repositories/backlog_repository_impl.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/add_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/delete_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/get_pending_tasks_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/backlog_task_item.dart';
import 'package:focusmaxxing/features/insights/data/repositories/insights_repository_impl.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_daily_summary_usecase.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_recent_sessions_usecase.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:focusmaxxing/features/timer/data/datasources/session_local_data_source.dart';
import 'package:focusmaxxing/features/timer/data/repositories/session_repository_impl.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/hold_to_cancel_button.dart';
import 'package:focusmaxxing/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SpyNotificationService extends NotificationService {
  String? lastShownGoal;
  String? lastFormattedTime;
  bool isTimerCancelled = false;
  bool isOngoingActive = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
  }) async {
    lastShownGoal = taskGoal;
    lastFormattedTime = formattedTimeRemaining;
    isOngoingActive = !isPaused;
    isTimerCancelled = false;
  }

  @override
  Future<void> cancelTimerNotification() async {
    isTimerCancelled = true;
    isOngoingActive = false;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = 'Time to Lock In 🚀',
    String body = 'Start your daily focus block and crush your goals.',
  }) async {}

  @override
  Future<void> cancelDailyReminder() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late SpyNotificationService notificationSpy;
  late SharedPreferences sharedPreferences;
  late TimerNotifier timerNotifier;
  late BacklogNotifier backlogNotifier;
  late InsightsNotifier insightsNotifier;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPreferences = await SharedPreferences.getInstance();

    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final migrationRunner = MigrationRunner(migrations: const [MigrationV1()]);
    await migrationRunner.run(db, oldVersion: 0, targetVersion: 1);
    DatabaseHelper.setMockDatabase(db);

    notificationSpy = SpyNotificationService();

    final sessionDataSource = SessionLocalDataSource();
    final backlogDataSource = BacklogLocalDataSource();

    final sessionRepo =
        SessionRepositoryImpl(localDataSource: sessionDataSource);
    final backlogRepo =
        BacklogRepositoryImpl(localDataSource: backlogDataSource);
    final insightsRepo =
        InsightsRepositoryImpl(localDataSource: sessionDataSource);

    final markTaskCompleted = MarkTaskCompletedUseCase(backlogRepo);

    timerNotifier = TimerNotifier(
      startSessionUseCase: StartSessionUseCase(sessionRepo),
      completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
      cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
      notificationService: notificationSpy,
      markTaskCompletedUseCase: markTaskCompleted,
      prefs: sharedPreferences,
    );

    backlogNotifier = BacklogNotifier(
      getPendingTasksUseCase: GetPendingTasksUseCase(backlogRepo),
      addBacklogTaskUseCase: AddBacklogTaskUseCase(backlogRepo),
      deleteBacklogTaskUseCase: DeleteBacklogTaskUseCase(backlogRepo),
      markTaskCompletedUseCase: markTaskCompleted,
    );

    insightsNotifier = InsightsNotifier(
      getDailySummaryUseCase: GetDailySummaryUseCase(insightsRepo),
      getRecentSessionsUseCase: GetRecentSessionsUseCase(insightsRepo),
      notificationService: notificationSpy,
      sharedPreferences: sharedPreferences,
    );
  });

  tearDown(() async {
    timerNotifier.dispose();
    backlogNotifier.dispose();
    insightsNotifier.dispose();
    await DatabaseHelper.instance.close();
    DatabaseHelper.setMockDatabase(null);
  });

  Widget buildApp() {
    return FocusmaxxingApp(
      timerNotifier: timerNotifier,
      backlogNotifier: backlogNotifier,
      insightsNotifier: insightsNotifier,
    );
  }

  group('Focusmaxxing End-to-End Integration Flow', () {
    testWidgets(
      'Scenario 1: Full Focus Cycle -> Start, Complete Session, Check-In and Verify Insights',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text('FOCUSMAXXING'), findsOneWidget);
        expect(find.text('25:00'), findsOneWidget);
        expect(find.text('🚀 LOCK IN'), findsOneWidget);

        timerNotifier.setDurationPreset(1);
        await tester.pumpAndSettle();
        expect(find.text('00:01'), findsOneWidget);

        await tester.tap(find.text('🚀 LOCK IN'));
        await tester.pumpAndSettle();

        expect(find.text('What ONE thing are you locking in on?'), findsOneWidget);

        final goalInput = find.byType(TextField);
        await tester.enterText(goalInput, 'Finish clean architecture');
        await tester.pumpAndSettle();

        await tester.tap(find.text('START FOCUS (0m)'));
        await tester.pumpAndSettle();

        expect(timerNotifier.status, TimerStatus.running);
        expect(find.text('Finish clean architecture'), findsWidgets);
        expect(find.text('PAUSE FOCUS'), findsOneWidget);
        expect(notificationSpy.lastShownGoal, 'Finish clean architecture');
        expect(notificationSpy.isOngoingActive, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.text('Did you lock in?'), findsOneWidget);
        expect(find.text('LOCKED IN 🚀'), findsOneWidget);
        expect(find.text('DERAILED 💀'), findsOneWidget);

        await tester.tap(find.text('LOCKED IN 🚀'));
        await tester.pumpAndSettle();

        expect(notificationSpy.isTimerCancelled, isTrue);
        expect(timerNotifier.status, TimerStatus.breakRunning);
        expect(find.text('I\'M READY TO FOCUS'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.insights_outlined));
        await tester.pumpAndSettle();

        expect(find.text('TODAY\'S MOMENTUM'), findsOneWidget);
        expect(find.text('CURRENT STREAK'), findsOneWidget);
        expect(find.textContaining('CURRENT STREAK: 1 DAY'), findsOneWidget);
        expect(find.text('Finish clean architecture'), findsOneWidget);
        expect(find.text('Locked In'), findsOneWidget);
        expect(find.text('🚀'), findsWidgets);
      },
    );

    testWidgets(
      'Scenario 2: Hold-to-Cancel Verification -> Quick tap prompts warning, 5s hold cancels session',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('🚀 LOCK IN'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('⚡ Deep Work'));
        await tester.pumpAndSettle();

        expect(timerNotifier.status, TimerStatus.running);
        expect(find.text('PAUSE FOCUS'), findsOneWidget);

        await tester.tap(find.text('PAUSE FOCUS'));
        await tester.pumpAndSettle();

        expect(timerNotifier.status, TimerStatus.paused);
        expect(find.text('RESUME FOCUS'), findsOneWidget);
        expect(find.byType(HoldToCancelButton), findsOneWidget);

        await tester.tap(find.byType(HoldToCancelButton));
        await tester.pump();

        expect(find.text('Hold for 5 full seconds to cancel session'), findsOneWidget);
        expect(timerNotifier.status, TimerStatus.paused);

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(HoldToCancelButton)),
        );

        await Future<void>.delayed(const Duration(milliseconds: 5300));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(timerNotifier.status, TimerStatus.idle);
        expect(find.text('🚀 LOCK IN'), findsOneWidget);
        expect(notificationSpy.isTimerCancelled, isTrue);
      },
    );

    testWidgets(
      'Scenario 3: Backlog Scratchpad -> Add task, promote to anchor, complete session & auto-checkoff',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.inbox_outlined));
        await tester.pumpAndSettle();

        expect(find.text('Backlog (Focus Scratchpad)'), findsOneWidget);

        final taskInput = find.widgetWithText(TextField, 'Add next task...');
        await tester.enterText(taskInput, 'Write system architecture doc');
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add_circle));
        await tester.pumpAndSettle();

        expect(find.text('Write system architecture doc'), findsOneWidget);

        await tester.tap(find.text('Write system architecture doc'));
        await tester.pumpAndSettle();

        expect(find.text('Backlog (Focus Scratchpad)'), findsNothing);
        expect(find.text('Write system architecture doc'), findsWidgets);
        expect(timerNotifier.currentTaskGoal, 'Write system architecture doc');
        expect(timerNotifier.linkedBacklogTaskId, isNotNull);

        // Run session with linked backlog task and verify auto-completion checkoff
        timerNotifier.setDurationPreset(1);
        await tester.pumpAndSettle();

        await tester.tap(find.text('🚀 LOCK IN'));
        await tester.pumpAndSettle();

        await Future<void>.delayed(const Duration(milliseconds: 1200));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        await tester.tap(find.text('LOCKED IN 🚀'));
        await tester.pumpAndSettle();

        // Verify task was auto-completed and is no longer pending in backlog
        await tester.tap(find.byIcon(Icons.inbox_outlined));
        await tester.pumpAndSettle();

        expect(find.byType(BacklogTaskItem), findsNothing);
        expect(find.textContaining('Scratchpad is clear'), findsOneWidget);
      },
    );
  });
}
