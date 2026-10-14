import 'package:equatable/equatable.dart';

class SessionType {
  const SessionType._();
  static const String focus = 'FOCUS';
  static const String shortBreak = 'SHORT_BREAK';
}

class SessionStatus {
  const SessionStatus._();
  static const String lockedIn = 'LOCKED_IN';
  static const String derailed = 'DERAILED';
  static const String cancelled = 'CANCELLED';
}

class SessionEntity extends Equatable {
  final int? id;
  final String taskGoal;
  final String sessionType;
  final int targetDurationSeconds;
  final int actualDurationSeconds;
  final int startTimeEpochMs;
  final int endTimeEpochMs;
  final String status;

  const SessionEntity({
    this.id,
    required this.taskGoal,
    required this.sessionType,
    required this.targetDurationSeconds,
    required this.actualDurationSeconds,
    required this.startTimeEpochMs,
    required this.endTimeEpochMs,
    required this.status,
  });

  SessionEntity copyWith({
    int? id,
    String? taskGoal,
    String? sessionType,
    int? targetDurationSeconds,
    int? actualDurationSeconds,
    int? startTimeEpochMs,
    int? endTimeEpochMs,
    String? status,
  }) {
    return SessionEntity(
      id: id ?? this.id,
      taskGoal: taskGoal ?? this.taskGoal,
      sessionType: sessionType ?? this.sessionType,
      targetDurationSeconds:
          targetDurationSeconds ?? this.targetDurationSeconds,
      actualDurationSeconds:
          actualDurationSeconds ?? this.actualDurationSeconds,
      startTimeEpochMs: startTimeEpochMs ?? this.startTimeEpochMs,
      endTimeEpochMs: endTimeEpochMs ?? this.endTimeEpochMs,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        taskGoal,
        sessionType,
        targetDurationSeconds,
        actualDurationSeconds,
        startTimeEpochMs,
        endTimeEpochMs,
        status,
      ];
}
