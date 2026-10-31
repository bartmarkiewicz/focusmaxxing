import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Persisted session lifecycle state for crash-recovery tombstones.
enum TombstoneSessionStatus {
  running,
  paused,
  completed,
  breakRunning,
  breakCompleted;

  static TombstoneSessionStatus? tryParse(String? raw) {
    if (raw == null) return null;
    for (final value in TombstoneSessionStatus.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// Represents a persisted crash-recovery tombstone for an active focus or break session.
class ActiveSessionTombstoneEntity extends Equatable {
  const ActiveSessionTombstoneEntity({
    this.sessionId,
    required this.status,
    required this.taskGoal,
    this.linkedBacklogTaskId,
    required this.focusDurationSeconds,
    required this.targetDurationSeconds,
    required this.remainingSeconds,
    this.targetEndTimeEpochMs,
    required this.savedAtEpochMs,
  });

  final int? sessionId;
  final TombstoneSessionStatus status;
  final String taskGoal;
  final int? linkedBacklogTaskId;
  final int focusDurationSeconds;
  final int targetDurationSeconds;
  final int remainingSeconds;
  final int? targetEndTimeEpochMs;
  final int savedAtEpochMs;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'status': status.name,
      'taskGoal': taskGoal,
      'linkedBacklogTaskId': linkedBacklogTaskId,
      'focusDurationSeconds': focusDurationSeconds,
      'targetDurationSeconds': targetDurationSeconds,
      'remainingSeconds': remainingSeconds,
      'targetEndTimeEpochMs': targetEndTimeEpochMs,
      'savedAtEpochMs': savedAtEpochMs,
    };
  }

  String toJson() => jsonEncode(toMap());

  static ActiveSessionTombstoneEntity? tryFromJson(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return null;
      final rawStatus = decoded['status'];
      final rawTaskGoal = decoded['taskGoal'];
      final rawFocusDuration = decoded['focusDurationSeconds'];
      final rawTargetDuration = decoded['targetDurationSeconds'];
      final rawRemaining = decoded['remainingSeconds'];
      final rawSavedAt = decoded['savedAtEpochMs'];
      final rawSessionId = decoded['sessionId'];
      final rawLinkedTaskId = decoded['linkedBacklogTaskId'];
      final rawTargetEndMs = decoded['targetEndTimeEpochMs'];

      if (rawStatus is! String ||
          rawTaskGoal is! String ||
          rawFocusDuration is! int ||
          rawTargetDuration is! int ||
          rawRemaining is! int ||
          rawSavedAt is! int ||
          (rawSessionId != null && rawSessionId is! int) ||
          (rawLinkedTaskId != null && rawLinkedTaskId is! int) ||
          (rawTargetEndMs != null && rawTargetEndMs is! int)) {
        return null;
      }

      final parsedStatus = TombstoneSessionStatus.tryParse(rawStatus);
      if (parsedStatus == null ||
          rawFocusDuration <= 0 ||
          rawTargetDuration <= 0) {
        return null;
      }

      return ActiveSessionTombstoneEntity(
        sessionId: rawSessionId as int?,
        status: parsedStatus,
        taskGoal: rawTaskGoal,
        linkedBacklogTaskId: rawLinkedTaskId as int?,
        focusDurationSeconds: rawFocusDuration,
        targetDurationSeconds: rawTargetDuration,
        remainingSeconds: rawRemaining,
        targetEndTimeEpochMs: rawTargetEndMs as int?,
        savedAtEpochMs: rawSavedAt,
      );
    } on Exception catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
        sessionId,
        status,
        taskGoal,
        linkedBacklogTaskId,
        focusDurationSeconds,
        targetDurationSeconds,
        remainingSeconds,
        targetEndTimeEpochMs,
        savedAtEpochMs,
      ];
}
