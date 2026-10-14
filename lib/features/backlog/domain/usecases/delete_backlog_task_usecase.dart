import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';

class DeleteBacklogTaskUseCase {
  final IBacklogRepository repository;

  const DeleteBacklogTaskUseCase(this.repository);

  Future<Either<Failure, void>> call(int id) {
    return repository.deleteTask(id);
  }
}
