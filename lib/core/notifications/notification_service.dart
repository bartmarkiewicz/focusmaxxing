import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:focusmaxxing/core/constants/schedule_constants.dart';

class NotificationService {
  static const int ongoingNotificationId = 1001;
  static const int dailyReminderNotificationId = 1002;
  static const int autoShieldNotificationId =
      ScheduleConstants.autoShieldNotificationId;
  static const int sessionCompletionNotificationId = 1004;

  static const String androidSmallIcon = '@drawable/ic_notification';

  static const String legacyTimerChannelId = 'focusmaxxing_timer_channel';
  static const String timerChannelId = 'focusmaxxing_timer_silent_channel';
  static const String timerChannelName = 'Focus Countdown';
  static const String timerChannelDescription =
      'Silent ongoing countdown notification for active focus sessions';

  static const String completionChannelId = 'focusmaxxing_completion_channel';
  static const String completionChannelName = 'Session Completion Alarms';
  static const String completionChannelDescription =
      'High-priority alarms and notifications when a focus block finishes';

  static const String reminderChannelId = 'focusmaxxing_reminder_channel';
  static const String reminderChannelName = 'Daily Focus Reminders';
  static const String reminderChannelDescription =
      'Scheduled notifications prompting daily focus blocks';

  static const String autoShieldChannelId =
      ScheduleConstants.scheduleNotificationChannelId;
  static const String autoShieldChannelName =
      ScheduleConstants.scheduleNotificationChannelName;
  static const String autoShieldChannelDescription =
      ScheduleConstants.scheduleNotificationChannelDescription;

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;
  int _timerNotificationOpId = 0;

  @visibleForTesting
  bool? isSupportedPlatformOverride;

  @visibleForTesting
  void setInitializedForTesting(bool value) {
    _isInitialized = value;
  }

