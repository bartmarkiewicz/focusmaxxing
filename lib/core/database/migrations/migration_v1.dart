import 'package:focusmaxxing/core/database/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV1 extends Migration {
  const MigrationV1()
      : super(1, 'Create initial sessions and backlog_tasks tables');

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_goal TEXT NOT NULL,
        session_type TEXT NOT NULL,
        target_duration_seconds INTEGER NOT NULL,
        actual_duration_seconds INTEGER NOT NULL,
        start_time_epoch_ms INTEGER NOT NULL,
        end_time_epoch_ms INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE TABLE backlog_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_session_id INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        completed_at TIMESTAMP,
        FOREIGN KEY(completed_session_id) REFERENCES sessions(id) ON DELETE SET NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX idx_sessions_start_time ON sessions (start_time_epoch_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX idx_sessions_type_status_time ON sessions (session_type, status, start_time_epoch_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX idx_backlog_tasks_is_completed ON backlog_tasks (is_completed, id DESC);',
    );
    await db.execute(
      'CREATE INDEX idx_backlog_tasks_completed_session ON backlog_tasks (completed_session_id);',
    );
  }
}
