import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/features/timer/data/models/focus_target_model.dart';
import 'package:focusmaxxing/features/timer/data/models/session_model.dart';
import 'package:focusmaxxing/features/timer/data/models/session_target_allocation_model.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/utils/target_allocation_balancer.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

abstract interface class ISessionLocalDataSource {
  Future<int> insertSession(SessionModel session);
  Future<void> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  );
  Future<List<SessionModel>> getSessionsForDateRange(int startMs, int endMs);
  Future<List<int>> getCompletedFocusSessionStartTimes();
  Future<List<FocusTargetModel>> getFocusTargets({bool includeArchived = false});
  Future<FocusTargetModel> findOrCreateFocusTarget(
    String name, {
    String colorHex = '#00E5FF',
  });
  Future<List<FocusTargetModel>> getRecentFocusTargets({int limit = 10});
  Future<List<SessionTargetAllocationModel>> getSessionTargets(int sessionId);
}

class SessionLocalDataSource implements ISessionLocalDataSource {
  SessionLocalDataSource({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<Database> get _db => _databaseHelper.database;

  @override
  Future<int> insertSession(SessionModel session) async {
    try {
      final db = await _db;
      return await db.transaction<int>((txn) async {
        final sessionId = await txn.insert(
          DatabaseHelper.tableSessions,
          session.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final hasTargetsTable =
            await _hasTable(txn, DatabaseHelper.tableSessionTargets);
        if (!hasTargetsTable) {
          return sessionId;
        }

        final targets = session.targets;
        if (targets.isNotEmpty) {
          final percentages = targets.map((t) => t.percentage).toList();
          final allocatedSecondsList =
              session.status == SessionStatus.lockedIn
                  ? TargetAllocationBalancer.calculateAllocatedSeconds(
                      totalSeconds: session.actualDurationSeconds,
                      percentages: percentages,
                    )
                  : List<int>.filled(targets.length, 0);

          for (var i = 0; i < targets.length; i++) {
            final target = targets[i];
            final targetId = target.targetId ??
                await _findOrCreateFocusTargetInTxn(
                  txn,
                  target.targetName,
                  colorHex: target.colorHex,
                );

            await txn.insert(
              DatabaseHelper.tableSessionTargets,
              <String, dynamic>{
                'session_id': sessionId,
                'target_id': targetId,
                'allocated_percentage': target.percentage,
                'allocated_seconds': allocatedSecondsList[i],
                'display_order': i + 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        } else if (session.taskGoal.trim().isNotEmpty) {
          // Backward compatibility: link session to focus_targets with 100% allocation
          final targetId = await _findOrCreateFocusTargetInTxn(
            txn,
            session.taskGoal.trim(),
          );
          final allocated = session.status == SessionStatus.lockedIn
              ? session.actualDurationSeconds
              : 0;

          await txn.insert(
            DatabaseHelper.tableSessionTargets,
            <String, dynamic>{
              'session_id': sessionId,
              'target_id': targetId,
              'allocated_percentage': 100,
              'allocated_seconds': allocated,
              'display_order': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        return sessionId;
      });
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to insert session: $e');
    }
  }

  @override
  Future<void> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async {
    try {
      final db = await _db;
      await db.transaction((txn) async {
        final count = await txn.update(
          DatabaseHelper.tableSessions,
          <String, dynamic>{
            'status': status,
            'actual_duration_seconds': actualDurationSeconds,
            'end_time_epoch_ms': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [sessionId],
        );

        if (count == 0) {
          throw DatabaseException(
              'No session found with ID $sessionId to update');
        }

        final hasTargetsTable =
            await _hasTable(txn, DatabaseHelper.tableSessionTargets);
        if (!hasTargetsTable) {
          return;
        }

        // Update allocated seconds for linked session_targets
        final targetRows = await txn.query(
          DatabaseHelper.tableSessionTargets,
          where: 'session_id = ?',
          whereArgs: [sessionId],
          orderBy: 'display_order ASC',
        );

        if (targetRows.isNotEmpty) {
          if (status == SessionStatus.lockedIn) {
            final percentages = targetRows
                .map((r) => (r['allocated_percentage'] as num).toInt())
                .toList();
            final allocatedSecondsList =
                TargetAllocationBalancer.calculateAllocatedSeconds(
              totalSeconds: actualDurationSeconds,
              percentages: percentages,
            );

            for (var i = 0; i < targetRows.length; i++) {
              final row = targetRows[i];
              await txn.update(
                DatabaseHelper.tableSessionTargets,
                <String, dynamic>{
                  'allocated_seconds': allocatedSecondsList[i],
                },
                where: 'session_id = ? AND target_id = ?',
                whereArgs: [sessionId, row['target_id']],
              );
            }
          } else {
            // Derailed or Cancelled sessions get 0 allocated seconds
            await txn.update(
              DatabaseHelper.tableSessionTargets,
              <String, dynamic>{'allocated_seconds': 0},
              where: 'session_id = ?',
              whereArgs: [sessionId],
            );
          }
        }
      });
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to update session $sessionId: $e');
    }
  }

  @override
  Future<List<SessionModel>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseHelper.tableSessions,
        where: 'start_time_epoch_ms >= ? AND start_time_epoch_ms <= ?',
        whereArgs: [startMs, endMs],
        orderBy: 'start_time_epoch_ms DESC',
      );
      return results.map(SessionModel.fromMap).toList();
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to query sessions for date range: $e');
    }
  }

  @override
  Future<List<int>> getCompletedFocusSessionStartTimes() async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseHelper.tableSessions,
        columns: ['start_time_epoch_ms'],
        where: 'session_type = ? AND status = ?',
        whereArgs: ['FOCUS', 'LOCKED_IN'],
        orderBy: 'start_time_epoch_ms DESC',
      );
      return results.map((row) => row['start_time_epoch_ms'] as int).toList();
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
          'Failed to query completed session timestamps: $e');
    }
  }

  @override
  Future<List<FocusTargetModel>> getFocusTargets({
    bool includeArchived = false,
  }) async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseHelper.tableFocusTargets,
        where: includeArchived ? null : 'is_archived = ?',
        whereArgs: includeArchived ? null : [0],
        orderBy: 'name ASC',
      );
      return results.map(FocusTargetModel.fromMap).toList();
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to fetch focus targets: $e');
    }
  }

