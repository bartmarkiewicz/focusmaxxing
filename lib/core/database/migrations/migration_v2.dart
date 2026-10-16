import 'package:focusmaxxing/core/database/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV2 extends Migration {
  const MigrationV2() : super(2, 'Create shielded_apps table for Brainrot Shield');

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE shielded_apps (
        package_name TEXT PRIMARY KEY,
        app_name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_preset INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute(
      'CREATE INDEX idx_shielded_apps_is_active ON shielded_apps (is_active);',
    );
  }
}
