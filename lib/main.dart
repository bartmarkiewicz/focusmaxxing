import 'dart:io';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/core/theme/app_theme.dart';
import 'package:focusmaxxing/core/theme/theme_notifier.dart';
import 'package:focusmaxxing/features/audio/data/repositories/audio_repository_impl.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/play_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/set_audio_volume_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/stop_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/backlog/data/datasources/backlog_local_data_source.dart';
import 'package:focusmaxxing/features/backlog/data/repositories/backlog_repository_impl.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/add_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/delete_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/get_pending_tasks_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/billing/data/datasources/billing_local_cache_source.dart';
import 'package:focusmaxxing/features/billing/data/datasources/in_app_purchase_client.dart';
import 'package:focusmaxxing/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/get_product_details_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/purchase_lifetime_pro_usecase.dart';
import 'package:focusmaxxing/features/billing/domain/usecases/restore_purchases_usecase.dart';
import 'package:focusmaxxing/features/billing/presentation/notifiers/billing_notifier.dart';
import 'package:focusmaxxing/features/insights/data/repositories/insights_repository_impl.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_daily_summary_usecase.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_recent_sessions_usecase.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:focusmaxxing/features/shield/data/datasources/shield_installed_apps_source.dart';
import 'package:focusmaxxing/features/shield/data/datasources/shield_local_data_source.dart';
import 'package:focusmaxxing/features/shield/data/datasources/shield_native_bridge_source.dart';
import 'package:focusmaxxing/features/shield/data/repositories/shield_repository_impl.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:focusmaxxing/features/schedule/data/datasources/schedule_alarm_data_source.dart';
import 'package:focusmaxxing/features/schedule/data/datasources/schedule_local_data_source.dart';
import 'package:focusmaxxing/features/schedule/data/repositories/schedule_repository_impl.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/check_schedule_active_now_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/get_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/save_schedule_usecase.dart';
import 'package:focusmaxxing/features/schedule/domain/usecases/toggle_auto_shield_usecase.dart';
import 'package:focusmaxxing/features/schedule/presentation/notifiers/schedule_notifier.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/check_shield_permissions_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_installed_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/get_shielded_apps_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/request_permission_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/sync_shield_with_overlay_usecase.dart';
import 'package:focusmaxxing/features/shield/domain/usecases/toggle_shield_app_usecase.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/timer/data/datasources/session_local_data_source.dart';
import 'package:focusmaxxing/features/timer/data/repositories/session_repository_impl.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/widget/data/services/widget_sync_service_impl.dart';
import 'package:focusmaxxing/main_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

export 'package:focusmaxxing/features/schedule/data/datasources/schedule_alarm_data_source.dart'
    show autoShieldStartAlarmCallback, autoShieldEndAlarmCallback;