  @override
  Future<FocusTargetModel> findOrCreateFocusTarget(
    String name, {
    String colorHex = '#00E5FF',
  }) async {
    try {
      final db = await _db;
      return await db.transaction((txn) async {
        final id = await _findOrCreateFocusTargetInTxn(
          txn,
          name,
          colorHex: colorHex,
        );
        final rows = await txn.query(
          DatabaseHelper.tableFocusTargets,
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        return FocusTargetModel.fromMap(rows.first);
      });
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to find or create focus target: $e');
    }
  }

  @override
  Future<List<FocusTargetModel>> getRecentFocusTargets({int limit = 10}) async {
    try {
      final db = await _db;
      const query = '''
        SELECT ft.*
        FROM ${DatabaseHelper.tableFocusTargets} ft
        LEFT JOIN (
          SELECT target_id, MAX(session_id) as last_session_id
          FROM ${DatabaseHelper.tableSessionTargets}
          GROUP BY target_id
        ) st ON ft.id = st.target_id
        WHERE ft.is_archived = 0
        ORDER BY st.last_session_id DESC NULLS LAST, ft.created_at DESC
        LIMIT ?;
      ''';
      final results = await db.rawQuery(query, [limit]);
      return results.map(FocusTargetModel.fromMap).toList();
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to fetch recent focus targets: $e');
    }
  }

  @override
  Future<List<SessionTargetAllocationModel>> getSessionTargets(
    int sessionId,
  ) async {
    try {
      final db = await _db;
      const query = '''
        SELECT st.*, ft.name, ft.color_hex
        FROM ${DatabaseHelper.tableSessionTargets} st
        JOIN ${DatabaseHelper.tableFocusTargets} ft ON st.target_id = ft.id
        WHERE st.session_id = ?
        ORDER BY st.display_order ASC;
      ''';
      final results = await db.rawQuery(query, [sessionId]);
      return results.map(SessionTargetAllocationModel.fromMap).toList();
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
          'Failed to fetch session targets for session $sessionId: $e');
    }
  }

  Future<bool> _hasTable(DatabaseExecutor db, String tableName) async {
    final res = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
      [tableName],
    );
    return res.isNotEmpty;
  }

  Future<int> _findOrCreateFocusTargetInTxn(
    DatabaseExecutor txn,
    String name, {
    String colorHex = '#00E5FF',
  }) async {
    final trimmed = name.trim();
    final existing = await txn.query(
      DatabaseHelper.tableFocusTargets,
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return (existing.first['id'] as num).toInt();
    }

    return await txn.insert(
      DatabaseHelper.tableFocusTargets,
      <String, dynamic>{
        'name': trimmed,
        'color_hex': colorHex,
        'is_archived': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
