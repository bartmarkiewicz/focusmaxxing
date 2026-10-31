import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/constants/schedule_constants.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Retained as a backwards-compatibility callback for legacy alarms and the unit test harness.
/// Production alarms are handled directly by native [AutoShieldAlarmReceiver].
@pragma('vm:entry-point')
Future<void> autoShieldStartAlarmCallback([
  @visibleForTesting DateTime? nowOverride,
]) async {
  final now = nowOverride ?? DateTime.now();
  final prefs = await SharedPreferences.getInstance();
  final rawJson = prefs.getString(ScheduleConstants.schedulePrefsKey);
  if (rawJson == null) return;

  final activeDays =
      prefs.getStringList(ScheduleConstants.scheduleActiveDaysPrefsKey) ??
          ['1', '2', '3', '4', '5'];

  int? startHour;
  int? startMinute;
  int? endHour;
  int? endMinute;
  var isEnabled = true;
  String? timeRange;
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, dynamic>) {
      final rawEnabled = decoded['isEnabled'];
      if (rawEnabled is bool) {
        isEnabled = rawEnabled;
      }
      final rawStartHour = decoded['startHour'];
      final rawStartMinute = decoded['startMinute'];
      final rawEndHour = decoded['endHour'];
      final rawEndMinute = decoded['endMinute'];
      if (rawStartHour is int) startHour = rawStartHour;
      if (rawStartMinute is int) startMinute = rawStartMinute;
      if (rawEndHour is int) endHour = rawEndHour;
      if (rawEndMinute is int) endMinute = rawEndMinute;
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
    }
  } on Exception catch (_) {}

  if (!isEnabled) return;

  var effectiveWeekday = now.weekday;
  if (startHour != null &&
      startMinute != null &&
      endHour != null &&
      endMinute != null) {
    final startTotal = startHour * 60 + startMinute;
    final endTotal = endHour * 60 + endMinute;
    final currentTotal = now.hour * 60 + now.minute;
    if (startTotal > endTotal && currentTotal < endTotal) {
      effectiveWeekday =
          now.weekday == DateTime.monday ? DateTime.sunday : now.weekday - 1;
    }
  }

  if (!activeDays.contains(effectiveWeekday.toString())) {
    return;
  }

  const channel = MethodChannel('com.focusmaxxing/shield');
  final blockedPackages =
      prefs.getStringList(ScheduleConstants.schedulePackagesPrefsKey) ??
          <String>[];

  try {
    await channel.invokeMethod<bool>('startShield', {
      'packages': blockedPackages,
      'isScheduled': true,
      if (timeRange != null) 'timeRange': timeRange,
    });
  } on Exception catch (_) {}
}

/// Retained as a backwards-compatibility callback for legacy alarms and the unit test harness.
/// Production alarms are handled directly by native [AutoShieldAlarmReceiver].
@pragma('vm:entry-point')
Future<void> autoShieldEndAlarmCallback() async {
  const channel = MethodChannel('com.focusmaxxing/shield');
  try {
    await channel.invokeMethod<bool>('stopShield', {'force': true});
  } on Exception catch (_) {}
}

abstract interface class IScheduleAlarmDataSource {
  Future<bool> scheduleAlarms(ScheduleConfigEntity schedule);
  Future<bool> cancelAlarms();
}

class ScheduleAlarmDataSourceImpl implements IScheduleAlarmDataSource {
  static const int startAlarmId = ScheduleConstants.startAlarmId;
  static const int endAlarmId = ScheduleConstants.endAlarmId;

