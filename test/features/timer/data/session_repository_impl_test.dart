import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:focusmaxxing/features/timer/data/datasources/session_local_data_source.dart';
import 'package:focusmaxxing/features/timer/data/repositories/session_repository_impl.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SessionLocalDataSource dataSource;
  late SessionRepositoryImpl repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    final factory = databaseFactoryFfi;
    db = await factory.openDatabase(inMemoryDatabasePath);

    final runner = MigrationRunner(migrations: const [MigrationV1()]);
    await runner.run(db, oldVersion: 0, targetVersion: 1);

    DatabaseHelper.setMockDatabase(db, factory: factory);
    dataSource = SessionLocalDataSource();
    repository = SessionRepositoryImpl(localDataSource: dataSource);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('SessionRepositoryImpl', () {
    test('createSession inserts record and returns valid ID', () async {
      const session = SessionEntity(
        taskGoal: 'Ship MVP',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 0,
        startTimeEpochMs: 1000,
        endTimeEpochMs: 2500,
        status: SessionStatus.lockedIn,
      );

      final result = await repository.createSession(session);
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (id) => expect(id, greaterThan(0)),
      );
    });

    test('updateSessionStatus updates outcome and actual duration', () async {
      const session = SessionEntity(
        taskGoal: 'Refactor Code',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 0,
        startTimeEpochMs: 1000,
        endTimeEpochMs: 2500,
        status: SessionStatus.lockedIn,
      );
      final id = (await repository.createSession(session)).getOrElse(() => 0);

      final updateResult = await repository.updateSessionStatus(
        id,
        SessionStatus.derailed,
        1200,
      );
      expect(updateResult.isRight(), isTrue);

      final rows = await db.query(
        DatabaseHelper.tableSessions,
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows, hasLength(1));
      expect(rows.first['status'], SessionStatus.derailed);
      expect(rows.first['actual_duration_seconds'], 1200);
    });

    test('getSessionsForDateRange queries sessions within time boundaries', () async {
      const session1 = SessionEntity(
        taskGoal: 'Morning Session',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: 10000,
        endTimeEpochMs: 11500,
        status: SessionStatus.lockedIn,
      );
      const session2 = SessionEntity(
        taskGoal: 'Afternoon Session',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: 20000,
        endTimeEpochMs: 21500,
        status: SessionStatus.lockedIn,
      );

      await repository.createSession(session1);
      await repository.createSession(session2);

      final rangeResult = await repository.getSessionsForDateRange(9000, 15000);
      expect(rangeResult.isRight(), isTrue);
      final list = rangeResult.getOrElse(() => []);

      expect(list, hasLength(1));
      expect(list.first.taskGoal, 'Morning Session');
    });

    test('returns Left(DatabaseFailure) when database is closed', () async {
      await db.close();

      const session = SessionEntity(
        taskGoal: 'Closed DB Test',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 0,
        startTimeEpochMs: 1000,
        endTimeEpochMs: 2500,
        status: SessionStatus.lockedIn,
      );

      final result = await repository.createSession(session);
      expect(result.isLeft(), isTrue);
    });
  });
}
