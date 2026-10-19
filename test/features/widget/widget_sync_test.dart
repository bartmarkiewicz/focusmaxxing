import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
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
import 'package:focusmaxxing/features/widget/data/services/widget_sync_service_impl.dart';
import 'package:focusmaxxing/features/widget/domain/services/i_widget_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeWidgetSyncService implements IWidgetSyncService {
  int? lastTodayMinutes;
  int? lastActiveStreak;
  int updateCallCount = 0;

  @override
  Future<void> updateGlanceableWidget({
    required int todayMinutes,
    required int activeStreak,
  }) async {
    lastTodayMinutes = todayMinutes;
    lastActiveStreak = activeStreak;
    updateCallCount++;
  }
}

class FakeSessionRepository implements ISessionRepository {
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

class FakeInsightsRepository implements IInsightsRepository {
  DailySummaryEntity summaryToReturn;

  FakeInsightsRepository({required this.summaryToReturn});

  @override
  Future<Either<Failure, DailySummaryEntity>> getDailySummary(
    DateTime date, {
    bool includeWeekendsInStreak = false,
  }) async {
    return Right(summaryToReturn);
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getRecentSessions({
    int days = 7,
  }) async {
    return const Right([]);
  }

  @override
  Future<Either<Failure, int>> calculateStreak({
    DateTime? referenceDate,
    bool includeWeekends = false,
  }) async {
    return const Right(0);
  }
}

class FakeNotificationService extends Fake implements NotificationService {
  @override
  Future<void> cancelTimerNotification() async {}

  @override
  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
  }) async {}

  @override
  Future<void> scheduleSessionCompletionNotification({
    required DateTime targetEndTime,
    required String goal,
  }) async {}

  @override
  Future<void> cancelSessionCompletionNotification() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetSyncServiceImpl Unit Tests', () {
    test('pushes today_minutes and active_streak with GlanceableDialWidgetProvider target',
        () async {
      final savedData = <String, dynamic>{};
      final updateParams = <String, dynamic>{};

      final service = WidgetSyncServiceImpl(
        saveWidgetData: <T>(
          String id,
          T? data, {
          bool deleteFile = true,
          String? appGroupId,
        }) async {
          savedData[id] = data;
          return true;
        },
        updateWidget: ({
          String? name,
          String? androidName,
          String? iOSName,
          String? qualifiedAndroidName,
        }) async {
          updateParams['name'] = name;
          updateParams['androidName'] = androidName;
          updateParams['qualifiedAndroidName'] = qualifiedAndroidName;
          return true;
        },
      );

      await service.updateGlanceableWidget(
        todayMinutes: 75,
        activeStreak: 4,
      );

      expect(savedData['today_minutes'], equals(75));
      expect(savedData['active_streak'], equals(4));
      expect(updateParams['name'], equals('GlanceableDialWidgetProvider'));
      expect(
        updateParams['androidName'],
        equals('widget.GlanceableDialWidgetProvider'),
      );
      expect(
        updateParams['qualifiedAndroidName'],
        equals('com.bmrkiewicz.focusmaxxing.focusmaxxing.widget.GlanceableDialWidgetProvider'),
      );
    });

    test('handles PlatformException and MissingPluginException gracefully', () async {
      final service = WidgetSyncServiceImpl(
        saveWidgetData: <T>(
          String id,
          T? data, {
          bool deleteFile = true,
          String? appGroupId,
        }) async {
          throw PlatformException(code: 'CHANNEL_ERROR');
        },
      );

      expect(
        () => service.updateGlanceableWidget(todayMinutes: 25, activeStreak: 1),
        returnsNormally,
      );
    });
  });

  group('TimerNotifier Widget Sync Integration Tests', () {
    late FakeSessionRepository sessionRepository;
    late FakeNotificationService notificationService;
    late FakeWidgetSyncService widgetSyncService;
    late FakeInsightsRepository insightsRepository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      sessionRepository = FakeSessionRepository();
      notificationService = FakeNotificationService();
      widgetSyncService = FakeWidgetSyncService();
      insightsRepository = FakeInsightsRepository(
        summaryToReturn: DailySummaryEntity(
          date: DateTime.now(),
          totalFocusMinutes: 50,
          completedSessionsCount: 2,
          currentStreakDays: 3,
        ),
      );
    });

    test('dispatches updated today_minutes and active_streak to widget on checkInSession',
        () async {
      final timerNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        notificationService: notificationService,
        widgetSyncService: widgetSyncService,
        getDailySummaryUseCase: GetDailySummaryUseCase(insightsRepository),
      );

      await timerNotifier.startFocusSession('Test Goal');
      await timerNotifier.checkInSession(lockedIn: true);

      expect(widgetSyncService.updateCallCount, equals(1));
      expect(widgetSyncService.lastTodayMinutes, equals(50));
      expect(widgetSyncService.lastActiveStreak, equals(3));
    });

    test('falls back to session duration when getDailySummaryUseCase is null',
        () async {
      final timerNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        notificationService: notificationService,
        widgetSyncService: widgetSyncService,
      );

      timerNotifier.setDurationPreset(30 * 60);
      await timerNotifier.startFocusSession('30m Goal');
      await timerNotifier.checkInSession(lockedIn: true);

      expect(widgetSyncService.updateCallCount, equals(1));
      expect(widgetSyncService.lastTodayMinutes, equals(30));
      expect(widgetSyncService.lastActiveStreak, equals(1));
    });
  });

  group('InsightsNotifier Widget Sync Integration Tests', () {
    late FakeInsightsRepository insightsRepository;
    late FakeNotificationService notificationService;
    late FakeWidgetSyncService widgetSyncService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      insightsRepository = FakeInsightsRepository(
        summaryToReturn: DailySummaryEntity(
          date: DateTime.now(),
          totalFocusMinutes: 120,
          completedSessionsCount: 4,
          currentStreakDays: 7,
        ),
      );
      notificationService = FakeNotificationService();
      widgetSyncService = FakeWidgetSyncService();
    });

    test('dispatches today_minutes and active_streak to widget on loadInsights',
        () async {
      final insightsNotifier = InsightsNotifier(
        getDailySummaryUseCase: GetDailySummaryUseCase(insightsRepository),
        getRecentSessionsUseCase: GetRecentSessionsUseCase(insightsRepository),
        notificationService: notificationService,
        widgetSyncService: widgetSyncService,
      );

      await insightsNotifier.loadInsights();

      expect(widgetSyncService.updateCallCount, equals(1));
      expect(widgetSyncService.lastTodayMinutes, equals(120));
      expect(widgetSyncService.lastActiveStreak, equals(7));
    });
  });
}
