import 'dart:convert';
import 'package:focusmaxxing/features/schedule/domain/entities/schedule_config_entity.dart';

class ScheduleConfigModel extends ScheduleConfigEntity {
  const ScheduleConfigModel({
    super.isEnabled,
    super.startHour,
    super.startMinute,
    super.endHour,
    super.endMinute,
    super.activeDays,
  });

  factory ScheduleConfigModel.fromEntity(ScheduleConfigEntity entity) {
    return ScheduleConfigModel(
      isEnabled: entity.isEnabled,
      startHour: entity.startHour,
      startMinute: entity.startMinute,
      endHour: entity.endHour,
      endMinute: entity.endMinute,
      activeDays: entity.activeDays,
    );
  }

  factory ScheduleConfigModel.fromMap(Map<String, dynamic> map) {
    final rawDays = map['activeDays'];
    final activeDays = rawDays is List
        ? rawDays.map((e) => int.tryParse(e.toString()) ?? 1).toList()
        : ScheduleConfigEntity.defaultActiveDays;

    return ScheduleConfigModel(
      isEnabled: map['isEnabled'] as bool? ?? false,
      startHour: map['startHour'] as int? ?? ScheduleConfigEntity.defaultStartHour,
      startMinute:
          map['startMinute'] as int? ?? ScheduleConfigEntity.defaultStartMinute,
      endHour: map['endHour'] as int? ?? ScheduleConfigEntity.defaultEndHour,
      endMinute: map['endMinute'] as int? ?? ScheduleConfigEntity.defaultEndMinute,
      activeDays: activeDays,
    );
  }

  factory ScheduleConfigModel.fromJson(String source) =>
      ScheduleConfigModel.fromMap(jsonDecode(source) as Map<String, dynamic>);

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'activeDays': activeDays,
    };
  }

  String toJson() => jsonEncode(toMap());
}
