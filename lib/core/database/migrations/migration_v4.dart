import 'package:focusmaxxing/core/database/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV4 extends Migration {
  const MigrationV4()
      : super(4, 'Create focus_targets and session_targets tables with backfill');

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS focus_targets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        color_hex TEXT NOT NULL DEFAULT '#00E5FF',
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_targets (
        session_id INTEGER NOT NULL,
        target_id INTEGER NOT NULL,
        allocated_percentage INTEGER NOT NULL DEFAULT 100,
        allocated_seconds INTEGER NOT NULL DEFAULT 0,
        display_order INTEGER NOT NULL DEFAULT 1,
        PRIMARY KEY (session_id, target_id),
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE,
        FOREIGN KEY (target_id) REFERENCES focus_targets(id) ON DELETE CASCADE
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_session_targets_target_id ON session_targets (target_id, session_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_focus_targets_archived ON focus_targets (is_archived, name);',
    );

    // Automated Historical Backfill:
    // 1. Insert distinct legacy session goals into focus_targets
    await db.execute('''
      INSERT OR IGNORE INTO focus_targets (name)
      SELECT DISTINCT TRIM(task_goal)
      FROM sessions
      WHERE task_goal IS NOT NULL AND TRIM(task_goal) != '';
    ''');

    // 2. Link existing sessions to session_targets with 100% allocation
    // (Allocated seconds credited only for LOCKED_IN sessions, 0 for DERAILED/CANCELLED)
    await db.execute('''
      INSERT OR IGNORE INTO session_targets (session_id, target_id, allocated_percentage, allocated_seconds, display_order)
      SELECT s.id, ft.id, 100,
        CASE WHEN s.status = 'LOCKED_IN' THEN s.actual_duration_seconds ELSE 0 END, 1
      FROM sessions s
      JOIN focus_targets ft ON LOWER(TRIM(s.task_goal)) = LOWER(ft.name);
    ''');
  }
}
