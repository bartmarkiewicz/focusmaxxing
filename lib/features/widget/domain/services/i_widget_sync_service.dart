abstract interface class IWidgetSyncService {
  Future<void> updateGlanceableWidget({
    required int todayMinutes,
    required int activeStreak,
  });
}
