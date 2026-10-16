import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
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
import 'package:focusmaxxing/features/timer/presentation/widgets/goal_input_dialog.dart';
import 'package:focusmaxxing/main_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSessionRepo implements ISessionRepository {
  String? lastStartedGoal;

  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async {
    lastStartedGoal = session.taskGoal;
    return const Right(10);
  }

  @override
  Future<Either<Failure, void>> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async =>
      const Right([]);
}

class _FakeNotificationService extends Fake implements NotificationService {
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

class _FakeInsightsRepo implements IInsightsRepository {
  @override
  Future<Either<Failure, DailySummaryEntity>> getDailySummary(
    DateTime date, {
    bool includeWeekendsInStreak = false,
  }) async =>
      Right(
        DailySummaryEntity(
          date: date,
          totalFocusMinutes: 0,
          completedSessionsCount: 0,
          currentStreakDays: 0,
        ),
      );

  @override
  Future<Either<Failure, List<SessionEntity>>> getRecentSessions({
    int days = 7,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, int>> calculateStreak({
    DateTime? referenceDate,
    bool includeWeekends = false,
  }) async =>
      const Right(0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSessionRepo sessionRepo;
  late _FakeNotificationService notificationService;
  late TimerNotifier timerNotifier;
  late InsightsNotifier insightsNotifier;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sessionRepo = _FakeSessionRepo();
    notificationService = _FakeNotificationService();
    timerNotifier = TimerNotifier(
      startSessionUseCase: StartSessionUseCase(sessionRepo),
      completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
      cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
      notificationService: notificationService,
    );
    final insightsRepo = _FakeInsightsRepo();
    insightsNotifier = InsightsNotifier(
      getDailySummaryUseCase: GetDailySummaryUseCase(insightsRepo),
      getRecentSessionsUseCase: GetRecentSessionsUseCase(insightsRepo),
      notificationService: notificationService,
    );
  });

  Widget buildTestApp({
    Future<Uri?>? initialUriFuture,
    Stream<Uri?>? uriStream,
    int initialIndex = 0,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TimerNotifier>.value(value: timerNotifier),
        ChangeNotifierProvider<InsightsNotifier>.value(value: insightsNotifier),
      ],
      child: MaterialApp(
        home: MainScaffold(
          initialIndex: initialIndex,
          widgetLaunchUriFuture: initialUriFuture,
          widgetLaunchUriStream: uriStream,
        ),
      ),
    );
  }

  testWidgets(
      'cold start with focusmaxxing://lockin launches GoalInputDialog and starts session',
      (tester) async {
    final completer = Completer<Uri?>()..complete(Uri.parse('focusmaxxing://lockin'));

    await tester.pumpWidget(
      buildTestApp(initialUriFuture: completer.future, initialIndex: 1),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GoalInputDialog), findsOneWidget);

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'Ship Widget Feature');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(timerNotifier.status, equals(TimerStatus.running));
    expect(timerNotifier.currentTaskGoal, equals('Ship Widget Feature'));

    timerNotifier.dispose();
  });

  testWidgets(
      'warm launch event focusmaxxing://lockin switches tab and opens GoalInputDialog',
      (tester) async {
    final streamController = StreamController<Uri?>.broadcast();
    addTearDown(streamController.close);

    await tester.pumpWidget(
      buildTestApp(uriStream: streamController.stream, initialIndex: 2),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GoalInputDialog), findsNothing);

    streamController.add(Uri.parse('focusmaxxing://lockin'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(GoalInputDialog), findsOneWidget);

    timerNotifier.dispose();
  });

  testWidgets(
      'does not reopen GoalInputDialog if timer is already running',
      (tester) async {
    final streamController = StreamController<Uri?>.broadcast();
    addTearDown(streamController.close);

    await timerNotifier.startFocusSession('Running Work');
    expect(timerNotifier.status, equals(TimerStatus.running));

    await tester.pumpWidget(
      buildTestApp(uriStream: streamController.stream, initialIndex: 1),
    );
    await tester.pumpAndSettle();

    streamController.add(Uri.parse('focusmaxxing://lockin'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(GoalInputDialog), findsNothing);

    timerNotifier.dispose();
  });

  testWidgets(
      'dismissing GoalInputDialog leaves timer idle and safely resets mutex for future clicks',
      (tester) async {
    final streamController = StreamController<Uri?>.broadcast();
    addTearDown(streamController.close);

    await tester.pumpWidget(
      buildTestApp(uriStream: streamController.stream, initialIndex: 0),
    );
    await tester.pumpAndSettle();

    // Trigger first launch
    streamController.add(Uri.parse('focusmaxxing://lockin'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(GoalInputDialog), findsOneWidget);

    // Dismiss dialog without entering a goal
    Navigator.of(tester.element(find.byType(GoalInputDialog))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(GoalInputDialog), findsNothing);
    expect(timerNotifier.status, equals(TimerStatus.idle));

    // Subsequent trigger should successfully open the modal again
    streamController.add(Uri.parse('focusmaxxing://lockin'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(GoalInputDialog), findsOneWidget);

    timerNotifier.dispose();
  });

  testWidgets('ignores non-lockin URIs without opening modal or disrupting tab',
      (tester) async {
    final streamController = StreamController<Uri?>.broadcast();
    addTearDown(streamController.close);

    await tester.pumpWidget(
      buildTestApp(uriStream: streamController.stream, initialIndex: 2),
    );
    await tester.pumpAndSettle();

    streamController.add(Uri.parse('focusmaxxing://other_route'));
    streamController.add(Uri.parse('https://google.com'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(GoalInputDialog), findsNothing);

    timerNotifier.dispose();
  });

  testWidgets('rapid consecutive duplicate clicks do not stack duplicate modals',
      (tester) async {
    final streamController = StreamController<Uri?>.broadcast();
    addTearDown(streamController.close);

    await tester.pumpWidget(
      buildTestApp(uriStream: streamController.stream, initialIndex: 0),
    );
    await tester.pumpAndSettle();

    // Send rapid burst of duplicate clicks
    streamController.add(Uri.parse('focusmaxxing://lockin'));
    streamController.add(Uri.parse('focusmaxxing://lockin'));
    streamController.add(Uri.parse('focusmaxxing://lockin'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Only one instance of GoalInputDialog should ever exist
    expect(find.byType(GoalInputDialog), findsOneWidget);

    timerNotifier.dispose();
  });
}
