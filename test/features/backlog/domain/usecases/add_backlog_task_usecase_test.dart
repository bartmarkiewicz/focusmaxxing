import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/add_backlog_task_usecase.dart';

class _MockRepository implements IBacklogRepository {
  String? lastAddedTitle;

  @override
  Future<Either<Failure, int>> addTask(String title) async {
    lastAddedTitle = title;
    return const Right(1);
  }

  @override
  Future<Either<Failure, void>> deleteTask(int id) async => const Right(null);

  @override
  Future<Either<Failure, List<BacklogTaskEntity>>> getPendingTasks() async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> markCompleted(int id, int sessionId) async =>
      const Right(null);
}

void main() {
  late _MockRepository repository;
  late AddBacklogTaskUseCase useCase;

  setUp(() {
    repository = _MockRepository();
    useCase = AddBacklogTaskUseCase(repository);
  });

  group('AddBacklogTaskUseCase', () {
    test('returns ValidationFailure when title is empty or blank', () async {
      final result1 = await useCase('');
      final result2 = await useCase('   ');

      expect(
          result1,
          const Left<Failure, int>(
              ValidationFailure('Task title cannot be empty')));
      expect(
          result2,
          const Left<Failure, int>(
              ValidationFailure('Task title cannot be empty')));
      expect(repository.lastAddedTitle, isNull);
    });

    test('returns ValidationFailure when title exceeds 60 characters',
        () async {
      final longTitle = 'A' * 61;
      final result = await useCase(longTitle);

      expect(
        result,
        const Left<Failure, int>(
            ValidationFailure('Task title cannot exceed 60 characters')),
      );
      expect(repository.lastAddedTitle, isNull);
    });

    test('trims title and delegates to repository on valid input', () async {
      final result = await useCase('  Valid Title  ');

      expect(result, const Right<Failure, int>(1));
      expect(repository.lastAddedTitle, 'Valid Title');
    });
  });
}
