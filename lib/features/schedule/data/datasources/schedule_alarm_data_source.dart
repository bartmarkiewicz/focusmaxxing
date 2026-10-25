import 'dart:convert';
import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/constants/schedule_constants.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void autoShieldStartAlarmCallback() async {
  final now = DateTime.now();
  final prefs = await SharedPreferences.getInstance();
  final rawJson = prefs.getString(ScheduleConstants.schedulePrefsKey);
  if (rawJson == null) return;

  final activeDays =
      prefs.getStringList(ScheduleConstants.scheduleActiveDaysPrefsKey) ??
          ['1', '2', '3', '4', '5'];
  if (!activeDays.contains(now.weekday.toString())) {
    return;
  }

  const channel = MethodChannel('com.focusmaxxing/shield');
  final blockedPackages =
      prefs.getStringList(ScheduleConstants.schedulePackagesPrefsKey) ??
          <String>[];
  String? timeRange;
  try {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final startHour = decoded['startHour'] as int?;
    final startMinute = decoded['startMinute'] as int?;
    final endHour = decoded['endHour'] as int?;
    final endMinute = decoded['endMinute'] as int?;
    if (startHour != null &&
        startMinute != null &&
        endHour != null &&
        endMinute != null) {
      final sH = startHour.toString().padLeft(2, '0');
      final sM = startMinute.toString().padLeft(2, '0');
      final eH = endHour.toString().padLeft(2, '0');
      final eM = endMinute.toString().padLeft(2, '0');
      timeRange = '$sH:$sM - $eH:$eM';
    }
  } catch (_) {}

  try {
    await channel.invokeMethod<bool>('startShield', {
      'packages': blockedPackages,
      'isScheduled': true,
      if (timeRange != null) 'timeRange': timeRange,
    });
  } catch (_) {
    // Ignore native background startup errors
  }
}

@pragma('vm:entry-point')
void autoShieldEndAlarmCallback() async {
  const channel = MethodChannel('com.focusmaxxing/shield');
  try {
    await channel.invokeMethod<bool>('stopShield', {'force': true});
  } catch (_) {
    // Ignore native background shutdown errors
  }
}

abstract interface class IScheduleAlarmDataSource {
  Future<bool> scheduleAlarms(ScheduleConfigEntity schedule);
  Future<bool> cancelAlarms();
}

class ScheduleAlarmDataSourceImpl implements IScheduleAlarmDataSource {
  static const int startAlarmId = ScheduleConstants.startAlarmId;
  static const int endAlarmId = ScheduleConstants.endAlarmId;

  final bool isTestMode;
  final Future<bool> Function(
    Duration period,
    int id,
    Function callback, {
    DateTime? startAt,
    bool exact,
    bool wakeup,
    bool rescheduleOnReboot,
  })? alarmPeriodicOverride;
  final Future<bool> Function(int id)? alarmCancelOverride;

  ScheduleAlarmDataSourceImpl({
    this.isTestMode = false,
    this.alarmPeriodicOverride,
    this.alarmCancelOverride,
  });

  bool get _canUseAlarmManager => !isTestMode && !kIsWeb && Platform.isAndroid;

  @override
  Future<bool> scheduleAlarms(ScheduleConfigEntity schedule) async {
    if (!schedule.isValid) {
      throw const ScheduleException('Cannot schedule invalid time range');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        ScheduleConstants.scheduleActiveDaysPrefsKey,
        schedule.activeDays.map((d) => d.toString()).toList(),
      );
    } catch (_) {}

    if (!_canUseAlarmManager && alarmPeriodicOverride == null) {
      return true;
    }

    try {
      final now = DateTime.now();
      var nextStart = DateTime(
        now.year,
        now.month,
        now.day,
        schedule.startHour,
        schedule.startMinute,
      );
      if (nextStart.isBefore(now)) {
        nextStart = nextStart.add(const Duration(days: 1));
      }

      var nextEnd = DateTime(
        now.year,
        now.month,
        now.day,
        schedule.endHour,
        schedule.endMinute,
      );
      if (nextEnd.isBefore(now)) {
        nextEnd = nextEnd.add(const Duration(days: 1));
      }

      final schedulePeriodic =
          alarmPeriodicOverride ?? AndroidAlarmManager.periodic;

      final startScheduled = await schedulePeriodic(
        const Duration(days: 1),
        startAlarmId,
        autoShieldStartAlarmCallback,
        startAt: nextStart,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      final endScheduled = await schedulePeriodic(
        const Duration(days: 1),
        endAlarmId,
        autoShieldEndAlarmCallback,
        startAt: nextEnd,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      return startScheduled && endScheduled;
    } catch (e) {
      throw ScheduleException('Failed to configure OS alarms: $e');
    }
  }

  @override
  Future<bool> cancelAlarms() async {
    if (!_canUseAlarmManager && alarmCancelOverride == null) {
      return true;
    }

    try {
      final cancelFunc = alarmCancelOverride ?? AndroidAlarmManager.cancel;
      final startCancelled = await cancelFunc(startAlarmId);
      final endCancelled = await cancelFunc(endAlarmId);
      return startCancelled && endCancelled;
    } catch (e) {
      throw ScheduleException('Failed to cancel OS alarms: $e');
    }
  }
}
