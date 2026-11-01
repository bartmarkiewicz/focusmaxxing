import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v2.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v3.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v4.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  group('MigrationV4', () {
    test('creates focus_targets and session_targets tables with indexes', () async {
      final factory = databaseFactoryFfi;
      final db = await factory.openDatabase(inMemoryDatabasePath);

      final runner = MigrationRunner(
        migrations: const [
          MigrationV1(),
          MigrationV2(),
          MigrationV3(),
          MigrationV4(),
        ],
      );

      await runner.run(db, oldVersion: 0, targetVersion: 4);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;",
      );
      final names = tables.map((t) => t['name'] as String).toList();

      expect(names, contains(DatabaseHelper.tableFocusTargets));
      expect(names, contains(DatabaseHelper.tableSessionTargets));

      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name;",
      );
      final indexNames = indexes.map((i) => i['name'] as String).toList();

      expect(indexNames, contains('idx_session_targets_target_id'));
      expect(indexNames, contains('idx_focus_targets_archived'));

      await db.close();
    });

    test('backfills distinct task_goal from sessions into focus_targets and links session_targets', () async {
      final factory = databaseFactoryFfi;
      final db = await factory.openDatabase(inMemoryDatabasePath);

      final v1Runner = MigrationRunner(migrations: const [MigrationV1()]);
      await v1Runner.run(db, oldVersion: 0, targetVersion: 1);

      // Insert legacy sessions with duplicate and trimmed goals
      await db.insert('sessions', <String, dynamic>{
        'task_goal': 'Mobile UI',
        'session_type': 'FOCUS',
        'target_duration_seconds': 1500,
        'actual_duration_seconds': 1500,
        'start_time_epoch_ms': 1000,
        'end_time_epoch_ms': 2500,
        'status': 'LOCKED_IN',
      });

      await db.insert('sessions', <String, dynamic>{
        'task_goal': '  mobile ui  ', // Case-insensitive duplicate with whitespace
        'session_type': 'FOCUS',
        'target_duration_seconds': 1800,
        'actual_duration_seconds': 1800,
        'start_time_epoch_ms': 3000,
        'end_time_epoch_ms': 4800,
        'status': 'LOCKED_IN',
      });

      await db.insert('sessions', <String, dynamic>{
        'task_goal': 'API Refactor',
        'session_type': 'FOCUS',
        'target_duration_seconds': 1200,
        'actual_duration_seconds': 1200,
        'start_time_epoch_ms': 5000,
        'end_time_epoch_ms': 6200,
        'status': 'LOCKED_IN',
      });

      await db.insert('sessions', <String, dynamic>{
        'task_goal': 'Documentation',
        'session_type': 'FOCUS',
        'target_duration_seconds': 900,
        'actual_duration_seconds': 900,
        'start_time_epoch_ms': 7000,
        'end_time_epoch_ms': 7900,
        'status': 'DERAILED',
      });

      // Run up to MigrationV4
      final fullRunner = MigrationRunner(
        migrations: const [
          MigrationV1(),
          MigrationV2(),
          MigrationV3(),
          MigrationV4(),
        ],
      );
      await fullRunner.run(db, oldVersion: 1, targetVersion: 4);

      final targets = await db.query(DatabaseHelper.tableFocusTargets);
      expect(targets.length, 3); // 'Mobile UI', 'API Refactor', 'Documentation'

      final sessionTargets = await db.query(DatabaseHelper.tableSessionTargets);
      expect(sessionTargets.length, 4);

      for (final st in sessionTargets) {
        expect(st['allocated_percentage'], 100);
        expect(st['display_order'], 1);
      }

      // Check that DERAILED session got 0 allocated seconds
      final derailedRow = await db.rawQuery('''
        SELECT st.allocated_seconds
        FROM session_targets st
        JOIN sessions s ON s.id = st.session_id
        WHERE s.status = 'DERAILED';
      ''');
      expect(derailedRow.first['allocated_seconds'], 0);

      await db.close();
    });
  });
}
