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
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/insights/domain/repositories/i_insights_repository.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_daily_summary_usecase.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_recent_sessions_usecase.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/main_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSessionRepo implements ISessionRepository {
  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async =>
      const Right(1);

  @override
  Future<Either<Failure, void>> updateSessionStatus(
          int id, String status, int duration) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
          int start, int end) async =>
      const Right([]);
}

class _FakeBacklogRepo implements IBacklogRepository {
  @override
  Future<Either<Failure, List<BacklogTaskEntity>>> getPendingTasks() async =>
      const Right([]);

  @override
  Future<Either<Failure, int>> addTask(String title) async => const Right(1);

  @override
  Future<Either<Failure, void>> deleteTask(int id) async => const Right(null);

  @override
  Future<Either<Failure, void>> markCompleted(int id, [int? sessionId]) async =>
      const Right(null);
}

class _FakeInsightsRepo implements IInsightsRepository {
  @override
  Future<Either<Failure, DailySummaryEntity>> getDailySummary(DateTime date,
          {bool includeWeekendsInStreak = false}) async =>
      Right(
        DailySummaryEntity(
          date: date,
          totalFocusMinutes: 0,
          completedSessionsCount: 0,
          currentStreakDays: 0,
        ),
      );

  @override
  Future<Either<Failure, List<SessionEntity>>> getRecentSessions(
          {int days = 7}) async =>
      const Right([]);

  @override
  Future<Either<Failure, int>> calculateStreak(
          {DateTime? referenceDate, bool includeWeekends = false}) async =>
      const Right(0);
}

void main() {
  late TimerNotifier timerNotifier;
  late BacklogNotifier backlogNotifier;
  late InsightsNotifier insightsNotifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sessionRepo = _FakeSessionRepo();
    final backlogRepo = _FakeBacklogRepo();
    final insightsRepo = _FakeInsightsRepo();

    timerNotifier = TimerNotifier(
      startSessionUseCase: StartSessionUseCase(sessionRepo),
      completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
      cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
      notificationService: NotificationService(),
      prefs: prefs,
    );

    backlogNotifier = BacklogNotifier(
      getPendingTasksUseCase: GetPendingTasksUseCase(backlogRepo),
      addBacklogTaskUseCase: AddBacklogTaskUseCase(backlogRepo),
      deleteBacklogTaskUseCase: DeleteBacklogTaskUseCase(backlogRepo),
      markTaskCompletedUseCase: MarkTaskCompletedUseCase(backlogRepo),
    );

    insightsNotifier = InsightsNotifier(
      getDailySummaryUseCase: GetDailySummaryUseCase(insightsRepo),
      getRecentSessionsUseCase: GetRecentSessionsUseCase(insightsRepo),
      notificationService: NotificationService(),
      sharedPreferences: prefs,
    );
  });

  Widget buildWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TimerNotifier>.value(value: timerNotifier),
        ChangeNotifierProvider<BacklogNotifier>.value(value: backlogNotifier),
        ChangeNotifierProvider<InsightsNotifier>.value(value: insightsNotifier),
      ],
      child: const MaterialApp(
        home: MainScaffold(),
      ),
    );
  }

  testWidgets('renders 3 navigation destinations and switches tabs',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('FOCUSMAXXING'), findsOneWidget);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Shield'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);

    await tester.tap(find.text('Shield'));
    await tester.pumpAndSettle();

    expect(find.text('Brainrot Shield'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('Insights & Settings'), findsOneWidget);

    await tester.tap(find.text('Timer'));
    await tester.pumpAndSettle();

    expect(find.text('FOCUSMAXXING'), findsOneWidget);
  });
}
