import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';

class StartSessionUseCase {
  final ISessionRepository repository;

  const StartSessionUseCase(this.repository);

  Future<Either<Failure, int>> call({
    required String taskGoal,
    required String sessionType,
    required int targetDurationSeconds,
  }) async {
    if (targetDurationSeconds <= 0) {
      return const Left<Failure, int>(
        ValidationFailure('Target duration must be greater than zero'),
      );
    }

    final trimmedGoal = taskGoal.trim();
    final effectiveGoal = trimmedGoal.isNotEmpty ? trimmedGoal : 'Deep Work';
    if (effectiveGoal.length > 60) {
      return const Left<Failure, int>(
        ValidationFailure('Task goal cannot exceed 60 characters'),
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final session = SessionEntity(
      taskGoal: effectiveGoal,
      sessionType: sessionType,
      targetDurationSeconds: targetDurationSeconds,
      actualDurationSeconds: 0,
      startTimeEpochMs: now,
      endTimeEpochMs: now + (targetDurationSeconds * 1000),
      status: SessionStatus.lockedIn,
    );
    return await repository.createSession(session);
  }
}
