import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/insights/domain/repositories/i_insights_repository.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_daily_summary_usecase.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_recent_sessions_usecase.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockInsightsRepository implements IInsightsRepository {
  DailySummaryEntity? summaryToReturn;
  List<SessionEntity>? sessionsToReturn;
  Failure? summaryFailure;
  Failure? sessionsFailure;
  bool? capturedIncludeWeekends;

  @override
  Future<Either<Failure, DailySummaryEntity>> getDailySummary(
    DateTime date, {
    bool includeWeekendsInStreak = false,
  }) async {
    capturedIncludeWeekends = includeWeekendsInStreak;
    if (summaryFailure != null) return Left(summaryFailure!);
    return Right(
      summaryToReturn ??
          DailySummaryEntity(
            date: date,
            totalFocusMinutes: 50,
            completedSessionsCount: 2,
            currentStreakDays: 3,
          ),
    );
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getRecentSessions(
      {int days = 7}) async {
    if (sessionsFailure != null) return Left(sessionsFailure!);
    return Right(sessionsToReturn ?? const []);
  }

  @override
  Future<Either<Failure, int>> calculateStreak({
    DateTime? referenceDate,
    bool includeWeekends = false,
  }) async {
    return const Right(0);
  }
}

class _MockNotificationService extends NotificationService {
  bool didScheduleDailyReminder = false;
  bool didCancelDailyReminder = false;
  int? capturedHour;
  int? capturedMinute;

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = 'Time to Lock In 🚀',
    String body = 'Start your daily focus block and crush your goals.',
  }) async {
    didScheduleDailyReminder = true;
    capturedHour = hour;
    capturedMinute = minute;
  }

  @override
  Future<void> cancelDailyReminder() async {
    didCancelDailyReminder = true;
  }
}

void main() {
  late _MockInsightsRepository repository;
  late _MockNotificationService notificationService;
  late SharedPreferences prefs;
  late InsightsNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _MockInsightsRepository();
    notificationService = _MockNotificationService();

    notifier = InsightsNotifier(
      getDailySummaryUseCase: GetDailySummaryUseCase(repository),
      getRecentSessionsUseCase: GetRecentSessionsUseCase(repository),
      notificationService: notificationService,
      sharedPreferences: prefs,
    );
  });

  test('initial state loads preferences with sensible defaults', () {
    expect(notifier.isStreakEnabled, isTrue);
    expect(notifier.includeWeekendsInStreak, isFalse);
    expect(notifier.isDailyReminderEnabled, isFalse);
    expect(notifier.dailyReminderHour, 9);
    expect(notifier.dailyReminderMinute, 0);
    expect(notifier.dailySummary, isNull);
    expect(notifier.recentSessions, isEmpty);
    expect(notifier.isLoading, isFalse);
    expect(notifier.errorMessage, isNull);
  });

  test('loadInsights fetches summary and recent sessions successfully',
      () async {
    const session = SessionEntity(
      id: 1,
      taskGoal: 'Clean Architecture Test',
      sessionType: SessionType.focus,
      targetDurationSeconds: 1500,
      actualDurationSeconds: 1500,
      startTimeEpochMs: 1000,
      endTimeEpochMs: 2500,
      status: SessionStatus.lockedIn,
    );
    repository.sessionsToReturn = [session];

    await notifier.loadInsights();

    expect(notifier.isLoading, isFalse);
    expect(notifier.errorMessage, isNull);
    expect(notifier.dailySummary?.totalFocusMinutes, 50);
    expect(notifier.recentSessions.length, 1);
  });

  test('loadInsights sets errorMessage on use case failure', () async {
    repository.summaryFailure = const DatabaseFailure('DB read failed');

    await notifier.loadInsights();

    expect(notifier.isLoading, isFalse);
    expect(notifier.errorMessage, 'DB read failed');
  });

  test('setStreakEnabled updates state and persists to SharedPreferences',
      () async {
    await notifier.setStreakEnabled(false);

    expect(notifier.isStreakEnabled, isFalse);
    expect(prefs.getBool(InsightsNotifier.keyStreakEnabled), isFalse);

    await notifier.setStreakEnabled(true);

    expect(notifier.isStreakEnabled, isTrue);
    expect(prefs.getBool(InsightsNotifier.keyStreakEnabled), isTrue);
  });

  test('setIncludeWeekendsInStreak persists and reloads insights', () async {
    await notifier.setIncludeWeekendsInStreak(true);

    expect(notifier.includeWeekendsInStreak, isTrue);
    expect(prefs.getBool(InsightsNotifier.keyIncludeWeekends), isTrue);
    expect(repository.capturedIncludeWeekends, isTrue);
  });

  test('setDailyReminderEnabled toggles notification scheduling and persists',
      () async {
    await notifier.setDailyReminderEnabled(true);

    expect(notifier.isDailyReminderEnabled, isTrue);
    expect(notificationService.didScheduleDailyReminder, isTrue);
    expect(prefs.getBool(InsightsNotifier.keyDailyReminderEnabled), isTrue);

    await notifier.setDailyReminderEnabled(false);

    expect(notifier.isDailyReminderEnabled, isFalse);
    expect(notificationService.didCancelDailyReminder, isTrue);
    expect(prefs.getBool(InsightsNotifier.keyDailyReminderEnabled), isFalse);
  });

  test('setDailyReminderTime updates time, persists, and reschedules if active',
      () async {
    await notifier.setDailyReminderEnabled(true);
    notificationService.didScheduleDailyReminder = false;

    await notifier.setDailyReminderTime(10, 30);

    expect(notifier.dailyReminderHour, 10);
    expect(notifier.dailyReminderMinute, 30);
    expect(prefs.getInt(InsightsNotifier.keyDailyReminderHour), 10);
    expect(prefs.getInt(InsightsNotifier.keyDailyReminderMinute), 30);
    expect(notificationService.didScheduleDailyReminder, isTrue);
    expect(notificationService.capturedHour, 10);
    expect(notificationService.capturedMinute, 30);
  });
}
