import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const int ongoingNotificationId = 1001;
  static const int dailyReminderNotificationId = 1002;

  static const String timerChannelId = 'focusmaxxing_timer_channel';
  static const String timerChannelName = 'Focus Countdown';
  static const String timerChannelDescription =
      'Ongoing countdown notification for active focus sessions';

  static const String reminderChannelId = 'focusmaxxing_reminder_channel';
  static const String reminderChannelName = 'Daily Focus Reminders';
  static const String reminderChannelDescription =
      'Scheduled notifications prompting daily focus blocks';

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  NotificationService({FlutterLocalNotificationsPlugin? notificationsPlugin})
      : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  bool get isSupportedPlatform =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS);

  Future<void> init() async {
    if (_isInitialized) return;
    if (!isSupportedPlatform) {
      _isInitialized = true;
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    _isInitialized = true;
  }

  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
  }) async {
    if (!isSupportedPlatform) return;

    final title = isPaused
        ? '⏸ Paused ($formattedTimeRemaining) · Lock In'
        : '🚀 $formattedTimeRemaining Remaining';

    final useNativeChronometer = !isPaused && targetEndTimeEpochMs != null;

    final androidDetails = AndroidNotificationDetails(
      timerChannelId,
      timerChannelName,
      channelDescription: timerChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: !isPaused,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      when: useNativeChronometer ? targetEndTimeEpochMs : null,
      usesChronometer: useNativeChronometer,
      chronometerCountDown: useNativeChronometer,
      subText: isPaused ? 'Paused' : 'Active Focus',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    await _notificationsPlugin.show(
      ongoingNotificationId,
      title,
      taskGoal.isNotEmpty ? taskGoal : 'Stay locked in',
      notificationDetails,
    );
  }

  Future<void> cancelTimerNotification() async {
    if (!isSupportedPlatform) return;
    await _notificationsPlugin.cancel(ongoingNotificationId);
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = 'Time to Lock In 🚀',
    String body = 'Start your daily focus block and crush your goals.',
  }) async {
    if (!isSupportedPlatform) return;
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

    await _notificationsPlugin.periodicallyShow(
      dailyReminderNotificationId,
      title,
      body,
      RepeatInterval.daily,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelDailyReminder() async {
    if (!isSupportedPlatform) return;
    await _notificationsPlugin.cancel(dailyReminderNotificationId);
  }
}
