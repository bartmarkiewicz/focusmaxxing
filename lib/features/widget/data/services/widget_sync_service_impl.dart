import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:focusmaxxing/features/widget/domain/services/i_widget_sync_service.dart';
import 'package:home_widget/home_widget.dart';

typedef SaveWidgetDataFunction = Future<bool?> Function<T>(
  String id,
  T? data, {
  bool deleteFile,
  String? appGroupId,
});

typedef UpdateWidgetFunction = Future<bool?> Function({
  String? name,
  String? androidName,
  String? iOSName,
  String? qualifiedAndroidName,
});

class WidgetSyncServiceImpl implements IWidgetSyncService {
  static const String keyTodayMinutes = 'today_minutes';
  static const String keyActiveStreak = 'active_streak';
  static const String keyIsRunning = 'is_running';
  static const String keyTargetEndTime = 'target_end_epoch_ms';
  static const String keyTaskGoal = 'task_goal';
  static const String providerName = 'GlanceableDialWidgetProvider';
  static const String qualifiedProviderName =
      'com.bmrkiewicz.focusmaxxing.focusmaxxing.widget.GlanceableDialWidgetProvider';

  final SaveWidgetDataFunction _saveWidgetData;
  final UpdateWidgetFunction _updateWidget;

  WidgetSyncServiceImpl({
    SaveWidgetDataFunction? saveWidgetData,
    UpdateWidgetFunction? updateWidget,
  })  : _saveWidgetData = saveWidgetData ?? HomeWidget.saveWidgetData,
        _updateWidget = updateWidget ?? HomeWidget.updateWidget;

  @override
  Future<void> updateGlanceableWidget({
    int? todayMinutes,
    int? activeStreak,
    bool? isRunning,
    int? targetEndTimeEpochMs,
    String? taskGoal,
  }) async {
    try {
      if (todayMinutes != null) {
        await _saveWidgetData<int>(keyTodayMinutes, todayMinutes);
      }
      if (activeStreak != null) {
        await _saveWidgetData<int>(keyActiveStreak, activeStreak);
      }
      if (isRunning != null) {
        await _saveWidgetData<bool>(keyIsRunning, isRunning);
      }
      if (targetEndTimeEpochMs != null) {
        await _saveWidgetData<int>(keyTargetEndTime, targetEndTimeEpochMs);
      }
      if (taskGoal != null) {
        await _saveWidgetData<String>(keyTaskGoal, taskGoal);
      }
      await _updateWidget(
        name: providerName,
        androidName: 'widget.$providerName',
        qualifiedAndroidName: qualifiedProviderName,
      );
    } on PlatformException catch (e) {
      developer.log(
        'WidgetSyncServiceImpl: Failed to update home widget: $e',
        name: 'WidgetSyncServiceImpl',
      );
    } on MissingPluginException catch (e) {
      developer.log(
        'WidgetSyncServiceImpl: HomeWidget plugin not available: $e',
        name: 'WidgetSyncServiceImpl',
      );
    }
  }
}
