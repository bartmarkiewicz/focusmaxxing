import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';

abstract class IBacklogRepository {
  Future<Either<Failure, List<BacklogTaskEntity>>> getPendingTasks();
  Future<Either<Failure, int>> addTask(String title);
  Future<Either<Failure, void>> deleteTask(int id);
  Future<Either<Failure, void>> markCompleted(int id, int sessionId);
}
