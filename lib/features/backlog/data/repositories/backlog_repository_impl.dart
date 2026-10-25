import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/backlog/data/datasources/backlog_local_data_source.dart';
import 'package:focusmaxxing/features/backlog/data/models/backlog_task_model.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';

class BacklogRepositoryImpl implements IBacklogRepository {
  final IBacklogLocalDataSource localDataSource;

  const BacklogRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<BacklogTaskEntity>>> getPendingTasks() async {
    try {
      final models = await localDataSource.getPendingTasks();
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(DatabaseFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> addTask(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('Task title cannot be empty'));
    }
    try {
      final model = BacklogTaskModel(
        title: trimmed,
        createdAt: DateTime.now().toUtc(),
      );
      final id = await localDataSource.insertTask(model);
      return Right(id);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(DatabaseFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTask(int id) async {
    try {
      await localDataSource.deleteTask(id);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(DatabaseFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> markCompleted(int id, [int? sessionId]) async {
    try {
      await localDataSource.markCompleted(id, sessionId);
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(DatabaseFailure('Unexpected error: $e'));
    }
  }
}
