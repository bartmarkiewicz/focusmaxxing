import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class _FakeFlutterLocalNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  int? lastCancelledId;
  bool cancelAllCalled = false;
  int? lastShownId;
  String? lastShownTitle;
  String? lastShownBody;
  NotificationDetails? lastShownDetails;
  int? lastScheduledId;
  String? lastScheduledTitle;
  String? lastScheduledBody;
  tz.TZDateTime? lastScheduledDate;
  bool shouldThrowOnSchedule = false;

  @override
  Future<void> cancel(int id, {String? tag}) async {
    lastCancelledId = id;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalled = true;
  }

  @override
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {
    lastShownId = id;
    lastShownTitle = title;
    lastShownBody = body;
    lastShownDetails = notificationDetails;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    AndroidScheduleMode? androidScheduleMode,
    bool? androidAllowWhileIdle,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation =
        UILocalNotificationDateInterpretation.absoluteTime,
  }) async {
    if (shouldThrowOnSchedule) {
      throw Exception('Platform security error or exact alarm restricted');
    }
    lastScheduledId = id;
    lastScheduledTitle = title;
    lastScheduledBody = body;
    lastScheduledDate = scheduledDate;
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);

  late _FakeFlutterLocalNotificationsPlugin fakePlugin;
  late NotificationService service;

  setUp(() {
    fakePlugin = _FakeFlutterLocalNotificationsPlugin();
    service = NotificationService(notificationsPlugin: fakePlugin);
    service.isSupportedPlatformOverride = true;
    service.setInitializedForTesting(true);
  });

  group('NotificationService', () {
    test('uses monochrome @drawable/ic_notification status bar small icon', () {
      expect(
        NotificationService.androidSmallIcon,
        equals('@drawable/ic_notification'),
      );
    });

    test(
        'showOngoingTimer displays silent low-importance active countdown notification with native chronometer',
        () async {
      final targetEndMs = DateTime.now()
          .add(const Duration(minutes: 25))
          .millisecondsSinceEpoch;

      await service.showOngoingTimer(
        taskGoal: 'Deep Work',
        formattedTimeRemaining: '24:35',
        isPaused: false,
        targetEndTimeEpochMs: targetEndMs,
      );

      expect(fakePlugin.lastShownId, NotificationService.ongoingNotificationId);
      expect(fakePlugin.lastShownTitle, 'Focus block');
      expect(fakePlugin.lastShownBody, 'Deep Work');

      final android = fakePlugin.lastShownDetails?.android;
      expect(android, isNotNull);
      expect(android!.channelId, NotificationService.timerChannelId);
      expect(
        NotificationService.timerChannelId,
        isNot(equals(NotificationService.legacyTimerChannelId)),
      );
      expect(android.importance, Importance.low);
      expect(android.priority, Priority.low);
      expect(android.silent, isTrue);
      expect(android.onlyAlertOnce, isTrue);
      expect(android.playSound, isFalse);
      expect(android.enableVibration, isFalse);
      expect(android.usesChronometer, isTrue);
      expect(android.chronometerCountDown, isTrue);
      expect(android.showWhen, isTrue);
      expect(android.when, targetEndMs);
    });

    test('showOngoingTimer displays paused status when isPaused is true',
        () async {
      await service.showOngoingTimer(
        taskGoal: 'Clean Room',
        formattedTimeRemaining: '10:00',
        isPaused: true,
      );

      expect(fakePlugin.lastShownId, NotificationService.ongoingNotificationId);
      expect(fakePlugin.lastShownTitle, contains('Paused (10:00)'));
      expect(fakePlugin.lastShownBody, 'Clean Room');

      final android = fakePlugin.lastShownDetails?.android;
      expect(android, isNotNull);
      expect(android!.importance, Importance.low);
      expect(android.priority, Priority.low);
      expect(android.usesChronometer, isFalse);
      expect(android.showWhen, isFalse);
    });

    test(
        'showOngoingTimer falls back to static time title without chronometer when targetEndTimeEpochMs is null',
        () async {
      await service.showOngoingTimer(
        taskGoal: 'Fallback Goal',
        formattedTimeRemaining: '24:35',
        isPaused: false,
      );

      expect(fakePlugin.lastShownId, NotificationService.ongoingNotificationId);
      expect(fakePlugin.lastShownTitle, 'Focus block · 24:35');
      expect(fakePlugin.lastShownBody, 'Fallback Goal');

      final android = fakePlugin.lastShownDetails?.android;
      expect(android, isNotNull);
      expect(android!.usesChronometer, isFalse);
      expect(android.showWhen, isFalse);
    });

    test(
        'showOngoingTimer displays recharging title and feeds remain locked body when isBreak is true',
        () async {
      final targetEndMs = DateTime.now()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch;

      await service.showOngoingTimer(
        taskGoal: 'Feeds remain locked',
        formattedTimeRemaining: '04:32',
        isPaused: false,
        targetEndTimeEpochMs: targetEndMs,
        isBreak: true,
      );

      expect(fakePlugin.lastShownId, NotificationService.ongoingNotificationId);
      expect(fakePlugin.lastShownTitle, 'Recharging');
      expect(fakePlugin.lastShownBody, contains('Feeds remain locked'));
      expect(fakePlugin.lastShownDetails?.android?.subText, 'Recharging');
    });

    test('cancelTimerNotification cancels ongoing notification', () async {
      await service.cancelTimerNotification();
      expect(fakePlugin.lastCancelledId,
          NotificationService.ongoingNotificationId);
    });

    test(
        'scheduleSessionCompletionNotification schedules high-priority alarm for future time',
        () async {
      final targetEndTime = DateTime.now().add(const Duration(minutes: 25));

      await service.scheduleSessionCompletionNotification(
        targetEndTime: targetEndTime,
        goal: 'Write Architecture Spec',
      );

      expect(fakePlugin.lastScheduledId,
          NotificationService.sessionCompletionNotificationId);
      expect(fakePlugin.lastScheduledTitle, 'Focus block complete');
      expect(fakePlugin.lastScheduledBody, contains('Write Architecture Spec'));
      expect(fakePlugin.lastScheduledDate, isNotNull);
    });

    test(
        'scheduleSessionCompletionNotification schedules Recharge Complete title when isBreak is true',
        () async {
      final targetEndTime = DateTime.now().add(const Duration(minutes: 5));

      await service.scheduleSessionCompletionNotification(
        targetEndTime: targetEndTime,
        goal: 'Draft PRD',
        isBreak: true,
      );

      expect(fakePlugin.lastScheduledId,
          NotificationService.sessionCompletionNotificationId);
      expect(fakePlugin.lastScheduledTitle, 'Recharge complete');
      expect(fakePlugin.lastScheduledBody, contains('Ready to continue "Draft PRD"?'));
    });

    test(
        'scheduleSessionCompletionNotification defaults to Focus Block when goal is empty',
        () async {
      final targetEndTime = DateTime.now().add(const Duration(minutes: 15));

      await service.scheduleSessionCompletionNotification(
        targetEndTime: targetEndTime,
        goal: '   ',
      );

      expect(fakePlugin.lastScheduledBody, contains('Focus Block'));
    });

    test('scheduleSessionCompletionNotification ignores past target end time',
        () async {
      final pastTime = DateTime.now().subtract(const Duration(minutes: 5));

      await service.scheduleSessionCompletionNotification(
        targetEndTime: pastTime,
        goal: 'Past task',
      );

      expect(fakePlugin.lastScheduledId, isNull);
    });

    test(
        'scheduleSessionCompletionNotification catches exact alarm exceptions safely without throwing',
        () async {
      fakePlugin.shouldThrowOnSchedule = true;
      final targetEndTime = DateTime.now().add(const Duration(minutes: 20));

      // Should not throw an exception even if zonedSchedule throws
      await expectLater(
        service.scheduleSessionCompletionNotification(
          targetEndTime: targetEndTime,
          goal: 'Safe Error Handling',
        ),
        completes,
      );
    });

    test(
        'cancelSessionCompletionNotification cancels session completion notification',
        () async {
      await service.cancelSessionCompletionNotification();
      expect(fakePlugin.lastCancelledId,
          NotificationService.sessionCompletionNotificationId);
    });

    test('cancelDailyReminder cancels reminder notification', () async {
      await service.cancelDailyReminder();
      expect(fakePlugin.lastCancelledId,
          NotificationService.dailyReminderNotificationId);
    });

    test('cancelAutoShieldNotification cancels auto shield notification',
        () async {
      await service.cancelAutoShieldNotification();
      expect(fakePlugin.lastCancelledId,
          NotificationService.autoShieldNotificationId);
    });

    test('methods no-op when platform is not supported or not initialized',
        () async {
      service.isSupportedPlatformOverride = false;

      await service.showOngoingTimer(
        taskGoal: 'Ignored',
        formattedTimeRemaining: '25:00',
        isPaused: false,
      );
      await service.cancelTimerNotification();
      await service.cancelSessionCompletionNotification();

      expect(fakePlugin.lastShownId, isNull);
      expect(fakePlugin.lastCancelledId, isNull);
    });
  });
}
