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
    required int todayMinutes,
    required int activeStreak,
  }) async {
    try {
      await _saveWidgetData<int>(keyTodayMinutes, todayMinutes);
      await _saveWidgetData<int>(keyActiveStreak, activeStreak);
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
