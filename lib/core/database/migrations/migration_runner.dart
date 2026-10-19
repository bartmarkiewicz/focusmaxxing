import 'package:focusmaxxing/core/database/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class MigrationRunner {
  final List<Migration> _migrations;

  MigrationRunner({required List<Migration> migrations})
      : _migrations = List.of(migrations)
          ..sort((a, b) => a.version.compareTo(b.version));

  List<Migration> get migrations => List.unmodifiable(_migrations);

  Future<void> run(
    DatabaseExecutor db, {
    required int oldVersion,
    required int targetVersion,
    bool useTransaction = true,
  }) async {
    final pending = _migrations.where(
      (m) => m.version > oldVersion && m.version <= targetVersion,
    );

    for (final migration in pending) {
      if (db is Database && useTransaction) {
        await db.transaction((txn) async {
          await migration.up(txn);
        });
      } else {
        await migration.up(db);
      }
    }
  }
}
