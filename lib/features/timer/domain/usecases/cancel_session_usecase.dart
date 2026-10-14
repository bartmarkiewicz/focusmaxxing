import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';

class CancelSessionUseCase {
  const CancelSessionUseCase(this.repository);

  final ISessionRepository repository;

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
