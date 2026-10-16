import 'dart:io';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/core/theme/app_theme.dart';
import 'package:focusmaxxing/features/backlog/data/datasources/backlog_local_data_source.dart';
import 'package:focusmaxxing/features/backlog/data/repositories/backlog_repository_impl.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/add_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/delete_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/get_pending_tasks_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
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
import 'package:focusmaxxing/main_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

export 'package:focusmaxxing/features/shield/presentation/overlay/overlay_main.dart'
    show overlayMain, HardLockOverlayWidget;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final notificationService = NotificationService();
  await notificationService.init();

  final sharedPreferences = await SharedPreferences.getInstance();

  final sessionLocalDataSource = SessionLocalDataSource();
  final backlogLocalDataSource = BacklogLocalDataSource();

  final sessionRepository =
      SessionRepositoryImpl(localDataSource: sessionLocalDataSource);
  final backlogRepository =
      BacklogRepositoryImpl(localDataSource: backlogLocalDataSource);
  final insightsRepository =
      InsightsRepositoryImpl(localDataSource: sessionLocalDataSource);

  final markTaskCompletedUseCase =
      MarkTaskCompletedUseCase(backlogRepository);

  final timerNotifier = TimerNotifier(
    startSessionUseCase: StartSessionUseCase(sessionRepository),
    completeSessionUseCase: CompleteSessionUseCase(sessionRepository),
    cancelSessionUseCase: CancelSessionUseCase(sessionRepository),
    notificationService: notificationService,
    markTaskCompletedUseCase: markTaskCompletedUseCase,
    prefs: sharedPreferences,
  );

  final backlogNotifier = BacklogNotifier(
    getPendingTasksUseCase: GetPendingTasksUseCase(backlogRepository),
    addBacklogTaskUseCase: AddBacklogTaskUseCase(backlogRepository),
    deleteBacklogTaskUseCase: DeleteBacklogTaskUseCase(backlogRepository),
    markTaskCompletedUseCase: markTaskCompletedUseCase,
  );

  final insightsNotifier = InsightsNotifier(
    getDailySummaryUseCase: GetDailySummaryUseCase(insightsRepository),
    getRecentSessionsUseCase: GetRecentSessionsUseCase(insightsRepository),
    notificationService: notificationService,
    sharedPreferences: sharedPreferences,
  );

  runApp(
    FocusmaxxingApp(
      timerNotifier: timerNotifier,
      backlogNotifier: backlogNotifier,
      insightsNotifier: insightsNotifier,
    ),
  );
}

class FocusmaxxingApp extends StatelessWidget {
  const FocusmaxxingApp({
    super.key,
    this.timerNotifier,
    this.backlogNotifier,
    this.insightsNotifier,
  });

  final TimerNotifier? timerNotifier;
  final BacklogNotifier? backlogNotifier;
  final InsightsNotifier? insightsNotifier;

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
      ],
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return MaterialApp(
            title: 'Focusmaxxing',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.dark,
            theme: AppTheme.buildDarkTheme(darkDynamic),
            darkTheme: AppTheme.buildDarkTheme(darkDynamic),
            home: const MainScaffold(),
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
    final backlogRepo =
        BacklogRepositoryImpl(localDataSource: backlogDataSource);

    return TimerNotifier(
      startSessionUseCase: StartSessionUseCase(sessionRepo),
      completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
      cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
      notificationService: NotificationService(),
      markTaskCompletedUseCase: MarkTaskCompletedUseCase(backlogRepo),
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

    return InsightsNotifier(
      getDailySummaryUseCase: GetDailySummaryUseCase(insightsRepo),
      getRecentSessionsUseCase: GetRecentSessionsUseCase(insightsRepo),
      notificationService: NotificationService(),
    );
  }
}
