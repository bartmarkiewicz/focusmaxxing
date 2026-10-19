import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/constants/schedule_constants.dart';
import 'package:focusmaxxing/features/schedule/data/datasources/schedule_local_data_source.dart';
import 'package:focusmaxxing/features/schedule/data/models/schedule_config_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleLocalDataSourceImpl', () {
    late SharedPreferences prefs;
    late ScheduleLocalDataSourceImpl dataSource;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      dataSource = ScheduleLocalDataSourceImpl(prefs: prefs);
    });

    test('getSchedule returns default ScheduleConfigModel when no data saved',
        () async {
      final result = await dataSource.getSchedule();
      expect(result.isEnabled, isFalse);
      expect(result.startHour, equals(9));
      expect(result.endHour, equals(17));
    });

    test('saveSchedule persists JSON and getSchedule returns it', () async {
      const model = ScheduleConfigModel(
        isEnabled: true,
        startHour: 10,
        startMinute: 15,
        endHour: 18,
        endMinute: 45,
        activeDays: [1, 2, 3],
      );

      await dataSource.saveSchedule(model);

      final raw = prefs.getString(ScheduleConstants.schedulePrefsKey);
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['startHour'], equals(10));
      expect(decoded['isEnabled'], isTrue);

      final fetched = await dataSource.getSchedule();
      expect(fetched, equals(model));
    });
  });
}
