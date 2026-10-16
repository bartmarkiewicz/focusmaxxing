/// Constants for Scheduled Auto-Shield persistence, alarms, and notifications.
abstract final class ScheduleConstants {
  static const String schedulePrefsKey = 'scheduled_auto_shield_config';
  static const String scheduleActiveDaysPrefsKey =
      'scheduled_auto_shield_active_days';
  static const String schedulePackagesPrefsKey =
      'scheduled_auto_shield_packages';
  static const String proUnlockedPrefsKey = 'is_lifetime_pro';

  static const int startAlarmId = 2001;
  static const int endAlarmId = 2002;

  static const int autoShieldNotificationId = 1003;
  static const String scheduleNotificationChannelId =
      'focusmaxxing_schedule_channel';
  static const String scheduleNotificationChannelName = 'Scheduled Auto-Shield';
  static const String scheduleNotificationChannelDescription =
      'Notifications for scheduled work/study focus shielding';
}
