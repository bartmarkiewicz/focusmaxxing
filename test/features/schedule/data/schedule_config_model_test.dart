import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/schedule/data/models/schedule_config_model.dart';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';

void main() {
  group('ScheduleConfigModel', () {
    const testEntity = ScheduleConfigEntity(
      isEnabled: true,
      startHour: 8,
      startMinute: 30,
      endHour: 16,
      endMinute: 45,
      activeDays: [1, 2, 3, 4],
    );

    test('fromEntity converts domain entity accurately', () {
      final model = ScheduleConfigModel.fromEntity(testEntity);
      expect(model.isEnabled, isTrue);
      expect(model.startHour, equals(8));
      expect(model.startMinute, equals(30));
      expect(model.endHour, equals(16));
      expect(model.endMinute, equals(45));
      expect(model.activeDays, equals([1, 2, 3, 4]));
    });

    test('toMap and toJson serialize accurately', () {
      final model = ScheduleConfigModel.fromEntity(testEntity);
      final map = model.toMap();
      expect(map['isEnabled'], isTrue);
      expect(map['startHour'], equals(8));
      expect(map['startMinute'], equals(30));
      expect(map['endHour'], equals(16));
      expect(map['endMinute'], equals(45));
      expect(map['activeDays'], equals([1, 2, 3, 4]));

      final jsonString = model.toJson();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['startHour'], equals(8));
    });

    test('fromMap and fromJson deserialize correctly with full data', () {
      final map = {
        'isEnabled': true,
        'startHour': 9,
        'startMinute': 15,
        'endHour': 17,
        'endMinute': 30,
        'activeDays': [1, 3, 5],
      };
      final model = ScheduleConfigModel.fromMap(map);
      expect(model.isEnabled, isTrue);
      expect(model.startHour, equals(9));
      expect(model.startMinute, equals(15));
      expect(model.endHour, equals(17));
      expect(model.endMinute, equals(30));
      expect(model.activeDays, equals([1, 3, 5]));

      final fromJsonModel = ScheduleConfigModel.fromJson(jsonEncode(map));
      expect(fromJsonModel, equals(model));
    });

    test('fromMap falls back to defaults when fields are missing or corrupted',
        () {
      final model = ScheduleConfigModel.fromMap(const {});
      expect(model.isEnabled, isFalse);
      expect(model.startHour, equals(ScheduleConfigEntity.defaultStartHour));
      expect(
          model.startMinute, equals(ScheduleConfigEntity.defaultStartMinute));
      expect(model.endHour, equals(ScheduleConfigEntity.defaultEndHour));
      expect(model.endMinute, equals(ScheduleConfigEntity.defaultEndMinute));
      expect(model.activeDays, equals(ScheduleConfigEntity.defaultActiveDays));
    });
  });
}
