import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';

class MarkTaskCompletedUseCase {
  final IBacklogRepository repository;

  const MarkTaskCompletedUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required int id,
    int? sessionId,
  }) {
    return repository.markCompleted(id, sessionId);
  }
}
