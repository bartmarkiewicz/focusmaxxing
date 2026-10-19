import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';

class AddBacklogTaskUseCase {
  final IBacklogRepository repository;

  const AddBacklogTaskUseCase(this.repository);

  Future<Either<Failure, int>> call(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('Task title cannot be empty'));
    }
    if (trimmed.length > 60) {
      return const Left(
          ValidationFailure('Task title cannot exceed 60 characters'));
    }
    return repository.addTask(trimmed);
  }
}
