import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/database/migrations/migration.dart';
import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v2.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;

class _FailingMigration extends Migration {
  const _FailingMigration() : super(2, 'Test failing migration for rollback');

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('CREATE TABLE should_rollback (id INTEGER PRIMARY KEY);');
    throw StateError('Simulated migration crash');
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('MigrationRunner', () {
    test('applies MigrationV1 and creates schema tables', () async {
      final factory = databaseFactoryFfi;
      final db = await factory.openDatabase(inMemoryDatabasePath);

      final runner = MigrationRunner(migrations: const [MigrationV1()]);
      await runner.run(db, oldVersion: 0, targetVersion: 1);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;",
      );
      final names = tables.map((t) => t['name'] as String).toList();

      expect(names, contains(DatabaseHelper.tableSessions));
      expect(names, contains(DatabaseHelper.tableBacklogTasks));

      await db.close();
    });

    test('applies sequential upgrade from v1 to v2 with MigrationV2', () async {
      final factory = databaseFactoryFfi;
      final db = await factory.openDatabase(inMemoryDatabasePath);

      final runner = MigrationRunner(
        migrations: const [
          MigrationV1(),
          MigrationV2(),
        ],
      );

      await runner.run(db, oldVersion: 0, targetVersion: 1);
      var tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='${DatabaseHelper.tableShieldedApps}';",
      );
      expect(tables, isEmpty);

      await runner.run(db, oldVersion: 1, targetVersion: 2);
      tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='${DatabaseHelper.tableShieldedApps}';",
      );
      expect(tables, hasLength(1));

      await db.close();
    });

    test('rolls back transaction when a migration fails', () async {
      final factory = databaseFactoryFfi;
      final db = await factory.openDatabase(inMemoryDatabasePath);

      final runner = MigrationRunner(
        migrations: const [
          MigrationV1(),
          _FailingMigration(),
        ],
      );

      await runner.run(db, oldVersion: 0, targetVersion: 1);

      expect(
        () => runner.run(db, oldVersion: 1, targetVersion: 2),
        throwsA(isA<StateError>()),
      );

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='should_rollback';",
      );
      expect(tables, isEmpty);

      await db.close();
    });

    test(
        'wraps multi-step migrations in a single atomic transaction and rolls back all steps on failure',
        () async {
      final factory = databaseFactoryFfi;
      final db = await factory.openDatabase(inMemoryDatabasePath);

      final runner = MigrationRunner(
        migrations: const [
          MigrationV1(),
          _FailingMigration(),
        ],
      );

      await expectLater(
        runner.run(db, oldVersion: 0, targetVersion: 2, useTransaction: true),
        throwsA(isA<StateError>()),
      );

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
      );
      expect(tables, isEmpty);

      await db.close();
    });
  });

  group('DatabaseHelper with MigrationRunner', () {
    test('initializes and delegates to MigrationRunner on open', () async {
      final factory = databaseFactoryFfi;
      final db = await factory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseHelper.databaseVersion,
          onCreate: (database, version) async {
            final runner = MigrationRunner(
              migrations: const [MigrationV1(), MigrationV2()],
            );
            await runner.run(database, oldVersion: 0, targetVersion: version);
          },
        ),
      );

      DatabaseHelper.setMockDatabase(db, factory: factory);

      final instanceDb = await DatabaseHelper.instance.database;
      expect(instanceDb.isOpen, isTrue);

      final sessionId = await instanceDb.insert(
        DatabaseHelper.tableSessions,
        <String, dynamic>{
          'task_goal': 'Refactor migrations',
          'session_type': 'FOCUS',
          'target_duration_seconds': 1500,
          'actual_duration_seconds': 1500,
          'start_time_epoch_ms': 1000,
          'end_time_epoch_ms': 2500,
          'status': 'LOCKED_IN',
        },
      );
      expect(sessionId, greaterThan(0));
    });

    test(
        'database getter is idempotent when mock database is closed and throws DatabaseException consistently',
        () async {
      final factory = databaseFactoryFfi;
      final db = await factory.openDatabase(inMemoryDatabasePath);
      DatabaseHelper.setMockDatabase(db, factory: factory);

      await db.close();

      await expectLater(
        DatabaseHelper.instance.database,
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        DatabaseHelper.instance.database,
        throwsA(isA<DatabaseException>()),
      );
    });

    test(
        'non-mock database transparently re-initializes on first database access after close',
        () async {
      final factory = databaseFactoryFfi;
      DatabaseHelper.setMockDatabase(null, factory: factory);

      final firstDb = await DatabaseHelper.instance.database;
      expect(firstDb.isOpen, isTrue);

      await firstDb.close();
      expect(firstDb.isOpen, isFalse);

      final reopenedDb = await DatabaseHelper.instance.database;
      expect(reopenedDb.isOpen, isTrue);
    });
  });
}
