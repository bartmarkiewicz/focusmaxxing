import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/play_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/set_audio_volume_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/stop_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/add_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/delete_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/get_pending_tasks_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';
import 'package:focusmaxxing/features/shield/domain/repositories/i_shield_repository.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/bring_app_to_foreground_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/check_shield_permissions_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_installed_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_shielded_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/request_permission_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/start_shield_service_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/stop_shield_service_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/swap_shield_app_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/sync_shield_with_overlay_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/toggle_shield_app_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/watch_overlay_events_usecase.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
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
  final List<BacklogTaskEntity> _tasks = [];
  int _nextId = 1;

  @override
  Future<Either<Failure, int>> addTask(String title) async {
    final task = BacklogTaskEntity(
      id: _nextId++,
      title: title,
      createdAt: DateTime.now(),
    );
    _tasks.add(task);
    return Right(task.id!);
  }

  @override
  Future<Either<Failure, void>> deleteTask(int id) async {
    _tasks.removeWhere((t) => t.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<BacklogTaskEntity>>> getPendingTasks() async =>
      Right(_tasks.where((t) => !t.isCompleted).toList());

  @override
  Future<Either<Failure, void>> markCompleted(int id, [int? sessionId]) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tasks[idx] = _tasks[idx].copyWith(isCompleted: true);
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
}

class _FakeAudioRepository implements IAudioRepository {
  @override
  Future<Either<Failure, void>> playLoop(String assetPath) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> stopLoop() async => const Right(null);

  @override
  Future<Either<Failure, void>> setVolume(double volume) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> preloadAssets(List<String> assetPaths) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> playChime({String assetPath = ''}) async =>
      const Right(null);

  @override
  Future<void> dispose() async {}
}

class _TestShieldRepository implements IShieldRepository {
  final Map<String, ShieldedAppEntity> savedApps = {
    'com.discord': ShieldedAppEntity(
      packageName: 'com.discord',
      appName: 'Discord',
      isActive: true,
      createdAt: DateTime.utc(2026, 10, 16),
    ),
  };
  List<ShieldedAppEntity> installedApps = [
    ShieldedAppEntity(
      packageName: 'com.discord',
      appName: 'Discord',
      isActive: true,
      createdAt: DateTime.utc(2026, 10, 16),
    ),
  ];
  ShieldPermissionStatus permissionStatus = const ShieldPermissionStatus(
    hasUsageStatsPermission: false,
    hasOverlayPermission: true,
    isIgnoringBatteryOptimizations: true,
  );
  final List<ShieldPermissionType> requestedPermissions = [];

  @override
  Stream<dynamic> get overlayEvents => const Stream.empty();

  @override
  Future<Either<Failure, List<ShieldedAppEntity>>> getShieldedApps() async =>
      Right(savedApps.values.toList());

  @override
  Future<Either<Failure, List<ShieldedAppEntity>>> getInstalledApps() async =>
      Right(installedApps);

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
  }) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> purgeUninstalledApps(
    Set<String> installedPackages,
  ) async =>
      const Right(null);

  @override
  Future<Either<Failure, ShieldPermissionStatus>> checkPermissions() async =>
      Right(permissionStatus);

  @override
  Future<Either<Failure, bool>> requestPermission(
    ShieldPermissionType permissionType,
  ) async {
    requestedPermissions.add(permissionType);
    return const Right(true);
  }

  @override
  Future<Either<Failure, bool>> startShieldService(
    List<String> blockedPackages, {
    bool isScheduled = false,
    String? timeRange,
  }) async =>
      const Right(true);

  @override
  Future<Either<Failure, bool>> stopShieldService({bool force = false}) async =>
      const Right(true);

  @override
  Future<Either<Failure, void>> syncOverlayState({
    required String goal,
    required int remainingSeconds,
    required bool isBreak,
    bool isMaximumFocus = false,
    bool isPaused = false,
    int? targetEndTimeEpochMs,
  }) async =>
      const Right(null);

  @override
  Future<Either<Failure, bool>> bringAppToForeground() async =>
      const Right(true);
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

  Widget buildWidget({
    AudioNotifier? audioNotifier,
    ShieldNotifier? shieldNotifier,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TimerNotifier>.value(value: timerNotifier),
        ChangeNotifierProvider<BacklogNotifier>.value(value: backlogNotifier),
        ChangeNotifierProvider<AudioNotifier?>.value(value: audioNotifier),
        ChangeNotifierProvider<ShieldNotifier?>.value(value: shieldNotifier),
      ],
      child: const MaterialApp(
        home: TimerPage(),
      ),
    );
  }

  group('TimerPage', () {
    testWidgets('renders title, dial, presets, and Start session button when idle',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('FOCUSMAXXING'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('15m'), findsOneWidget);
      expect(find.text('25m'), findsOneWidget);
      expect(find.text('45m'), findsOneWidget);
      expect(find.text('60m'), findsOneWidget);
      expect(find.text('Start session'), findsOneWidget);
    });

    testWidgets('selecting duration preset updates dial countdown',
        (tester) async {
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

    testWidgets(
        'tapping goal anchor pill opens MultiTargetPickerSheet for editing without starting timer',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set focus target'));
      await tester.pumpAndSettle();

      expect(
          find.text('What are you working on?'), findsOneWidget);
      expect(timerNotifier.status, TimerStatus.idle);
    });

    testWidgets(
        '1-tap lock-in starts session immediately with Deep Work default and shows active lock-in banner',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start session'));
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.running);
      expect(timerNotifier.currentTaskGoal, 'Deep Work');
      expect(sessionRepository.lastCreatedSession?.taskGoal, 'Deep Work');
      expect(find.text('Session running'), findsOneWidget);

      timerNotifier.pause();
      await tester.pumpAndSettle();
      expect(find.text('Focus paused'), findsOneWidget);

      await timerNotifier.cancelSession();
      await tester.pumpAndSettle();
      expect(find.text('Session running'), findsNothing);
    });

    testWidgets('tapping Custom duration opens bottom sheet and updates preset',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      expect(find.text('Custom Duration'), findsOneWidget);
      expect(find.text('Set Duration'), findsOneWidget);

      await tester.tap(find.text('Set Duration'));
      await tester.pumpAndSettle();

      expect(find.text('Custom Duration'), findsNothing);
    });

    testWidgets('tapping ambient soundscapes pill opens bottom sheet',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sound: Off'), findsOneWidget);
      await tester.tap(find.text('Sound: Off'));
      await tester.pumpAndSettle();

      expect(find.text('Soundscape'), findsOneWidget);
    });

    testWidgets(
        'recent goal chips render and tapping a chip updates the anchor',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_focus_goals', ['Coding', 'Deep Work']);

      final testNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepository),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
        markTaskCompletedUseCase: MarkTaskCompletedUseCase(backlogRepository),
        notificationService: notificationService,
        prefs: prefs,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TimerNotifier>.value(value: testNotifier),
            ChangeNotifierProvider<BacklogNotifier>.value(
                value: backlogNotifier),
          ],
          child: const MaterialApp(
            home: TimerPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coding'), findsOneWidget);
      expect(find.text('Deep Work'), findsOneWidget);

      await tester.tap(find.text('Coding'));
      await tester.pumpAndSettle();

      expect(testNotifier.currentTaskGoal, 'Coding');
      expect(find.text('Coding'), findsWidgets); // chip and anchor pill
      testNotifier.dispose();
    });

    testWidgets('tapping ROLL INTO NEXT BLOCK during break starts next session',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Start session and check-in to trigger break
      await timerNotifier.startFocusSession('Review PR');
      await tester.pumpAndSettle();
      expect(timerNotifier.status, TimerStatus.running);

      await timerNotifier.checkInSession(lockedIn: true);
      await tester.pumpAndSettle();

      if (find.byKey(const Key('celebration_take_break_button')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('celebration_take_break_button')));
        await tester.pumpAndSettle();
      }

      expect(timerNotifier.status, TimerStatus.breakRunning);
      final rollButton = find.byKey(const Key('timer_roll_into_next_block_button'));
      expect(rollButton, findsOneWidget);

      await tester.ensureVisible(rollButton);
      await tester.pumpAndSettle();
      await tester.tap(rollButton);
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.running);
      expect(timerNotifier.currentTaskGoal, 'Review PR');

      await timerNotifier.cancelSession();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'tapping Single Session pill toggles singleSessionMode on TimerNotifier',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Single: Off'), findsOneWidget);
      expect(timerNotifier.isSingleSessionMode, isFalse);

      await tester.tap(find.byKey(const Key('timer_single_session_mode_pill')));
      await tester.pumpAndSettle();

      expect(find.text('Single: On'), findsOneWidget);
      expect(timerNotifier.isSingleSessionMode, isTrue);
    });

    testWidgets(
        'tapping END ALL SESSIONS during break returns to idle',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await timerNotifier.startFocusSession('Lock In Phase');
      await tester.pumpAndSettle();

      await timerNotifier.checkInSession(lockedIn: true);
      await tester.pumpAndSettle();
      expect(timerNotifier.status, TimerStatus.breakRunning);
      final endAllButton =
          find.byKey(const Key('timer_end_all_sessions_button'));
      expect(endAllButton, findsOneWidget);

      await tester.ensureVisible(endAllButton);
      await tester.pumpAndSettle();
      await tester.tap(endAllButton);
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.idle);
      expect(find.text('Start session'), findsOneWidget);
    });

    testWidgets(
        'check-in dialog in Single Session Mode still prompts user and returns directly to idle upon check-in',
        (tester) async {
      await timerNotifier.setSingleSessionMode(true);
      timerNotifier.setDurationPreset(1);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start session'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      });
      timerNotifier.syncWithWallClock();
      await tester.pumpAndSettle();

      expect(find.text('Did you lock in?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkin_end_all_sessions_button')));
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.idle);
      expect(find.text('Start session'), findsOneWidget);
    });

    testWidgets(
        'tapping LOCKED IN & END ALL SESSIONS in check-in dialog ends all sessions and returns to idle',
        (tester) async {
      expect(timerNotifier.isSingleSessionMode, isFalse);
      timerNotifier.setDurationPreset(1);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start session'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      });
      timerNotifier.syncWithWallClock();
      await tester.pumpAndSettle();

      expect(find.text('Did you lock in?'), findsOneWidget);
      final endAllBtn =
          find.byKey(const Key('checkin_end_all_sessions_button'));
      await tester.ensureVisible(endAllBtn);
      await tester.pumpAndSettle();
      await tester.tap(endAllBtn);
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.idle);
      expect(find.text('Start session'), findsOneWidget);
    });

    testWidgets(
        'renders active audio mini player during running session when soundscape is selected and toggles playback',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final audioRepo = _FakeAudioRepository();
      final audioNotifier = AudioNotifier(
        playSoundscapeUseCase: PlaySoundscapeUseCase(audioRepo),
        stopSoundscapeUseCase: StopSoundscapeUseCase(audioRepo),
        setAudioVolumeUseCase: SetAudioVolumeUseCase(audioRepo),
      )..attachTimerNotifier(timerNotifier);
      addTearDown(audioNotifier.dispose);
      await audioNotifier.selectSoundscape('brown_noise');

      await tester.pumpWidget(buildWidget(audioNotifier: audioNotifier));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('active_audio_mini_player')),
        findsNothing,
      );

      await timerNotifier.startFocusSession('Mini Player Test');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('active_audio_mini_player')),
        findsOneWidget,
      );
      expect(find.textContaining('Brown Noise'), findsOneWidget);
      expect(audioNotifier.isPlaying, isTrue);

      final playPauseFinder =
          find.byKey(const ValueKey('mini_player_play_pause'));
      await tester.ensureVisible(playPauseFinder);
      await tester.pumpAndSettle();
      await tester.tap(playPauseFinder);
      await tester.pumpAndSettle();
      expect(audioNotifier.isPlaying, isFalse);

      await tester.tap(playPauseFinder);
      await tester.pump();
      expect(audioNotifier.isPlaying, isTrue);

      await timerNotifier.cancelSession();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'check-in with lockedIn true triggers celebration sheet and rolling into next starts new focus session',
        (tester) async {
      timerNotifier.setDurationPreset(1);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start session'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      });
      timerNotifier.syncWithWallClock();
      await tester.pumpAndSettle();

      // Check-in dialog appears
      expect(find.text('Did you lock in?'), findsOneWidget);

      // Tap roll into next block
      await tester.tap(find.byKey(const Key('celebration_roll_next_button')));
      await tester.pumpAndSettle();

      // Should transition straight into running session
      expect(timerNotifier.status, TimerStatus.running);
      expect(find.text('Session running'), findsOneWidget);

      await timerNotifier.cancelSession();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'during break mode, _BreakInfoCard renders rotating micro-habits, shuffles on tap, and ROLL INTO NEXT BLOCK button starts next focus session',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      await timerNotifier.startFocusSession('Chain Block A');
      await tester.pumpAndSettle();

      await timerNotifier.checkInSession(lockedIn: true);
      await tester.pumpAndSettle();

      // Dismiss celebration sheet if visible by tapping outside or let break screen show
      if (find.byKey(const Key('celebration_take_break_button')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('celebration_take_break_button')));
        await tester.pumpAndSettle();
      }

      expect(timerNotifier.status, TimerStatus.breakRunning);

      // Verify BreakInfoCard renders
      expect(find.byKey(const Key('timer_break_info_card_tap')), findsOneWidget);

      // Tap to shuffle habit
      await tester.tap(find.byKey(const Key('timer_break_info_card_tap')));
      await tester.pumpAndSettle();

      // Roll into Next Block button is present
      final rollButton =
          find.byKey(const Key('timer_roll_into_next_block_button'));
      expect(rollButton, findsOneWidget);

      // Tapping roll into next block directly starts Chain Block A in running state
      await tester.ensureVisible(rollButton);
      await tester.pumpAndSettle();
      await tester.tap(rollButton);
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.running);
      expect(timerNotifier.currentTaskGoal, 'Chain Block A');

      await timerNotifier.cancelSession();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'in-session quick-capture pill appears when running and dumps stray thought to backlog',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final lockIn = find.text('Start session');
      await tester.ensureVisible(lockIn);
      await tester.tap(lockIn);
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.running);
      final pillFinder = find.byKey(const Key('in_session_quick_capture_pill'));
      expect(pillFinder, findsOneWidget);
      expect(find.text('+ Dump stray thought...'), findsOneWidget);

      await tester.tap(pillFinder);
      await tester.pumpAndSettle();

      expect(find.text('Brain Dump Stray Thought'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('in_session_quick_capture_input')),
        'Remember to buy coffee beans',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('in_session_quick_capture_submit_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Brain Dump Stray Thought'), findsNothing);
      expect(find.text('Saved "Remember to buy coffee beans" to Backlog'),
          findsOneWidget);
      expect(backlogNotifier.pendingTasks.map((t) => t.title),
          contains('Remember to buy coffee beans'));
      expect(timerNotifier.status, TimerStatus.running);

      await timerNotifier.cancelSession();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'pre-flight gate dialog appears when active apps exist without permissions, Arm Shield opens guidance',
        (tester) async {
      final shieldRepo = _TestShieldRepository();
      final prefs = await SharedPreferences.getInstance();
      final shieldNotifier = ShieldNotifier(
        getShieldedAppsUseCase: GetShieldedAppsUseCase(shieldRepo),
        getInstalledAppsUseCase: GetInstalledAppsUseCase(shieldRepo),
        toggleShieldAppUseCase: ToggleShieldAppUseCase(shieldRepo),
        swapShieldAppUseCase: SwapShieldAppUseCase(shieldRepo),
        checkShieldPermissionsUseCase: CheckShieldPermissionsUseCase(shieldRepo),
        requestPermissionUseCase: RequestPermissionUseCase(shieldRepo),
        startShieldServiceUseCase: StartShieldServiceUseCase(shieldRepo),
        stopShieldServiceUseCase: StopShieldServiceUseCase(shieldRepo),
        syncShieldWithOverlayUseCase: SyncShieldWithOverlayUseCase(shieldRepo),
        bringAppToForegroundUseCase: BringAppToForegroundUseCase(shieldRepo),
        watchOverlayEventsUseCase: WatchOverlayEventsUseCase(shieldRepo),
        sharedPreferences: prefs,
        autoInitialize: false,
      );
      await shieldNotifier.refresh();

      await tester.pumpWidget(buildWidget(shieldNotifier: shieldNotifier));
      await tester.pumpAndSettle();

      final lockIn = find.text('Start session');
      await tester.ensureVisible(lockIn);
      await tester.tap(lockIn);
      await tester.pumpAndSettle();

      // Pre-flight dialog should appear
      expect(find.text('Shield Not Armed'), findsOneWidget);
      expect(
        find.text(
          'Brainrot Shield is not armed yet. Enable Android permissions to physically block distraction apps during your focus session.',
        ),
        findsOneWidget,
      );
      expect(timerNotifier.status, TimerStatus.idle);

      // Tap Arm Shield (30s)
      await tester.tap(find.byKey(const Key('shield_gate_arm_shield_button')));
      await tester.pumpAndSettle();

      // Should open PermissionGuidanceSheet
      expect(find.text('Enable Usage Access'), findsOneWidget);
      expect(timerNotifier.status, TimerStatus.idle);

      shieldNotifier.dispose();
    });

    testWidgets(
        'pre-flight gate dialog: Start Timer Only starts session without blocking',
        (tester) async {
      final shieldRepo = _TestShieldRepository();
      final prefs = await SharedPreferences.getInstance();
      final shieldNotifier = ShieldNotifier(
        getShieldedAppsUseCase: GetShieldedAppsUseCase(shieldRepo),
        getInstalledAppsUseCase: GetInstalledAppsUseCase(shieldRepo),
        toggleShieldAppUseCase: ToggleShieldAppUseCase(shieldRepo),
        swapShieldAppUseCase: SwapShieldAppUseCase(shieldRepo),
        checkShieldPermissionsUseCase: CheckShieldPermissionsUseCase(shieldRepo),
        requestPermissionUseCase: RequestPermissionUseCase(shieldRepo),
        startShieldServiceUseCase: StartShieldServiceUseCase(shieldRepo),
        stopShieldServiceUseCase: StopShieldServiceUseCase(shieldRepo),
        syncShieldWithOverlayUseCase: SyncShieldWithOverlayUseCase(shieldRepo),
        bringAppToForegroundUseCase: BringAppToForegroundUseCase(shieldRepo),
        watchOverlayEventsUseCase: WatchOverlayEventsUseCase(shieldRepo),
        sharedPreferences: prefs,
        autoInitialize: false,
      );
      await shieldNotifier.refresh();

      await tester.pumpWidget(buildWidget(shieldNotifier: shieldNotifier));
      await tester.pumpAndSettle();

      final lockIn = find.text('Start session');
      await tester.ensureVisible(lockIn);
      await tester.tap(lockIn);
      await tester.pumpAndSettle();

      expect(find.text('Shield Not Armed'), findsOneWidget);

      // Tap Start Timer Only
      await tester.tap(
        find.byKey(const Key('shield_gate_start_timer_only_button')),
      );
      await tester.pumpAndSettle();

      expect(timerNotifier.status, TimerStatus.running);
      expect(find.text('Shield Not Armed'), findsNothing);

      await timerNotifier.cancelSession();
      await tester.pumpAndSettle();
      shieldNotifier.dispose();
    });
  });
}
