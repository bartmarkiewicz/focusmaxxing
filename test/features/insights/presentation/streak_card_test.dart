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
import 'package:focusmaxxing/features/insights/presentation/widgets/streak_card.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeInsightsRepository implements IInsightsRepository {
  @override
  Future<Either<Failure, DailySummaryEntity>> getDailySummary(
    DateTime date, {
    bool includeWeekendsInStreak = false,
  }) async {
    return Right(
      DailySummaryEntity(
        date: date,
        totalFocusMinutes: 25,
        completedSessionsCount: 1,
        currentStreakDays: 5,
      ),
    );
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getRecentSessions({int days = 7}) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, int>> calculateStreak({
    DateTime? referenceDate,
    bool includeWeekends = false,
  }) async {
    return const Right(5);
  }
}

void main() {
  late _FakeInsightsRepository repository;
  late InsightsNotifier notifier;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _FakeInsightsRepository();
    notifier = InsightsNotifier(
      getDailySummaryUseCase: GetDailySummaryUseCase(repository),
      getRecentSessionsUseCase: GetRecentSessionsUseCase(repository),
      notificationService: NotificationService(),
      sharedPreferences: prefs,
    );
  });

  Widget buildWidget(int streakDays) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<InsightsNotifier>.value(
          value: notifier,
          child: StreakCard(streakDays: streakDays),
        ),
      ),
    );
  }

  testWidgets('renders active streak and switches when enabled', (tester) async {
    await tester.pumpWidget(buildWidget(5));

    expect(find.text('CURRENT STREAK: 5 DAYS'), findsOneWidget);
    expect(find.text('Streak Tracking'), findsOneWidget);
    expect(find.text('Include Weekends in Streak'), findsOneWidget);
  });

  testWidgets('renders singular DAY when streak is 1', (tester) async {
    await tester.pumpWidget(buildWidget(1));

    expect(find.text('CURRENT STREAK: 1 DAY'), findsOneWidget);
  });

  testWidgets('renders zero-guilt hidden state when streak tracking is disabled',
      (tester) async {
    await notifier.setStreakEnabled(false);
    await tester.pumpWidget(buildWidget(5));

    expect(find.text('Streak Tracking Hidden'), findsOneWidget);
    expect(find.text('CURRENT STREAK: 5 DAYS'), findsNothing);
    expect(find.text('Include Weekends in Streak'), findsNothing);
  });

  testWidgets('toggling switch updates notifier state', (tester) async {
    await tester.pumpWidget(buildWidget(3));

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));

    await tester.tap(switches.first);
    await tester.pumpAndSettle();

    expect(notifier.isStreakEnabled, isFalse);
  });
}