export 'package:focusmaxxing/features/shield/presentation/overlay/overlay_main.dart'
    show overlayMain, HardLockOverlayWidget;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final notificationService = NotificationService();
  try {
    await notificationService.init();
  } catch (e, st) {
    debugPrint('Failed to initialize NotificationService: $e\n$st');
  }

  final sharedPreferences = await SharedPreferences.getInstance();

  if (!kIsWeb && Platform.isAndroid) {
    try {
      await AndroidAlarmManager.initialize();
    } catch (_) {}
  }

  final sessionLocalDataSource = SessionLocalDataSource();
  final backlogLocalDataSource = BacklogLocalDataSource();
  final shieldLocalDataSource = ShieldLocalDataSource();
  const shieldInstalledAppsSource = ShieldInstalledAppsSourceImpl();
  final shieldNativeBridgeSource = ShieldNativeBridgeSourceImpl();
  final billingLocalCacheSource =
      BillingLocalCacheSourceImpl(sharedPreferences: sharedPreferences);
  const inAppPurchaseClient = InAppPurchaseClientImpl();
  final scheduleLocalDataSource =
      ScheduleLocalDataSourceImpl(prefs: sharedPreferences);
  final scheduleAlarmDataSource = ScheduleAlarmDataSourceImpl();

  final sessionRepository =
      SessionRepositoryImpl(localDataSource: sessionLocalDataSource);
  final backlogRepository =
      BacklogRepositoryImpl(localDataSource: backlogLocalDataSource);
  final insightsRepository =
      InsightsRepositoryImpl(localDataSource: sessionLocalDataSource);
  final shieldRepository = ShieldRepositoryImpl(
    localDataSource: shieldLocalDataSource,
    installedAppsSource: shieldInstalledAppsSource,
    nativeBridgeSource: shieldNativeBridgeSource,
  );
  final audioRepository = AudioRepositoryImpl();
  final billingRepository = BillingRepositoryImpl(
    iapClient: inAppPurchaseClient,
    localCacheSource: billingLocalCacheSource,
  );
  final scheduleRepository = ScheduleRepositoryImpl(
    localDataSource: scheduleLocalDataSource,
    alarmDataSource: scheduleAlarmDataSource,
  );

  final markTaskCompletedUseCase = MarkTaskCompletedUseCase(backlogRepository);
  final widgetSyncService = WidgetSyncServiceImpl();
  final getDailySummaryUseCase = GetDailySummaryUseCase(insightsRepository);

  final timerNotifier = TimerNotifier(
    startSessionUseCase: StartSessionUseCase(sessionRepository),
    completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
    cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
    notificationService: notificationService,
    markTaskCompletedUseCase: markTaskCompletedUseCase,
    prefs: sharedPreferences,
    widgetSyncService: widgetSyncService,
    getDailySummaryUseCase: getDailySummaryUseCase,
  );

  final backlogNotifier = BacklogNotifier(
    getPendingTasksUseCase: GetPendingTasksUseCase(backlogRepository),
    addBacklogTaskUseCase: AddBacklogTaskUseCase(backlogRepository),
    deleteBacklogTaskUseCase: DeleteBacklogTaskUseCase(backlogRepository),
    markTaskCompletedUseCase: markTaskCompletedUseCase,
  );
  try {
    await backlogNotifier.loadPendingTasks();
  } catch (e, st) {
    debugPrint('Failed to load pending backlog tasks on startup: $e\n$st');
  }

  timerNotifier.attachBacklogNotifier(backlogNotifier);

  final insightsNotifier = InsightsNotifier(
    getDailySummaryUseCase: getDailySummaryUseCase,
    getRecentSessionsUseCase: GetRecentSessionsUseCase(insightsRepository),
    notificationService: notificationService,
    sharedPreferences: sharedPreferences,
    widgetSyncService: widgetSyncService,
  );

  final checkScheduleActiveNowUseCase =
      CheckScheduleActiveNowUseCase(scheduleRepository);

  final shieldNotifier = ShieldNotifier(
    getShieldedAppsUseCase: GetShieldedAppsUseCase(shieldRepository),
    getInstalledAppsUseCase: GetInstalledAppsUseCase(shieldRepository),
    toggleShieldAppUseCase: ToggleShieldAppUseCase(shieldRepository),
    checkShieldPermissionsUseCase:
        CheckShieldPermissionsUseCase(shieldRepository),
    requestPermissionUseCase: RequestPermissionUseCase(shieldRepository),
    syncShieldWithOverlayUseCase:
        SyncShieldWithOverlayUseCase(shieldRepository),
    repository: shieldRepository,
    checkScheduleActiveNowUseCase: checkScheduleActiveNowUseCase,
    sharedPreferences: sharedPreferences,
  )..attachTimerNotifier(timerNotifier);

  final audioNotifier = AudioNotifier(
    playSoundscapeUseCase: PlaySoundscapeUseCase(audioRepository),
    stopSoundscapeUseCase: StopSoundscapeUseCase(audioRepository),
    setAudioVolumeUseCase: SetAudioVolumeUseCase(audioRepository),
    repository: audioRepository,
    sharedPreferences: sharedPreferences,
  )..attachTimerNotifier(timerNotifier);

  final scheduleNotifier = ScheduleNotifier(
    getScheduleUseCase: GetScheduleUseCase(scheduleRepository),
    saveScheduleUseCase: SaveScheduleUseCase(scheduleRepository),
    toggleAutoShieldUseCase: ToggleAutoShieldUseCase(scheduleRepository),
    checkScheduleActiveNowUseCase: checkScheduleActiveNowUseCase,
    repository: scheduleRepository,
    shieldNotifier: shieldNotifier,
    sharedPreferences: sharedPreferences,
  );

  final themeNotifier = ThemeNotifier(
    sharedPreferences: sharedPreferences,
  );

  final billingNotifier = BillingNotifier(
    getProductDetailsUseCase: GetProductDetailsUseCase(billingRepository),
    purchaseLifetimeProUseCase: PurchaseLifetimeProUseCase(billingRepository),
    restorePurchasesUseCase: RestorePurchasesUseCase(billingRepository),
    repository: billingRepository,
    shieldNotifier: shieldNotifier,
    audioNotifier: audioNotifier,
    scheduleNotifier: scheduleNotifier,
    themeNotifier: themeNotifier,
  );

  runApp(
    FocusmaxxingApp(
      timerNotifier: timerNotifier,
      backlogNotifier: backlogNotifier,
      insightsNotifier: insightsNotifier,
      shieldNotifier: shieldNotifier,
      audioNotifier: audioNotifier,
      billingNotifier: billingNotifier,
      scheduleNotifier: scheduleNotifier,
      themeNotifier: themeNotifier,
    ),
  );
}

