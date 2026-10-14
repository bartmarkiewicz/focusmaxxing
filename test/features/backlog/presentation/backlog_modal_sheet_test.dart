import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/domain/repositories/i_backlog_repository.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/add_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/delete_backlog_task_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/get_pending_tasks_usecase.dart';
import 'package:focusmaxxing/features/backlog/domain/usecases/mark_task_completed_usecase.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/backlog_modal_sheet.dart';
import 'package:provider/provider.dart';

class _MockBacklogRepository implements IBacklogRepository {
  final List<BacklogTaskEntity> _tasks = [];
  int _counter = 1;
  Failure? failureToThrow;

  @override
  Future<Either<Failure, int>> addTask(String title) async {
    if (failureToThrow != null) return Left(failureToThrow!);
    final task = BacklogTaskEntity(
      id: _counter++,
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
  Future<Either<Failure, void>> markCompleted(int id, int sessionId) async {
    return const Right(null);
  }
}

void main() {
  late _MockBacklogRepository repository;
  late BacklogNotifier notifier;

  setUp(() {
    repository = _MockBacklogRepository();
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

  Widget createWidget({ValueChanged<BacklogTaskEntity>? onTaskSelected}) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<BacklogNotifier>.value(
          value: notifier,
          child: BacklogModalSheet(onTaskSelected: onTaskSelected),
        ),
      ),
    );
  }

  group('BacklogModalSheet', () {
    testWidgets('renders empty state initially when repository has no tasks', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Backlog (Focus Scratchpad)'), findsOneWidget);
      expect(
        find.text('Scratchpad is clear.\nAdd tasks above to stay locked in.'),
        findsOneWidget,
      );
    });

    testWidgets('loads pre-existing tasks from repository on initialization post-frame', (tester) async {
      await repository.addTask('Preloaded Task 1');
      await repository.addTask('Preloaded Task 2');

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Preloaded Task 1'), findsOneWidget);
      expect(find.text('Preloaded Task 2'), findsOneWidget);
    });

    testWidgets('adds a new task via input field and renders list tile', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      await tester.enterText(input, 'Finish slide deck');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Finish slide deck'), findsOneWidget);
    });

    testWidgets('tapping a task triggers onTaskSelected and sets selectedTask on notifier', (tester) async {
      BacklogTaskEntity? selected;
      await repository.addTask('Code review PR 42');

      await tester.pumpWidget(createWidget(
        onTaskSelected: (task) => selected = task,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Code review PR 42'), findsOneWidget);

      await tester.tap(find.text('Code review PR 42'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected?.title, 'Code review PR 42');
      expect(notifier.selectedTask?.title, 'Code review PR 42');
    });

    testWidgets('swiping item left deletes it and displays undo snackbar which restores item', (tester) async {
      await repository.addTask('Task To Dismiss');

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Task To Dismiss'), findsOneWidget);

      await tester.drag(find.text('Task To Dismiss'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Task To Dismiss'), findsNothing);
      expect(find.text('Removed "Task To Dismiss"'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();

      expect(find.text('Task To Dismiss'), findsOneWidget);
    });

    testWidgets('displays error message when notifier has errorMessage', (tester) async {
      repository.failureToThrow = const DatabaseFailure('Database connection timeout');

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Database connection timeout'), findsOneWidget);
    });
  });
}
