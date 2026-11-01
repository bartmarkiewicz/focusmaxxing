import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';

class SessionTargetAllocationModel extends SessionTargetAllocation {
  const SessionTargetAllocationModel({
    super.targetId,
    required super.targetName,
    required super.percentage,
    super.allocatedSeconds = 0,
    super.displayOrder = 1,
    super.colorHex = '#00E5FF',
    super.backlogTaskId,
  });

  factory SessionTargetAllocationModel.fromMap(Map<String, dynamic> map) {
    return SessionTargetAllocationModel(
      targetId: (map['target_id'] as num?)?.toInt(),
      targetName: map['name']?.toString() ??
          map['target_name']?.toString() ??
          'Focus Target',
      percentage: (map['allocated_percentage'] as num?)?.toInt() ?? 100,
      allocatedSeconds: (map['allocated_seconds'] as num?)?.toInt() ?? 0,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 1,
      colorHex: map['color_hex']?.toString() ?? '#00E5FF',
      backlogTaskId: (map['backlog_task_id'] as num?)?.toInt(),
    );
  }

  factory SessionTargetAllocationModel.fromEntity(
      SessionTargetAllocation entity) {
    return SessionTargetAllocationModel(
      targetId: entity.targetId,
      targetName: entity.targetName,
      percentage: entity.percentage,
      allocatedSeconds: entity.allocatedSeconds,
      displayOrder: entity.displayOrder,
      colorHex: entity.colorHex,
      backlogTaskId: entity.backlogTaskId,
    );
  }

  Map<String, dynamic> toSessionTargetMap(int sessionId) {
    return <String, dynamic>{
      'session_id': sessionId,
      if (targetId != null) 'target_id': targetId,
      'allocated_percentage': percentage,
      'allocated_seconds': allocatedSeconds,
      'display_order': displayOrder,
    };
  }

  SessionTargetAllocation toEntity() {
    return SessionTargetAllocation(
      targetId: targetId,
      targetName: targetName,
      percentage: percentage,
      allocatedSeconds: allocatedSeconds,
      displayOrder: displayOrder,
      colorHex: colorHex,
      backlogTaskId: backlogTaskId,
    );
  }
}
