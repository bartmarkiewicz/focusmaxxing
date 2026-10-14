import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';

class GetPendingTasksUseCase {
  final IBacklogRepository repository;

  const GetPendingTasksUseCase(this.repository);

  Future<Either<Failure, List<BacklogTaskEntity>>> call() {
    return repository.getPendingTasks();
  }
}
