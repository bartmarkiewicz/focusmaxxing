import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';

class CompleteSessionUseCase {
  const CompleteSessionUseCase(this.repository);

  final ISessionRepository repository;

  Future<Either<Failure, void>> call({
    required int sessionId,
    required String status,
    required int actualDurationSeconds,
  }) {
    return repository.updateSessionStatus(
      sessionId,
      status,
      actualDurationSeconds,
    );
  }
}
