import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/add_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/delete_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/get_pending_tasks_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';

class _FakeBacklogRepository implements IBacklogRepository {
  final List<BacklogTaskEntity> _tasks = [];
  int _nextId = 1;
  Failure? failureToThrow;

  @override
  Future<Either<Failure, int>> addTask(String title) async {
    if (failureToThrow != null) return Left(failureToThrow!);
    final task = BacklogTaskEntity(
      id: _nextId++,
      title: title,
      createdAt: DateTime.now(),
    );
    _tasks.add(task);
    return Right(task.id!);
  }

  @override
  Future<Either<Failure, void>> deleteTask(int id) async {
    if (failureToThrow != null) return Left(failureToThrow!);
    _tasks.removeWhere((t) => t.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<BacklogTaskEntity>>> getPendingTasks() async {
    if (failureToThrow != null) return Left(failureToThrow!);
    return Right(_tasks.where((t) => !t.isCompleted).toList());
  }

  @override
  Future<Either<Failure, void>> markCompleted(int id, [int? sessionId]) async {
    if (failureToThrow != null) return Left(failureToThrow!);
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        isCompleted: true,
        completedSessionId: sessionId,
        completedAt: DateTime.now(),
      );
    }
    return const Right(null);
  }
}

void main() {
  late _FakeBacklogRepository repository;
  late BacklogNotifier notifier;

  setUp(() {
    repository = _FakeBacklogRepository();
    notifier = BacklogNotifier(
      getPendingTasksUseCase: GetPendingTasksUseCase(repository),
      addBacklogTaskUseCase: AddBacklogTaskUseCase(repository),
      deleteBacklogTaskUseCase: DeleteBacklogTaskUseCase(repository),
      markTaskCompletedUseCase: MarkTaskCompletedUseCase(repository),
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  group('BacklogNotifier', () {
    test('initial state has empty pending tasks and not loading', () {
      expect(notifier.pendingTasks, isEmpty);
      expect(notifier.isLoading, isFalse);
      expect(notifier.errorMessage, isNull);
      expect(notifier.selectedTask, isNull);
    });

    test('selectTaskAsGoal sets active goal and notifies listeners', () {
      final task = BacklogTaskEntity(
        id: 1,
        title: 'Selected Task',
        createdAt: DateTime.now(),
      );

      var notified = false;
      notifier.addListener(() => notified = true);

      notifier.selectTaskAsGoal(task);

      expect(notifier.selectedTask, equals(task));
      expect(notified, isTrue);

      notifier.selectTaskAsGoal(null);
      expect(notifier.selectedTask, isNull);
    });

    test('loadPendingTasks sets errorMessage on repository failure', () async {
      repository.failureToThrow = const DatabaseFailure('Database read error');

      await notifier.loadPendingTasks();

      expect(notifier.isLoading, isFalse);
      expect(notifier.errorMessage, 'Database read error');
      expect(notifier.pendingTasks, isEmpty);
    });

    test('addTask updates pending tasks list', () async {
      final success = await notifier.addTask('Review architecture');

      expect(success, isTrue);
      expect(notifier.pendingTasks, hasLength(1));
      expect(notifier.pendingTasks.first.title, 'Review architecture');
      expect(notifier.errorMessage, isNull);
    });

    test('addTask returns false and sets errorMessage on failure', () async {
      repository.failureToThrow = const DatabaseFailure('Insert failed');

      final success = await notifier.addTask('Fail task');

      expect(success, isFalse);
      expect(notifier.errorMessage, 'Insert failed');
      expect(notifier.pendingTasks, isEmpty);
    });

    test('addTask returns false for empty input without calling repository',
        () async {
      final success = await notifier.addTask('   ');

      expect(success, isFalse);
      expect(notifier.pendingTasks, isEmpty);
    });

    test('deleteTask removes task from pending tasks optimistically', () async {
      await notifier.addTask('Task A');
      final taskId = notifier.pendingTasks.first.id!;

      await notifier.deleteTask(taskId);

      expect(notifier.pendingTasks, isEmpty);
    });

    test('deleteTask rolls back pending tasks on repository failure', () async {
      await notifier.addTask('Task Protected');
      final taskId = notifier.pendingTasks.first.id!;

      repository.failureToThrow = const DatabaseFailure('Delete failed');

      await notifier.deleteTask(taskId);

      expect(notifier.pendingTasks, hasLength(1));
      expect(notifier.pendingTasks.first.id, taskId);
      expect(notifier.errorMessage, 'Delete failed');
    });

    test('completeTask removes task and unsets selectedTask if matched',
        () async {
      await notifier.addTask('Task B');
      final task = notifier.pendingTasks.first;
      notifier.selectTaskAsGoal(task);

      expect(notifier.selectedTask, equals(task));

      await notifier.completeTask(task.id!, 101);

      expect(notifier.pendingTasks, isEmpty);
      expect(notifier.selectedTask, isNull);
    });
  });
}
