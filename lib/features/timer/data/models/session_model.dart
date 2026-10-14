import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

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
  });

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'] as int?,
      taskGoal: map['task_goal'] as String,
      sessionType: map['session_type'] as String,
      targetDurationSeconds: map['target_duration_seconds'] as int,
      actualDurationSeconds: map['actual_duration_seconds'] as int,
      startTimeEpochMs: map['start_time_epoch_ms'] as int,
      endTimeEpochMs: map['end_time_epoch_ms'] as int,
      status: map['status'] as String,
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
    );
  }
}
