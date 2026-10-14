import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';

class _MockSessionRepository implements ISessionRepository {
  int? lastSessionId;
  String? lastStatus;
  int? lastDuration;

  @override
  Future<Either<Failure, void>> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async {
    lastSessionId = sessionId;
    lastStatus = status;
    lastDuration = actualDurationSeconds;
    return const Right<Failure, void>(null);
  }

  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async =>
      const Right<Failure, int>(1);

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async =>
      const Right<Failure, List<SessionEntity>>([]);
}

void main() {
  late _MockSessionRepository repository;
  late CompleteSessionUseCase useCase;

  setUp(() {
    repository = _MockSessionRepository();
    useCase = CompleteSessionUseCase(repository);
  });

  group('CompleteSessionUseCase', () {
    test('delegates status update to repository', () async {
      final result = await useCase(
        sessionId: 123,
        status: SessionStatus.lockedIn,
        actualDurationSeconds: 1500,
      );

      expect(result, const Right<Failure, void>(null));
      expect(repository.lastSessionId, 123);
      expect(repository.lastStatus, SessionStatus.lockedIn);
      expect(repository.lastDuration, 1500);
    });
  });
}
