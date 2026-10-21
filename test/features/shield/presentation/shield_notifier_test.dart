import 'dart:async';
import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/core/constants/schedule_constants.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:focusmaxxing/features/schedule/domain/repositories/i_schedule_repository.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/check_schedule_active_now_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/check_shield_permissions_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_installed_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_shielded_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/request_permission_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/sync_shield_with_overlay_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/toggle_shield_app_usecase.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeShieldRepository implements IShieldRepository {
  final Map<String, ShieldedAppEntity> savedApps = {};
  List<ShieldedAppEntity> installedApps = [];
  ShieldPermissionStatus permissionStatus =
      const ShieldPermissionStatus.allGranted();
  final List<List<String>> startedPackagesHistory = [];
  int stopShieldCallCount = 0;
  int bringToForegroundCount = 0;
  final List<Map<String, dynamic>> syncedOverlayPayloads = [];
  // ignore: close_sinks
  final StreamController<dynamic> overlayController =
      StreamController<dynamic>.broadcast();

  @override
  Stream<dynamic> get overlayEvents => overlayController.stream;

  @override
  Future<Either<Failure, List<ShieldedAppEntity>>> getShieldedApps() async {
    return Right(savedApps.values.toList());
  }

  @override
  Future<Either<Failure, List<ShieldedAppEntity>>> getInstalledApps() async {
    return Right(installedApps);
  }

  @override
  Future<Either<Failure, ShieldedAppEntity>> toggleShieldApp({
    required String packageName,
    required String appName,
    required bool isActive,
    bool isPreset = false,
    Uint8List? iconBytes,
  }) async {
    final entity = ShieldedAppEntity(
      packageName: packageName,
      appName: appName,
      iconBytes: iconBytes,
      isActive: isActive,
      isPreset: isPreset,
      createdAt: DateTime.utc(2026, 10, 16),
    );
    savedApps[packageName] = entity;
    return Right(entity);
  }

  @override
  Future<Either<Failure, void>> swapShieldApp({
    required String deactivatePackageName,
    required String activatePackageName,
    required String activateAppName,
    bool activateIsPreset = false,
  }) async {
    final existing = savedApps[deactivatePackageName];
    if (existing != null) {
      savedApps[deactivatePackageName] = existing.copyWith(isActive: false);
    }
    savedApps[activatePackageName] = ShieldedAppEntity(
      packageName: activatePackageName,
      appName: activateAppName,
      isActive: true,
      isPreset: activateIsPreset,
      createdAt: DateTime.utc(2026, 10, 16),
    );
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> purgeUninstalledApps(
    Set<String> installedPackages,
  ) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, ShieldPermissionStatus>> checkPermissions() async {
    return Right(permissionStatus);
  }

  @override
  Future<Either<Failure, bool>> requestPermission(
    ShieldPermissionType permissionType,
  ) async {
    return const Right(true);
  }

  bool? lastStartIsScheduled;
  String? lastStartTimeRange;

  @override
  Future<Either<Failure, bool>> startShieldService(
    List<String> blockedPackages, {
    bool isScheduled = false,
    String? timeRange,
  }) async {
    lastStartIsScheduled = isScheduled;
    lastStartTimeRange = timeRange;
    startedPackagesHistory.add(List<String>.from(blockedPackages));
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> stopShieldService() async {
    stopShieldCallCount++;
    return const Right(true);
  }

  @override
  Future<Either<Failure, void>> syncOverlayState({
    required String goal,
    required int remainingSeconds,
    required bool isBreak,
    bool isMaximumFocus = false,
    bool isPaused = false,
    int? targetEndTimeEpochMs,
  }) async {
    syncedOverlayPayloads.add({
      'goal': goal,
      'remainingSeconds': remainingSeconds,
      'isBreak': isBreak,
      'isMaximumFocus': isMaximumFocus,
      if (isPaused) 'isPaused': true,
      if (targetEndTimeEpochMs != null)
        'targetEndTimeEpochMs': targetEndTimeEpochMs,
    });
    return const Right(null);
  }

  @override
  Future<Either<Failure, bool>> bringAppToForeground() async {
    bringToForegroundCount++;
    return const Right(true);
  }
}

class _FakeSessionRepository implements ISessionRepository {
  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async =>
      const Right(1);

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

class _NoOpNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
  }) async {}

  @override
  Future<void> cancelTimerNotification() async {}

  @override
  Future<void> scheduleSessionCompletionNotification({
    required DateTime targetEndTime,
    required String goal,
  }) async {}

  @override
  Future<void> cancelSessionCompletionNotification() async {}
}

