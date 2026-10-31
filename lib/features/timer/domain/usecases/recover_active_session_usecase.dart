import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';

/// Queries local SQLite persistence on cold start to locate an interrupted active
/// focus session that was initialized by [StartSessionUseCase] (`status == CANCELLED`,
/// `actualDurationSeconds == 0`, and `endTimeEpochMs == startTimeEpochMs + targetDurationSeconds * 1000`)
/// and never explicitly cancelled or completed before process death.
class RecoverActiveSessionUseCase {
  const RecoverActiveSessionUseCase(this.repository);

  static const int maxRecoveryWindowMs = 12 * 3600 * 1000;

  final ISessionRepository repository;

  Future<Either<Failure, SessionEntity?>> call({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final nowMs = currentTime.millisecondsSinceEpoch;
    final lookbackStartMs = nowMs - maxRecoveryWindowMs;
    final lookaheadEndMs = nowMs + maxRecoveryWindowMs;

    final result = await repository.getSessionsForDateRange(
      lookbackStartMs,
      lookaheadEndMs,
    );

    return result.map((sessions) {
      SessionEntity? latestCandidate;
      for (final session in sessions) {
        final expectedEndMs =
            session.startTimeEpochMs + (session.targetDurationSeconds * 1000);
        final isUnfinalizedFocusSession =
            session.sessionType == SessionType.focus &&
                session.status == SessionStatus.cancelled &&
                session.actualDurationSeconds == 0 &&
                session.targetDurationSeconds > 0 &&
                session.endTimeEpochMs == expectedEndMs &&
                session.startTimeEpochMs <= nowMs &&
                (nowMs - session.startTimeEpochMs) <= maxRecoveryWindowMs;

        if (isUnfinalizedFocusSession) {
          if (latestCandidate == null ||
              session.startTimeEpochMs > latestCandidate.startTimeEpochMs) {
            latestCandidate = session;
          }
        }
      }
      return latestCandidate;
    });
  }
}
