abstract interface class IWidgetSyncService {
  Future<void> updateGlanceableWidget({
    int? todayMinutes,
    int? activeStreak,
    bool? isRunning,
    int? targetEndTimeEpochMs,
    String? taskGoal,
  });
}
