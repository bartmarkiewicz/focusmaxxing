import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

void main() {
  group('SessionEntity', () {
    const entity = SessionEntity(
      id: 1,
      taskGoal: 'Code Review',
      sessionType: SessionType.focus,
      targetDurationSeconds: 1500,
      actualDurationSeconds: 1200,
      startTimeEpochMs: 1000,
      endTimeEpochMs: 2200,
      status: SessionStatus.lockedIn,
    );

    test('props equality and hashCode', () {
      const entity2 = SessionEntity(
        id: 1,
        taskGoal: 'Code Review',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1200,
        startTimeEpochMs: 1000,
        endTimeEpochMs: 2200,
        status: SessionStatus.lockedIn,
      );

      expect(entity, equals(entity2));
      expect(entity.hashCode, equals(entity2.hashCode));
    });

    test('copyWith updates specified fields and preserves others', () {
      final updated = entity.copyWith(
        id: 2,
        taskGoal: 'Updated Goal',
        sessionType: SessionType.shortBreak,
        targetDurationSeconds: 300,
        actualDurationSeconds: 300,
        startTimeEpochMs: 3000,
        endTimeEpochMs: 3300,
        status: SessionStatus.derailed,
      );

      expect(updated.id, 2);
      expect(updated.taskGoal, 'Updated Goal');
      expect(updated.sessionType, SessionType.shortBreak);
      expect(updated.targetDurationSeconds, 300);
      expect(updated.actualDurationSeconds, 300);
      expect(updated.startTimeEpochMs, 3000);
      expect(updated.endTimeEpochMs, 3300);
      expect(updated.status, SessionStatus.derailed);

      final noChange = entity.copyWith();
      expect(noChange, equals(entity));
    });
  });
}
