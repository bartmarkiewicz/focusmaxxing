import 'package:focusmaxxing/core/database/migrations/migration.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV3 extends Migration {
  const MigrationV3()
      : super(3, 'Create daily_focus_metrics table for daily rollups');

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_focus_metrics (
        date_key TEXT PRIMARY KEY,
        start_epoch_ms INTEGER NOT NULL,
        end_epoch_ms INTEGER NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        day INTEGER NOT NULL,
        weekday INTEGER NOT NULL,
        total_focus_seconds INTEGER NOT NULL DEFAULT 0,
        unclaimed_seconds INTEGER NOT NULL DEFAULT 0,
        completed_sessions_count INTEGER NOT NULL DEFAULT 0,
        derailed_sessions_count INTEGER NOT NULL DEFAULT 0,
        cancelled_sessions_count INTEGER NOT NULL DEFAULT 0,
        longest_session_seconds INTEGER NOT NULL DEFAULT 0,
        peak_hour INTEGER,
        hourly_focus_seconds_json TEXT NOT NULL DEFAULT '{}',
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_focus_metrics_epoch ON daily_focus_metrics (start_epoch_ms DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_focus_metrics_year_month ON daily_focus_metrics (year, month);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_focus_metrics_weekday ON daily_focus_metrics (weekday, total_focus_seconds DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_focus_metrics_peak ON daily_focus_metrics (total_focus_seconds DESC, start_epoch_ms DESC);',
    );
  }
}