  final bool isTestMode;
  final MethodChannel? methodChannel;
  final DateTime Function() _clock;
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
    this.methodChannel,
    DateTime Function()? clock,
    this.alarmPeriodicOverride,
    this.alarmCancelOverride,
  }) : _clock = clock ?? DateTime.now;

  /// Computes the next start and end alarm times using local calendar arithmetic
  /// so Daylight Saving Time (23h / 25h days) never causes a 1-hour drift, and
  /// active overnight windows activate immediately without a 24-hour delay.
  static ({DateTime nextStart, DateTime nextEnd}) computeNextAlarmTimes(
    ScheduleConfigEntity schedule,
    DateTime now,
  ) {
    final activeEvaluation = schedule.copyWith(isEnabled: true);
    if (activeEvaluation.isWithinSchedule(now)) {
      var nextEnd = DateTime(
        now.year,
        now.month,
        now.day,
        schedule.endHour,
        schedule.endMinute,
      );
      if (!nextEnd.isAfter(now)) {
        nextEnd = DateTime(
          now.year,
          now.month,
          now.day + 1,
          schedule.endHour,
          schedule.endMinute,
        );
      }
      return (nextStart: now, nextEnd: nextEnd);
    }

    var dayOffset = 0;
    var nextStart = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.startHour,
      schedule.startMinute,
    );
    if (!nextStart.isAfter(now)) {
      dayOffset = 1;
      nextStart = DateTime(
        now.year,
        now.month,
        now.day + 1,
        schedule.startHour,
        schedule.startMinute,
      );
    }

    if (schedule.activeDays.isNotEmpty) {
      for (var i = 0; i < 7; i++) {
        if (schedule.isActiveOn(nextStart.weekday)) {
          break;
        }
        dayOffset++;
        nextStart = DateTime(
          now.year,
          now.month,
          now.day + dayOffset,
          schedule.startHour,
          schedule.startMinute,
        );
      }
    }

    final nextEnd = schedule.isOvernight
        ? DateTime(
            nextStart.year,
            nextStart.month,
            nextStart.day + 1,
            schedule.endHour,
            schedule.endMinute,
          )
        : DateTime(
            nextStart.year,
            nextStart.month,
            nextStart.day,
            schedule.endHour,
            schedule.endMinute,
          );

    return (nextStart: nextStart, nextEnd: nextEnd);
  }

  bool get _canUseAlarmManager =>
      methodChannel != null || (!isTestMode && !kIsWeb && Platform.isAndroid);

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

    if (alarmPeriodicOverride != null) {
      try {
        final now = _clock();
        final (:nextStart, :nextEnd) = computeNextAlarmTimes(schedule, now);
        final startAnchor = DateTime(
          nextStart.year,
          nextStart.month,
          nextStart.day,
          schedule.startHour,
          schedule.startMinute,
        );
        final nextDayStartAnchor = DateTime(
          nextStart.year,
          nextStart.month,
          nextStart.day + 1,
          schedule.startHour,
          schedule.startMinute,
        );
        final startPeriod = nextDayStartAnchor.difference(startAnchor);

        final endAnchor = DateTime(
          nextEnd.year,
          nextEnd.month,
          nextEnd.day,
          schedule.endHour,
          schedule.endMinute,
        );
        final nextDayEndAnchor = DateTime(
          nextEnd.year,
          nextEnd.month,
          nextEnd.day + 1,
          schedule.endHour,
          schedule.endMinute,
        );
        final endPeriod = nextDayEndAnchor.difference(endAnchor);

        final startScheduled = await alarmPeriodicOverride!(
          startPeriod,
          startAlarmId,
          autoShieldStartAlarmCallback,
          startAt: nextStart,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );

        final endScheduled = await alarmPeriodicOverride!(
          endPeriod,
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

    if (!_canUseAlarmManager) {
      return true;
    }

    try {
      final channel = methodChannel ?? const MethodChannel('com.focusmaxxing/shield');
      final scheduled = await channel.invokeMethod<bool>('scheduleAlarms', {
        'startHour': schedule.startHour,
        'startMinute': schedule.startMinute,
        'endHour': schedule.endHour,
        'endMinute': schedule.endMinute,
      });
      return scheduled ?? true;
    } catch (e) {
      throw ScheduleException('Failed to configure OS alarms: $e');
    }
  }

  @override
  Future<bool> cancelAlarms() async {
    if (alarmCancelOverride != null) {
      try {
        final startCancelled = await alarmCancelOverride!(startAlarmId);
        final endCancelled = await alarmCancelOverride!(endAlarmId);
        return startCancelled && endCancelled;
      } catch (e) {
        throw ScheduleException('Failed to cancel OS alarms: $e');
      }
    }

    if (!_canUseAlarmManager) {
      return true;
    }

    try {
      final channel = methodChannel ?? const MethodChannel('com.focusmaxxing/shield');
      final cancelled = await channel.invokeMethod<bool>('cancelAlarms');
      return cancelled ?? true;
    } catch (e) {
      throw ScheduleException('Failed to cancel OS alarms: $e');
    }
  }
}