class _ControllableTimerNotifier extends TimerNotifier {
  _ControllableTimerNotifier({
    required super.startSessionUseCase,
    required super.completeSessionUseCase,
    required super.cancelSessionUseCase,
    required super.notificationService,
    super.prefs,
  });

  TimerStatus? overrideStatus;
  int? overrideRemainingSeconds;

  @override
  TimerStatus get status => overrideStatus ?? super.status;

  @override
  int get remainingSeconds =>
      overrideRemainingSeconds ?? super.remainingSeconds;
}

void main() {
  late _FakeShieldRepository repository;
  late SharedPreferences prefs;
  late ShieldNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _FakeShieldRepository();
    repository.installedApps = [
      ShieldedAppEntity(
        packageName: 'com.discord',
        appName: 'Discord',
        isActive: false,
        createdAt: DateTime.utc(2026, 10, 16),
      ),
      ShieldedAppEntity(
        packageName: 'com.android.chrome',
        appName: 'Google Chrome',
        isActive: false,
        isPreset: true,
        createdAt: DateTime.utc(2026, 10, 16),
      ),
      ShieldedAppEntity(
        packageName: 'com.spotify.music',
        appName: 'Spotify',
        isActive: false,
        createdAt: DateTime.utc(2026, 10, 16),
      ),
    ];

    notifier = ShieldNotifier(
      getShieldedAppsUseCase: GetShieldedAppsUseCase(repository),
      getInstalledAppsUseCase: GetInstalledAppsUseCase(repository),
      toggleShieldAppUseCase: ToggleShieldAppUseCase(repository),
      checkShieldPermissionsUseCase: CheckShieldPermissionsUseCase(repository),
      requestPermissionUseCase: RequestPermissionUseCase(repository),
      syncShieldWithOverlayUseCase: SyncShieldWithOverlayUseCase(repository),
      repository: repository,
      sharedPreferences: prefs,
      autoInitialize: false,
    );
    await notifier.refresh();
  });

  tearDown(() async {
    notifier.dispose();
    await repository.overlayController.close();
  });

  group('ShieldNotifierTest', () {
    test('adding apps up to the 2-app free cap succeeds', () async {
      final firstResult = await notifier.toggleApp(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isPreset: true,
      );
      final secondResult = await notifier.toggleApp(
        packageName: 'com.zhiliaoapp.musically',
        appName: 'TikTok',
        isPreset: true,
      );

      expect(firstResult, ShieldToggleResult.toggled);
      expect(secondResult, ShieldToggleResult.toggled);
      expect(notifier.activeAppCount, 2);
      expect(notifier.isPackageActive('com.instagram.android'), isTrue);
      expect(notifier.isPackageActive('com.zhiliaoapp.musically'), isTrue);
      expect(notifier.requiresUpgradePrompt, isFalse);
    });

    test(
      'attempting to toggle a 3rd app on the Free tier emits upgrade event and rejects activation',
      () async {
        await notifier.toggleApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isPreset: true,
        );
        await notifier.toggleApp(
          packageName: 'com.zhiliaoapp.musically',
          appName: 'TikTok',
          isPreset: true,
        );

        final emittedCandidates = <ShieldedAppEntity>[];
        final sub = notifier.upgradeEvents.listen(emittedCandidates.add);

        final thirdResult = await notifier.toggleApp(
          packageName: 'com.reddit.frontpage',
          appName: 'Reddit',
          isPreset: true,
        );
        await Future<void>.delayed(Duration.zero);

        expect(thirdResult, ShieldToggleResult.upgradeRequired);
        expect(notifier.activeAppCount, 2);
        expect(notifier.isPackageActive('com.reddit.frontpage'), isFalse);
        expect(notifier.requiresUpgradePrompt, isTrue);
        expect(
          notifier.pendingSwapCandidate?.packageName,
          'com.reddit.frontpage',
        );
        expect(emittedCandidates.length, 1);
        expect(emittedCandidates.first.appName, 'Reddit');

        await sub.cancel();
      },
    );

    test(
      'swapFreeApp replaces selected active app with pending candidate without payment',
      () async {
        await notifier.toggleApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isPreset: true,
        );
        await notifier.toggleApp(
          packageName: 'com.zhiliaoapp.musically',
          appName: 'TikTok',
          isPreset: true,
        );
        await notifier.toggleApp(
          packageName: 'com.reddit.frontpage',
          appName: 'Reddit',
          isPreset: true,
        );

        final swapped = await notifier.swapFreeApp(
          deactivatePackageName: 'com.instagram.android',
        );

        expect(swapped, isTrue);
        expect(notifier.activeAppCount, 2);
        expect(notifier.isPackageActive('com.instagram.android'), isFalse);
        expect(notifier.isPackageActive('com.zhiliaoapp.musically'), isTrue);
        expect(notifier.isPackageActive('com.reddit.frontpage'), isTrue);
        expect(notifier.requiresUpgradePrompt, isFalse);
        expect(notifier.pendingSwapCandidate, isNull);
      },
    );

    test(
      'activating Pro status lifts the 2-app limit and allows unlimited app selections',
      () async {
        await notifier.toggleApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isPreset: true,
        );
        await notifier.toggleApp(
          packageName: 'com.zhiliaoapp.musically',
          appName: 'TikTok',
          isPreset: true,
        );
        await notifier.toggleApp(
          packageName: 'com.reddit.frontpage',
          appName: 'Reddit',
          isPreset: true,
        );

        await notifier.unlockLifetimePro();

        expect(notifier.isPro, isTrue);
        expect(prefs.getBool(ShieldNotifier.proUnlockedPrefsKey), isTrue);
        expect(notifier.activeAppCount, 3);
        expect(notifier.isPackageActive('com.reddit.frontpage'), isTrue);

        final fourthResult = await notifier.toggleApp(
          packageName: 'com.twitter.android',
          appName: 'Twitter / X',
          isPreset: true,
        );
        expect(fourthResult, ShieldToggleResult.toggled);
        expect(notifier.activeAppCount, 4);
      },
    );

    test(
      'search query filtering correctly filters allInstalledApps by app title and package name',
      () {
        expect(notifier.filteredInstalledApps.length, 3);

        notifier.setSearchQuery('chrom');
        expect(notifier.filteredInstalledApps.length, 1);
        expect(
          notifier.filteredInstalledApps.first.appName,
          'Google Chrome',
        );

        notifier.setSearchQuery('com.discord');
        expect(notifier.filteredInstalledApps.length, 1);
        expect(notifier.filteredInstalledApps.first.appName, 'Discord');

        notifier.setSearchQuery('');
        expect(notifier.filteredInstalledApps.length, 3);
      },
    );

    test(
      'syncWithTimer starts service on focus, syncs break mode, holds lock at 00:00 break expiry, and stops on idle',
      () async {
        await notifier.toggleApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isPreset: true,
        );

        final sessionRepo = _FakeSessionRepository();
        final timerNotifier = _ControllableTimerNotifier(
          startSessionUseCase: StartSessionUseCase(sessionRepo),
          completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
          cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
          notificationService: _NoOpNotificationService(),
          prefs: prefs,
        );

        await timerNotifier.startFocusSession('Write unit tests');
        await notifier.syncWithTimer(timerNotifier);

        expect(notifier.isSessionShieldActive, isTrue);
        expect(
          repository.startedPackagesHistory.last,
          equals(['com.instagram.android']),
        );
        expect(
          repository.syncedOverlayPayloads.last['goal'],
          'Write unit tests',
        );
        expect(repository.syncedOverlayPayloads.last['isBreak'], isFalse);

        await timerNotifier.checkInSession(lockedIn: true);
        await notifier.syncWithTimer(timerNotifier);

        expect(timerNotifier.status, TimerStatus.breakRunning);
        expect(notifier.isSessionShieldActive, isTrue);
        expect(repository.syncedOverlayPayloads.last['isBreak'], isTrue);

        timerNotifier.overrideStatus = TimerStatus.breakCompleted;
        timerNotifier.overrideRemainingSeconds = 0;
        await notifier.syncWithTimer(timerNotifier);

        expect(timerNotifier.status, TimerStatus.breakCompleted);
        expect(notifier.isSessionShieldActive, isTrue);
        expect(repository.stopShieldCallCount, 0);
        expect(
          repository.syncedOverlayPayloads.last,
          equals({
            'goal': 'Write unit tests',
            'remainingSeconds': 0,
            'isBreak': true,
            'isMaximumFocus': false,
            'targetEndTimeEpochMs':
                timerNotifier.targetEndTime?.millisecondsSinceEpoch,
          }),
        );

        timerNotifier.overrideStatus = null;
        timerNotifier.overrideRemainingSeconds = null;
        timerNotifier.readyToFocusFromBreak();
        await notifier.syncWithTimer(timerNotifier);

        expect(timerNotifier.status, TimerStatus.idle);
        expect(notifier.isSessionShieldActive, isFalse);
        expect(repository.stopShieldCallCount, 1);

        timerNotifier.dispose();
      },
    );

    test(
      'toggling apps mid-session starts and stops native shield service even if session started with 0 apps',
      () async {
        final sessionRepo = _FakeSessionRepository();
        final timerNotifier = _ControllableTimerNotifier(
          startSessionUseCase: StartSessionUseCase(sessionRepo),
          completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
          cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
          notificationService: _NoOpNotificationService(),
          prefs: prefs,
        );

        await timerNotifier.startFocusSession('Mid-session test');
        await notifier.syncWithTimer(timerNotifier);

        expect(notifier.isSessionShieldActive, isTrue);
        expect(repository.startedPackagesHistory, isEmpty);

        await notifier.toggleApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isPreset: true,
        );
        expect(
          repository.startedPackagesHistory.last,
          equals(['com.instagram.android']),
        );

        final stopCountBeforeUncheck = repository.stopShieldCallCount;
        await notifier.toggleApp(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isPreset: true,
        );
        expect(
          repository.stopShieldCallCount,
          greaterThan(stopCountBeforeUncheck),
        );

        await notifier.toggleApp(
          packageName: 'com.zhiliaoapp.musically',
          appName: 'TikTok',
          isPreset: true,
        );
        expect(
          repository.startedPackagesHistory.last,
          equals(['com.zhiliaoapp.musically']),
        );

        timerNotifier.dispose();
      },
    );

    test(
      'overlayEvents with returnToFocusmaxxing action brings main app to foreground',
      () async {
        repository.overlayController.add('{"action":"returnToFocusmaxxing"}');
        await Future<void>.delayed(Duration.zero);

        expect(repository.bringToForegroundCount, 1);
      },
    );

    test(
      'Maximum Focus mode starts shield service even with 0 blocked apps and cancelSessionFromOverlay cancels active session',
      () async {
        final sessionRepo = _FakeSessionRepository();
        final timerNotifier = _ControllableTimerNotifier(
          startSessionUseCase: StartSessionUseCase(sessionRepo),
          completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
          cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
          notificationService: _NoOpNotificationService(),
          prefs: prefs,
        );

        await notifier.setMaximumFocusEnabled(true);
        expect(notifier.isMaximumFocusEnabled, isTrue);

        await timerNotifier.startFocusSession('Deep Focus Lock');
        await notifier.syncWithTimer(timerNotifier);

        expect(repository.startedPackagesHistory, isNotEmpty);
        expect(
          repository.syncedOverlayPayloads.last['isMaximumFocus'],
          isTrue,
        );

        repository.overlayController
            .add('{"action":"cancelSessionFromOverlay"}');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(timerNotifier.status, TimerStatus.idle);
        expect(repository.bringToForegroundCount, 1);

        timerNotifier.dispose();
      },
    );

    test(
      'syncWithTimer does NOT stop shield service when schedule is active now',
      () async {
        final scheduleRepo = _FakeScheduleRepo()..isActive = true;
        final checkScheduleUseCase =
            CheckScheduleActiveNowUseCase(scheduleRepo);

        final scheduledShieldNotifier = ShieldNotifier(
          getShieldedAppsUseCase: GetShieldedAppsUseCase(repository),
          getInstalledAppsUseCase: GetInstalledAppsUseCase(repository),
          toggleShieldAppUseCase: ToggleShieldAppUseCase(repository),
          checkShieldPermissionsUseCase:
              CheckShieldPermissionsUseCase(repository),
          requestPermissionUseCase: RequestPermissionUseCase(repository),
          syncShieldWithOverlayUseCase:
              SyncShieldWithOverlayUseCase(repository),
          repository: repository,
          checkScheduleActiveNowUseCase: checkScheduleUseCase,
          sharedPreferences: prefs,
          autoInitialize: false,
        );

        final sessionRepo = _FakeSessionRepository();
        final timerNotifier = _ControllableTimerNotifier(
          startSessionUseCase: StartSessionUseCase(sessionRepo),
          completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
          cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
          notificationService: _NoOpNotificationService(),
          prefs: prefs,
        );

        await timerNotifier.startFocusSession('Schedule priority test');
        await scheduledShieldNotifier.syncWithTimer(timerNotifier);

        final stopsBefore = repository.stopShieldCallCount;

        timerNotifier.overrideStatus = TimerStatus.idle;
        await scheduledShieldNotifier.syncWithTimer(timerNotifier);

        expect(repository.stopShieldCallCount, equals(stopsBefore));

        scheduledShieldNotifier.dispose();
        timerNotifier.dispose();
      },
    );

    test(
      'persists scheduled auto-shield packages even when installedApps is empty',
      () async {
        repository.installedApps = [];
        await notifier.refresh();

        await notifier.toggleApp(
          packageName: 'com.test.emptyapps',
          appName: 'Empty App',
          isPreset: true,
        );

        final saved =
            prefs.getStringList(ScheduleConstants.schedulePackagesPrefsKey);
        expect(saved, contains('com.test.emptyapps'));
      },
    );

    test(
      'startShieldForSchedule passes isScheduled: true and timeRange to repository',
      () async {
        await notifier.toggleApp(
          packageName: 'com.test.scheduled',
          appName: 'Scheduled App',
          isPreset: true,
        );

        await notifier.startShieldForSchedule(timeRange: '09:00 - 17:00');

        expect(notifier.isScheduledShieldActive, isTrue);
        expect(repository.lastStartIsScheduled, isTrue);
        expect(repository.lastStartTimeRange, equals('09:00 - 17:00'));
        expect(
          repository.startedPackagesHistory.last,
          contains('com.test.scheduled'),
        );
      },
    );

    test(
      'syncWithTimer does not spam syncOverlayState on 1-second countdown ticks while running',
      () async {
        final sessionRepo = _FakeSessionRepository();
        final timerNotifier = _ControllableTimerNotifier(
          startSessionUseCase: StartSessionUseCase(sessionRepo),
          completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
          cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
          notificationService: _NoOpNotificationService(),
          prefs: prefs,
        );

        await timerNotifier.startFocusSession('Silent Countdown');
        await notifier.syncWithTimer(timerNotifier);
        expect(repository.syncedOverlayPayloads.length, 1);

        // Simulate multiple 1-second countdown ticks with the same status, goal, and targetEndTime
        timerNotifier.overrideRemainingSeconds = 1499;
        await notifier.syncWithTimer(timerNotifier);
        timerNotifier.overrideRemainingSeconds = 1470;
        await notifier.syncWithTimer(timerNotifier);
        timerNotifier.overrideRemainingSeconds = 1440;
        await notifier.syncWithTimer(timerNotifier);

        expect(repository.syncedOverlayPayloads.length, 1);

        // Pausing changes status and targetEndTime, triggering a state sync
        timerNotifier.overrideRemainingSeconds = null;
        timerNotifier.pause();
        await notifier.syncWithTimer(timerNotifier);
        expect(repository.syncedOverlayPayloads.length, 2);
        expect(repository.syncedOverlayPayloads.last['isPaused'], isTrue);

        // Resuming triggers another state sync with restored targetEndTime
        timerNotifier.resume();
        await notifier.syncWithTimer(timerNotifier);
        expect(repository.syncedOverlayPayloads.length, 3);

        timerNotifier.dispose();
      },
    );
  });
}

class _FakeScheduleRepo implements IScheduleRepository {
  bool isActive = false;

  @override
  Future<Either<Failure, bool>> isScheduleActiveNow() async => Right(isActive);

  @override
  Future<Either<Failure, void>> armAlarms(
          ScheduleConfigEntity schedule) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> cancelAlarms() async => const Right(null);

  @override
  Future<Either<Failure, ScheduleConfigEntity>> getSchedule() async =>
      const Right(ScheduleConfigEntity.initial);

  @override
  Future<Either<Failure, void>> saveSchedule(
          ScheduleConfigEntity schedule) async =>
      const Right(null);
}
