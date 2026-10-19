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
import 'package:focusmaxxing/features/insights/presentation/pages/insights_page.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeInsightsRepository implements IInsightsRepository {
  bool didLoadSummary = false;
  Failure? failureToReturn;

  @override
  Future<Either<Failure, DailySummaryEntity>> getDailySummary(
    DateTime date, {
    bool includeWeekendsInStreak = false,
  }) async {
    didLoadSummary = true;
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right(
      DailySummaryEntity(
        date: date,
        totalFocusMinutes: 75,
        completedSessionsCount: 3,
        currentStreakDays: 4,
      ),
    );
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getRecentSessions({int days = 7}) async {
    if (failureToReturn != null) return Left(failureToReturn!);
    return Right([
      SessionEntity(
        id: 1,
        taskGoal: 'Implement Insights Page',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime.now().millisecondsSinceEpoch,
        endTimeEpochMs: DateTime.now().millisecondsSinceEpoch + 1500000,
        status: SessionStatus.lockedIn,
      ),
    ]);
  }

  @override
  Future<Either<Failure, int>> calculateStreak({
    DateTime? referenceDate,
    bool includeWeekends = false,
  }) async {
    return const Right(4);
  }
}

void main() {
  late _FakeInsightsRepository repository;
  late InsightsNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = _FakeInsightsRepository();
    notifier = InsightsNotifier(
      getDailySummaryUseCase: GetDailySummaryUseCase(repository),
      getRecentSessionsUseCase: GetRecentSessionsUseCase(repository),
      notificationService: NotificationService(),
      sharedPreferences: prefs,
    );
  });

  Widget buildWidget() {
    return MaterialApp(
      home: ChangeNotifierProvider<InsightsNotifier>.value(
        value: notifier,
        child: const InsightsPage(),
      ),
    );
  }

  testWidgets('renders all sections and loads insights on post-frame',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('Insights & Settings'), findsOneWidget);
    expect(find.text("TODAY'S MOMENTUM"), findsOneWidget);
    expect(find.text('75 MINS'), findsOneWidget);
    expect(find.text('Locked In Today'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Sessions Finished'), findsOneWidget);

    expect(find.text('CURRENT STREAK'), findsOneWidget);
    expect(find.text('CURRENT STREAK: 4 DAYS'), findsOneWidget);

    expect(find.text('RECENT SESSIONS'), findsOneWidget);
    expect(find.text('Implement Insights Page'), findsOneWidget);

    expect(find.text('CONFIG & PREFERENCES'), findsOneWidget);
    expect(find.text('Daily Focus Reminder'), findsOneWidget);
    expect(find.text('Ambient Audio'), findsNothing);
    expect(find.text('Timer Intervals'), findsNothing);

    expect(find.text('LIFETIME PRO: ACTIVE'), findsOneWidget);
  });

  testWidgets('renders error state with retry button when initial load fails',
      (tester) async {
    repository.failureToReturn = const DatabaseFailure('Database connection lost');

    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('Unable to load insights'), findsOneWidget);
    expect(find.text('Database connection lost'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);

    // Tapping retry re-fetches
    repository.failureToReturn = null;
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(find.text("TODAY'S MOMENTUM"), findsOneWidget);
    expect(find.text('75 MINS'), findsOneWidget);
  });
}
