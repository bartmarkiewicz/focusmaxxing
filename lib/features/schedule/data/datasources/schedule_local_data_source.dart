import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/features/schedule/data/models/schedule_config_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class IScheduleLocalDataSource {
  Future<ScheduleConfigModel> getSchedule();
  Future<void> saveSchedule(ScheduleConfigModel schedule);
}

class ScheduleLocalDataSourceImpl implements IScheduleLocalDataSource {
  static const String schedulePrefsKey = 'scheduled_auto_shield_config';

  final SharedPreferences? prefs;

  ScheduleLocalDataSourceImpl({this.prefs});

  Future<SharedPreferences> _getPrefs() async =>
      prefs ?? await SharedPreferences.getInstance();

  @override
  Future<ScheduleConfigModel> getSchedule() async {
    try {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString(schedulePrefsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return const ScheduleConfigModel();
      }
      return ScheduleConfigModel.fromJson(jsonString);
    } catch (e) {
      throw ScheduleException('Failed to read schedule from storage: $e');
    }
  }

  @override
  Future<void> saveSchedule(ScheduleConfigModel schedule) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(schedulePrefsKey, schedule.toJson());
    } catch (e) {
      throw ScheduleException('Failed to save schedule to storage: $e');
    }
  }
}
