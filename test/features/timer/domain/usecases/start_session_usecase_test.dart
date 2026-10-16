import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';

class _MockSessionRepository implements ISessionRepository {
  SessionEntity? lastCreatedSession;

  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async {
    lastCreatedSession = session;
    return const Right<Failure, int>(1);
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async =>
      const Right<Failure, List<SessionEntity>>([]);

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
  late StartSessionUseCase useCase;

  setUp(() {
    repository = _MockSessionRepository();
    useCase = StartSessionUseCase(repository);
  });

  group('StartSessionUseCase', () {
    test('returns ValidationFailure when targetDurationSeconds <= 0', () async {
      final result = await useCase(
        taskGoal: 'Code',
        sessionType: SessionType.focus,
        targetDurationSeconds: 0,
      );

      expect(
        result,
        const Left<Failure, int>(
          ValidationFailure('Target duration must be greater than zero'),
        ),
      );
      expect(repository.lastCreatedSession, isNull);
    });

    test('returns ValidationFailure when taskGoal exceeds 60 characters', () async {
      final longGoal = 'A' * 61;
      final result = await useCase(
        taskGoal: longGoal,
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
      );

      expect(
        result,
        const Left<Failure, int>(
          ValidationFailure('Task goal cannot exceed 60 characters'),
        ),
      );
      expect(repository.lastCreatedSession, isNull);
    });

    test('defaults empty or whitespace goal to "Deep Work"', () async {
      final result = await useCase(
        taskGoal: '   ',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
      );

      expect(result, const Right<Failure, int>(1));
      expect(repository.lastCreatedSession?.taskGoal, 'Deep Work');
      expect(repository.lastCreatedSession?.targetDurationSeconds, 1500);
      expect(repository.lastCreatedSession?.status, SessionStatus.cancelled);
    });

    test('initial session status is CANCELLED to prevent uncompleted streak poisoning', () async {
      final result = await useCase(
        taskGoal: 'Prevent Poisoning',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
      );

      expect(result, const Right<Failure, int>(1));
      expect(repository.lastCreatedSession?.status, SessionStatus.cancelled);
    });

    test('creates session with trimmed goal when input is valid', () async {
      final result = await useCase(
        taskGoal: '  Finish Unit Tests  ',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1800,
      );

      expect(result, const Right<Failure, int>(1));
      expect(repository.lastCreatedSession?.taskGoal, 'Finish Unit Tests');
      expect(repository.lastCreatedSession?.targetDurationSeconds, 1800);
      expect(repository.lastCreatedSession?.status, SessionStatus.cancelled);
    });
  });
}
