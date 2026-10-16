import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const int ongoingNotificationId = 1001;
  static const int dailyReminderNotificationId = 1002;
  static const int autoShieldNotificationId = 1003;

  static const String timerChannelId = 'focusmaxxing_timer_channel';
  static const String timerChannelName = 'Focus Countdown';
  static const String timerChannelDescription =
      'Ongoing countdown notification for active focus sessions';

  static const String reminderChannelId = 'focusmaxxing_reminder_channel';
  static const String reminderChannelName = 'Daily Focus Reminders';
  static const String reminderChannelDescription =
      'Scheduled notifications prompting daily focus blocks';

  static const String autoShieldChannelId = 'focusmaxxing_schedule_channel';
  static const String autoShieldChannelName = 'Scheduled Auto-Shield';
  static const String autoShieldChannelDescription =
      'Notifications for scheduled work/study focus shielding';

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

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  Future<void> showOngoingTimer({
    required String taskGoal,
    required String formattedTimeRemaining,
    required bool isPaused,
    int? targetEndTimeEpochMs,
  }) async {
    if (!isSupportedPlatform || !_isInitialized) return;

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
    if (!isSupportedPlatform || !_isInitialized) return;
    await _notificationsPlugin.cancel(ongoingNotificationId);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = 'Time to Lock In 🚀',
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
  }

  Future<void> cancelDailyReminder() async {
    if (!isSupportedPlatform || !_isInitialized) return;
    await _notificationsPlugin.cancel(dailyReminderNotificationId);
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

    await _notificationsPlugin.show(
      autoShieldNotificationId,
      'Brainrot Shield Active',
      'Scheduled Auto-Shield Active ($timeRange)',
      notificationDetails,
    );
  }

  Future<void> cancelAutoShieldNotification() async {
    if (!isSupportedPlatform || !_isInitialized) return;
    await _notificationsPlugin.cancel(autoShieldNotificationId);
  }
}
