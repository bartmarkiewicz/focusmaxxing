import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';

class SessionModel extends SessionEntity {
  const SessionModel({
    super.id,
    required super.taskGoal,
    required super.sessionType,
    required super.targetDurationSeconds,
    required super.actualDurationSeconds,
    required super.startTimeEpochMs,
    required super.endTimeEpochMs,
    required super.status,
    super.targets = const [],
  });

  factory SessionModel.fromMap(
    Map<String, dynamic> map, [
    List<SessionTargetAllocation>? targets,
  ]) {
    return SessionModel(
      id: (map['id'] as num?)?.toInt(),
      taskGoal: map['task_goal']?.toString() ?? 'Deep Work',
      sessionType: map['session_type']?.toString() ?? SessionType.focus,
      targetDurationSeconds:
          (map['target_duration_seconds'] as num?)?.toInt() ?? 0,
      actualDurationSeconds:
          (map['actual_duration_seconds'] as num?)?.toInt() ?? 0,
      startTimeEpochMs: (map['start_time_epoch_ms'] as num?)?.toInt() ?? 0,
      endTimeEpochMs: (map['end_time_epoch_ms'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? SessionStatus.cancelled,
      targets: targets ?? const [],
    );
  }

  factory SessionModel.fromEntity(SessionEntity entity) {
    return SessionModel(
      id: entity.id,
      taskGoal: entity.taskGoal,
      sessionType: entity.sessionType,
      targetDurationSeconds: entity.targetDurationSeconds,
      actualDurationSeconds: entity.actualDurationSeconds,
      startTimeEpochMs: entity.startTimeEpochMs,
      endTimeEpochMs: entity.endTimeEpochMs,
      status: entity.status,
      targets: entity.targets,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'task_goal': taskGoal,
      'session_type': sessionType,
      'target_duration_seconds': targetDurationSeconds,
      'actual_duration_seconds': actualDurationSeconds,
      'start_time_epoch_ms': startTimeEpochMs,
      'end_time_epoch_ms': endTimeEpochMs,
      'status': status,
    };
  }

  SessionEntity toEntity() {
    return SessionEntity(
      id: id,
      taskGoal: taskGoal,
      sessionType: sessionType,
      targetDurationSeconds: targetDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
      startTimeEpochMs: startTimeEpochMs,
      endTimeEpochMs: endTimeEpochMs,
      status: status,
      targets: targets,
    );
  }
}
