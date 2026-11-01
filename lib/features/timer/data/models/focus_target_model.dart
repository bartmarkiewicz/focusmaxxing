import 'package:focusmaxxing/features/timer/domain/entities/focus_target_entity.dart';

class FocusTargetModel extends FocusTargetEntity {
  const FocusTargetModel({
    super.id,
    required super.name,
    super.colorHex = '#00E5FF',
    super.isArchived = false,
    super.createdAt,
  });

  factory FocusTargetModel.fromMap(Map<String, dynamic> map) {
    return FocusTargetModel(
      id: (map['id'] as num?)?.toInt(),
      name: map['name']?.toString() ?? '',
      colorHex: map['color_hex']?.toString() ?? '#00E5FF',
      isArchived: ((map['is_archived'] as num?)?.toInt() ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  factory FocusTargetModel.fromEntity(FocusTargetEntity entity) {
    return FocusTargetModel(
      id: entity.id,
      name: entity.name,
      colorHex: entity.colorHex,
      isArchived: entity.isArchived,
      createdAt: entity.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'name': name,
      'color_hex': colorHex,
      'is_archived': isArchived ? 1 : 0,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  FocusTargetEntity toEntity() {
    return FocusTargetEntity(
      id: id,
      name: name,
      colorHex: colorHex,
      isArchived: isArchived,
      createdAt: createdAt,
    );
  }
}
