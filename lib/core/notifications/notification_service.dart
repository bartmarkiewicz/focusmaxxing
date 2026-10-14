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

  Future<void> init() async {
    if (_isInitialized) return;

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
  }) async {
    final title = isPaused
        ? '⏸ Paused ($formattedTimeRemaining) · Lock In'
        : '🚀 $formattedTimeRemaining Remaining';

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
      usesChronometer: false,
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
    await _notificationsPlugin.cancel(ongoingNotificationId);
  }

  Future<void> cancelDailyReminder() async {
    await _notificationsPlugin.cancel(dailyReminderNotificationId);
  }
}