class FocusmaxxingApp extends StatelessWidget {
  const FocusmaxxingApp({
    super.key,
    this.timerNotifier,
    this.backlogNotifier,
    this.insightsNotifier,
    this.shieldNotifier,
    this.audioNotifier,
    this.billingNotifier,
    this.scheduleNotifier,
    this.themeNotifier,
  });

  final TimerNotifier? timerNotifier;
  final BacklogNotifier? backlogNotifier;
  final InsightsNotifier? insightsNotifier;
  final ShieldNotifier? shieldNotifier;
  final AudioNotifier? audioNotifier;
  final BillingNotifier? billingNotifier;
  final ScheduleNotifier? scheduleNotifier;
  final ThemeNotifier? themeNotifier;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (timerNotifier case final notifier?)
          ChangeNotifierProvider<TimerNotifier>.value(value: notifier)
        else
          ChangeNotifierProvider<TimerNotifier>(
            create: (_) => _createDefaultTimerNotifier(),
          ),
        if (backlogNotifier case final notifier?)
          ChangeNotifierProvider<BacklogNotifier>.value(value: notifier)
        else
          ChangeNotifierProvider<BacklogNotifier>(
            create: (_) => _createDefaultBacklogNotifier(),
          ),
        if (insightsNotifier case final notifier?)
          ChangeNotifierProvider<InsightsNotifier>.value(value: notifier)
        else
          ChangeNotifierProvider<InsightsNotifier>(
            create: (_) => _createDefaultInsightsNotifier(),
          ),
        if (shieldNotifier case final notifier?)
          ChangeNotifierProvider<ShieldNotifier>.value(value: notifier)
        else
          ChangeNotifierProxyProvider<TimerNotifier, ShieldNotifier>(
            create: (_) => _createDefaultShieldNotifier(),
            update: (_, timer, shield) {
              final resolved = shield ?? _createDefaultShieldNotifier();
              resolved.attachTimerNotifier(timer);
              return resolved;
            },
          ),
        if (audioNotifier case final notifier?)
          ChangeNotifierProvider<AudioNotifier>.value(value: notifier)
        else
          ChangeNotifierProxyProvider<TimerNotifier, AudioNotifier>(
            create: (_) => _createDefaultAudioNotifier(),
            update: (_, timer, audio) {
              final resolved = audio ?? _createDefaultAudioNotifier();
              resolved.attachTimerNotifier(timer);
              return resolved;
            },
          ),
        if (scheduleNotifier case final notifier?)
          ChangeNotifierProvider<ScheduleNotifier>.value(value: notifier)
        else
          ChangeNotifierProxyProvider<ShieldNotifier, ScheduleNotifier>(
            create: (_) => _createDefaultScheduleNotifier(),
            update: (_, shield, schedule) {
              final resolved = schedule ?? _createDefaultScheduleNotifier();
              resolved.attachShieldNotifier(shield);
              return resolved;
            },
          ),
        if (themeNotifier case final notifier?)
          ChangeNotifierProvider<ThemeNotifier>.value(value: notifier)
        else
          ChangeNotifierProvider<ThemeNotifier>(
            create: (_) => _createDefaultThemeNotifier(),
          ),
        if (billingNotifier case final notifier?)
          ChangeNotifierProvider<BillingNotifier>.value(value: notifier)
        else
          ChangeNotifierProxyProvider4<ShieldNotifier, AudioNotifier,
              ScheduleNotifier, ThemeNotifier, BillingNotifier>(
            create: (_) => _createDefaultBillingNotifier(),
            update: (_, shield, audio, schedule, theme, billing) {
              final resolved = billing ?? _createDefaultBillingNotifier();
              resolved
                ..attachShieldNotifier(shield)
                ..attachAudioNotifier(audio)
                ..attachScheduleNotifier(schedule)
                ..attachThemeNotifier(theme);
              return resolved;
            },
          ),
      ],
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return Consumer<ThemeNotifier>(
            builder: (context, themeNotifier, _) {
              final accentColor = themeNotifier.currentAccent.color;
              return MaterialApp(
                title: 'Focusmaxxing',
                debugShowCheckedModeBanner: false,
                themeMode: ThemeMode.dark,
                theme: AppTheme.buildDarkTheme(darkDynamic,
                    accentColor: accentColor),
                darkTheme: AppTheme.buildDarkTheme(darkDynamic,
                    accentColor: accentColor),
                home: const MainScaffold(),
              );
            },
          );
        },
      ),
    );
  }

  static TimerNotifier _createDefaultTimerNotifier() {
    final sessionDataSource = SessionLocalDataSource();
    final backlogDataSource = BacklogLocalDataSource();
    final sessionRepo =
        SessionRepositoryImpl(localDataSource: sessionDataSource);
    final insightsRepo =
        InsightsRepositoryImpl(localDataSource: sessionDataSource);
    final backlogRepo =
        BacklogRepositoryImpl(localDataSource: backlogDataSource);
    final widgetSyncService = WidgetSyncServiceImpl();

    return TimerNotifier(
      startSessionUseCase: StartSessionUseCase(sessionRepo),
      completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
      cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
      notificationService: NotificationService(),
      markTaskCompletedUseCase: MarkTaskCompletedUseCase(backlogRepo),
      widgetSyncService: widgetSyncService,
      getDailySummaryUseCase: GetDailySummaryUseCase(insightsRepo),
    );
  }

  static BacklogNotifier _createDefaultBacklogNotifier() {
    final backlogDataSource = BacklogLocalDataSource();
    final backlogRepo =
        BacklogRepositoryImpl(localDataSource: backlogDataSource);

    return BacklogNotifier(
      getPendingTasksUseCase: GetPendingTasksUseCase(backlogRepo),
      addBacklogTaskUseCase: AddBacklogTaskUseCase(backlogRepo),
      deleteBacklogTaskUseCase: DeleteBacklogTaskUseCase(backlogRepo),
      markTaskCompletedUseCase: MarkTaskCompletedUseCase(backlogRepo),
    );
  }

  static InsightsNotifier _createDefaultInsightsNotifier() {
    final sessionDataSource = SessionLocalDataSource();
    final insightsRepo =
        InsightsRepositoryImpl(localDataSource: sessionDataSource);
    final widgetSyncService = WidgetSyncServiceImpl();

    return InsightsNotifier(
      getDailySummaryUseCase: GetDailySummaryUseCase(insightsRepo),
      getRecentSessionsUseCase: GetRecentSessionsUseCase(insightsRepo),
      notificationService: NotificationService(),
      widgetSyncService: widgetSyncService,
    );
  }

  static ShieldNotifier _createDefaultShieldNotifier() {
    final shieldRepo = ShieldRepositoryImpl(
      localDataSource: ShieldLocalDataSource(),
      installedAppsSource: const ShieldInstalledAppsSourceImpl(),
      nativeBridgeSource: ShieldNativeBridgeSourceImpl(),
    );

    return ShieldNotifier(
      getShieldedAppsUseCase: GetShieldedAppsUseCase(shieldRepo),
      getInstalledAppsUseCase: GetInstalledAppsUseCase(shieldRepo),
      toggleShieldAppUseCase: ToggleShieldAppUseCase(shieldRepo),
      checkShieldPermissionsUseCase: CheckShieldPermissionsUseCase(shieldRepo),
      requestPermissionUseCase: RequestPermissionUseCase(shieldRepo),
      syncShieldWithOverlayUseCase: SyncShieldWithOverlayUseCase(shieldRepo),
      repository: shieldRepo,
      autoInitialize: false,
    );
  }

  static AudioNotifier _createDefaultAudioNotifier() {
    final audioRepo = AudioRepositoryImpl();

    return AudioNotifier(
      playSoundscapeUseCase: PlaySoundscapeUseCase(audioRepo),
      stopSoundscapeUseCase: StopSoundscapeUseCase(audioRepo),
      setAudioVolumeUseCase: SetAudioVolumeUseCase(audioRepo),
      repository: audioRepo,
    );
  }

  static BillingNotifier _createDefaultBillingNotifier() {
    final billingRepo = BillingRepositoryImpl(
      iapClient: const InAppPurchaseClientImpl(),
      localCacheSource: const BillingLocalCacheSourceImpl(),
    );

    return BillingNotifier(
      getProductDetailsUseCase: GetProductDetailsUseCase(billingRepo),
      purchaseLifetimeProUseCase: PurchaseLifetimeProUseCase(billingRepo),
      restorePurchasesUseCase: RestorePurchasesUseCase(billingRepo),
      repository: billingRepo,
      autoInitialize: false,
    );
  }

  static ScheduleNotifier _createDefaultScheduleNotifier() {
    final localDataSource = ScheduleLocalDataSourceImpl();
    final alarmDataSource = ScheduleAlarmDataSourceImpl();
    final scheduleRepo = ScheduleRepositoryImpl(
      localDataSource: localDataSource,
      alarmDataSource: alarmDataSource,
    );

    return ScheduleNotifier(
      getScheduleUseCase: GetScheduleUseCase(scheduleRepo),
      saveScheduleUseCase: SaveScheduleUseCase(scheduleRepo),
      toggleAutoShieldUseCase: ToggleAutoShieldUseCase(scheduleRepo),
      repository: scheduleRepo,
      autoInitialize: false,
    );
  }

  static ThemeNotifier _createDefaultThemeNotifier() {
    return ThemeNotifier();
  }
}