  NotificationService({FlutterLocalNotificationsPlugin? notificationsPlugin})
      : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  bool get isSupportedPlatform =>
      isSupportedPlatformOverride ??
      (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS));

  Future<void> init() async {
    if (_isInitialized) return;
    if (!isSupportedPlatform) {
      _isInitialized = true;
      return;
    }

    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('NotificationService: fallback to default timezone: $e');
      try {
        tz.setLocalLocation(tz.UTC);
      } catch (_) {}
    }

    const androidSettings = AndroidInitializationSettings(androidSmallIcon);
    const darwinSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final androidImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();

        await androidImplementation
            ?.deleteNotificationChannel(legacyTimerChannelId);
        await androidImplementation?.createNotificationChannel(
          const AndroidNotificationChannel(
            timerChannelId,
            timerChannelName,
            description: timerChannelDescription,
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
        await androidImplementation?.createNotificationChannel(
          const AndroidNotificationChannel(
            completionChannelId,
            completionChannelName,
            description: completionChannelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidImplementation?.createNotificationChannel(
          const AndroidNotificationChannel(
            reminderChannelId,
            reminderChannelName,
            description: reminderChannelDescription,
            importance: Importance.defaultImportance,
          ),
        );
        await androidImplementation?.createNotificationChannel(
          const AndroidNotificationChannel(
            autoShieldChannelId,
            autoShieldChannelName,
            description: autoShieldChannelDescription,
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
      } catch (e) {
        debugPrint('NotificationService: Android channel setup error: $e');
      }
    }

    _isInitialized = true;
  }

  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
    bool isBreak = false,
  }) async {
    if (!isSupportedPlatform || !_isInitialized) return;
    final opId = ++_timerNotificationOpId;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final remainingMs =
        targetEndTimeEpochMs != null ? targetEndTimeEpochMs - nowMs : null;
    final useNativeChronometer =
        !isPaused && remainingMs != null && remainingMs > 0;

    final String title;
    final String contentText;
    final String subText;

    if (isBreak) {
      title = useNativeChronometer
          ? 'Recharging'
          : 'Recharging · $formattedTimeRemaining';
      contentText = 'Feeds remain locked · Recharge stamina';
      subText = 'Recharging';
    } else if (isPaused) {
      title = 'Paused ($formattedTimeRemaining)';
      contentText = taskGoal.isNotEmpty ? taskGoal : 'Stay focused';
      subText = 'Paused';
    } else {
      title = useNativeChronometer
          ? 'Focus block'
          : 'Focus block · $formattedTimeRemaining';
      contentText = taskGoal.isNotEmpty ? taskGoal : 'Stay focused';
      subText = 'Active Focus';
    }

    final androidDetails = AndroidNotificationDetails(
      timerChannelId,
      timerChannelName,
      channelDescription: timerChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      category: AndroidNotificationCategory.stopwatch,
      visibility: NotificationVisibility.public,
      ongoing: !isPaused,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      playSound: false,
      enableVibration: false,
      showWhen: useNativeChronometer,
      when: useNativeChronometer ? targetEndTimeEpochMs : null,
      usesChronometer: useNativeChronometer,
      chronometerCountDown: useNativeChronometer,
      timeoutAfter: useNativeChronometer ? remainingMs + 1500 : null,
      subText: subText,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    try {
      if (opId != _timerNotificationOpId) return;
      await _notificationsPlugin.show(
        ongoingNotificationId,
        title,
        contentText,
        notificationDetails,
      );
      if (opId != _timerNotificationOpId) {
        await _notificationsPlugin.cancel(ongoingNotificationId);
      }
    } catch (e) {
      debugPrint('NotificationService: failed to show ongoing timer: $e');
    }
  }

  Future<void> cancelTimerNotification() async {
    ++_timerNotificationOpId;
    if (!isSupportedPlatform || !_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(ongoingNotificationId);
    } catch (e) {
      debugPrint(
          'NotificationService: failed to cancel timer notification: $e');
    }
  }

  Future<void> scheduleSessionCompletionNotification({
    required DateTime targetEndTime,
    required String goal,
    bool isBreak = false,
  }) async {
    if (!isSupportedPlatform || !_isInitialized) return;
    await cancelSessionCompletionNotification();

    final scheduledDate = tz.TZDateTime.from(targetEndTime, tz.local);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      completionChannelId,
      completionChannelName,
      channelDescription: completionChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      enableVibration: true,
      playSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final cleanGoal = goal.trim().isNotEmpty ? goal.trim() : 'Focus Block';
    final alertTitle = isBreak ? 'Recharge complete' : 'Focus block complete';
    final hasCustomGoal = cleanGoal.isNotEmpty &&
        cleanGoal != 'Focus Block' &&
        cleanGoal != '5-Minute Recharge Break';
    final alertBody = isBreak
        ? (hasCustomGoal
            ? 'Ready to continue "$cleanGoal"?'
            : 'Ready for your next focus block?')
        : 'Session on "$cleanGoal" completed.';

    try {
      await _notificationsPlugin.zonedSchedule(
        sessionCompletionNotificationId,
        alertTitle,
        alertBody,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint(
        'NotificationService: exact alarm unavailable, falling back to inexact: $e',
      );
      try {
        await _notificationsPlugin.zonedSchedule(
          sessionCompletionNotificationId,
          alertTitle,
          alertBody,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (fallbackError) {
        debugPrint(
          'NotificationService: failed to schedule session completion alarm: $fallbackError',
        );
      }
    }
  }

  Future<void> cancelSessionCompletionNotification() async {
    if (!isSupportedPlatform || !_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(sessionCompletionNotificationId);
    } catch (e) {
      debugPrint(
          'NotificationService: failed to cancel session completion notification: $e');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }
    return scheduledDate;
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = 'Time to focus',
    String body = 'Start your daily focus block and crush your goals.',
  }) async {
    if (!isSupportedPlatform || !_isInitialized) return;
    await cancelDailyReminder();

    const androidDetails = AndroidNotificationDetails(
      reminderChannelId,
      reminderChannelName,
      channelDescription: reminderChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        dailyReminderNotificationId,
        title,
        body,
        _nextInstanceOfTime(hour, minute),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('NotificationService: failed to schedule daily reminder: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    if (!isSupportedPlatform || !_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(dailyReminderNotificationId);
    } catch (e) {
      debugPrint('NotificationService: failed to cancel daily reminder: $e');
    }
  }

  Future<void> showAutoShieldNotification({required String timeRange}) async {
    if (!isSupportedPlatform || !_isInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      autoShieldChannelId,
      autoShieldChannelName,
      channelDescription: autoShieldChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      subText: 'Scheduled Auto-Shield',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    try {
      await _notificationsPlugin.show(
        autoShieldNotificationId,
        'Brainrot Shield Active',
        'Scheduled Auto-Shield Active ($timeRange)',
        notificationDetails,
      );
    } catch (e) {
      debugPrint(
          'NotificationService: failed to show auto-shield notification: $e');
    }
  }

  Future<void> cancelAutoShieldNotification() async {
    if (!isSupportedPlatform || !_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(autoShieldNotificationId);
    } catch (e) {
      debugPrint(
          'NotificationService: failed to cancel auto-shield notification: $e');
    }
  }
}
