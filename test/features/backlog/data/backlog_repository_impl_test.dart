import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:focusmaxxing/features/backlog/data/datasources/backlog_local_data_source.dart';
import 'package:focusmaxxing/features/backlog/data/repositories/backlog_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late BacklogLocalDataSource dataSource;
  late BacklogRepositoryImpl repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    final factory = databaseFactoryFfi;
    db = await factory.openDatabase(inMemoryDatabasePath);

    final runner = MigrationRunner(migrations: const [MigrationV1()]);
    await runner.run(db, oldVersion: 0, targetVersion: 1);

    DatabaseHelper.setMockDatabase(db, factory: factory);
    dataSource = BacklogLocalDataSource();
    repository = BacklogRepositoryImpl(localDataSource: dataSource);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('BacklogRepositoryImpl', () {
    test('addTask inserts task and returns valid ID', () async {
      final result = await repository.addTask('Write unit test');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (id) => expect(id, greaterThan(0)),
      );
    });

    test('getPendingTasks returns newest tasks first', () async {
      final id1 = (await repository.addTask('First Task')).getOrElse(() => 0);
      final id2 = (await repository.addTask('Second Task')).getOrElse(() => 0);

      final result = await repository.getPendingTasks();
      expect(result.isRight(), isTrue);
      final tasks = result.getOrElse(() => []);

      expect(tasks, hasLength(2));
      expect(tasks[0].id, id2);
      expect(tasks[1].id, id1);
    });

    test('getPendingTasks returns only pending tasks', () async {
      final id1 = (await repository.addTask('Task 1')).getOrElse(() => 0);
      final id2 = (await repository.addTask('Task 2')).getOrElse(() => 0);

      const insertSessionSql = '''
        INSERT INTO ${DatabaseHelper.tableSessions} (
          task_goal, session_type, target_duration_seconds, actual_duration_seconds,
          start_time_epoch_ms, end_time_epoch_ms, status
        ) VALUES ('Goal', 'FOCUS', 1500, 1500, 1000, 2500, 'LOCKED_IN');
      ''';
      final sessionId = await db.rawInsert(insertSessionSql);

      await repository.markCompleted(id1, sessionId);

      final pendingResult = await repository.getPendingTasks();
      expect(pendingResult.isRight(), isTrue);
      final pending = pendingResult.getOrElse(() => []);

      expect(pending, hasLength(1));
      expect(pending.first.id, id2);
      expect(pending.first.title, 'Task 2');
    });

    test('deleteTask removes task from table', () async {
      final id = (await repository.addTask('To be deleted')).getOrElse(() => 0);

      final deleteResult = await repository.deleteTask(id);
      expect(deleteResult.isRight(), isTrue);

      final pending = (await repository.getPendingTasks()).getOrElse(() => []);
      expect(pending, isEmpty);
    });

    test('deleteTask with non-existent ID returns Left(DatabaseFailure)', () async {
      final deleteResult = await repository.deleteTask(99999);
      expect(deleteResult.isLeft(), isTrue);
      deleteResult.fold(
        (failure) => expect(failure.message, contains('99999')),
        (_) => fail('Should return Left for non-existent ID'),
      );
    });

    test('repository returns Left(DatabaseFailure) when database operations encounter errors', () async {
      await db.close();

      final result = await repository.addTask('Cannot add to closed db');
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, isNotEmpty),
        (_) => fail('Should fail on closed database'),
      );
    });
  });
}
