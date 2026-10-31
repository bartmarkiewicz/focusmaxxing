import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/timer/domain/entities/active_session_tombstone_entity.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/recover_active_session_usecase.dart';

class _MockSessionRepository implements ISessionRepository {
  List<SessionEntity> sessions = <SessionEntity>[];
  Failure? failure;

  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async =>
      const Right<Failure, int>(1);

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async {
    if (failure != null) {
      return Left<Failure, List<SessionEntity>>(failure!);
    }
    return Right<Failure, List<SessionEntity>>(
      sessions
          .where(
            (s) => s.startTimeEpochMs >= startMs && s.startTimeEpochMs <= endMs,
          )
          .toList(),
    );
  }

  @override
  Future<Either<Failure, void>> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async =>
      const Right<Failure, void>(null);
}

void main() {
  late _MockSessionRepository repository;
  late RecoverActiveSessionUseCase useCase;

  setUp(() {
    repository = _MockSessionRepository();
    useCase = RecoverActiveSessionUseCase(repository);
  });

  group('ActiveSessionTombstoneEntity', () {
    test('serializes to JSON and deserializes back accurately', () {
      const entity = ActiveSessionTombstoneEntity(
        sessionId: 42,
        status: TombstoneSessionStatus.running,
        taskGoal: 'Deep Work Block',
        linkedBacklogTaskId: 7,
        focusDurationSeconds: 1500,
        targetDurationSeconds: 1500,
        remainingSeconds: 900,
        targetEndTimeEpochMs: 1700000900000,
        savedAtEpochMs: 1700000000000,
      );

      final rawJson = entity.toJson();
      final decoded = ActiveSessionTombstoneEntity.tryFromJson(rawJson);

      expect(decoded, equals(entity));
    });

    test('tryFromJson returns null for malformed or invalid JSON payloads', () {
      expect(ActiveSessionTombstoneEntity.tryFromJson(null), isNull);
      expect(ActiveSessionTombstoneEntity.tryFromJson(''), isNull);
      expect(ActiveSessionTombstoneEntity.tryFromJson('{bad json'), isNull);
      expect(
        ActiveSessionTombstoneEntity.tryFromJson(
          '{"status":"running","taskGoal":"Goal","focusDurationSeconds":0,"targetDurationSeconds":1500,"remainingSeconds":10,"savedAtEpochMs":1}',
        ),
        isNull,
      );
    });
  });

  group('RecoverActiveSessionUseCase', () {
    test(
        'returns latest unfinalized focus session initialized by StartSessionUseCase',
        () async {
      final now = DateTime(2026, 10, 31, 14, 10);
      final startMs = DateTime(2026, 10, 31, 14, 0).millisecondsSinceEpoch;
      final completedSession = SessionEntity(
        id: 1,
        taskGoal: 'Earlier Completed',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: startMs - 3600000,
        endTimeEpochMs: startMs - 2100000,
        status: SessionStatus.lockedIn,
      );
      final interruptedSession = SessionEntity(
        id: 2,
        taskGoal: 'Interrupted Focus',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 0,
        startTimeEpochMs: startMs,
        endTimeEpochMs: startMs + 1500 * 1000,
        status: SessionStatus.cancelled,
      );

      repository.sessions = <SessionEntity>[
        completedSession,
        interruptedSession,
      ];

      final result = await useCase(now: now);

      expect(result, Right<Failure, SessionEntity?>(interruptedSession));
    });

    test(
        'ignores explicitly cancelled sessions whose endTimeEpochMs was updated at cancellation',
        () async {
      final now = DateTime(2026, 10, 31, 14, 10);
      final startMs = DateTime(2026, 10, 31, 14, 0).millisecondsSinceEpoch;
      final explicitlyCancelled = SessionEntity(
        id: 3,
        taskGoal: 'User Aborted',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 120,
        startTimeEpochMs: startMs,
        endTimeEpochMs: startMs + 120 * 1000,
        status: SessionStatus.cancelled,
      );

      repository.sessions = <SessionEntity>[explicitlyCancelled];

      final result = await useCase(now: now);

      expect(result, const Right<Failure, SessionEntity?>(null));
    });

    test('propagates repository failure on database error', () async {
      repository.failure = const DatabaseFailure('SQLite read failed');

      final result = await useCase(now: DateTime(2026, 10, 31, 14, 0));

      expect(
        result,
        const Left<Failure, SessionEntity?>(
          DatabaseFailure('SQLite read failed'),
        ),
      );
    });
  });
}
