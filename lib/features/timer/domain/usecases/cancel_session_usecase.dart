import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';

class CancelSessionUseCase {
  final ISessionRepository repository;

  const CancelSessionUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required int sessionId,
    required int actualDurationSeconds,
  }) {
    return repository.updateSessionStatus(
      sessionId,
      SessionStatus.cancelled,
      actualDurationSeconds,
    );
  }
}
