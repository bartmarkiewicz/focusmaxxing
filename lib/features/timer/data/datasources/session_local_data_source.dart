import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/features/timer/data/models/session_model.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

abstract class ISessionLocalDataSource {
  Future<int> insertSession(SessionModel session);
  Future<void> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  );
  Future<List<SessionModel>> getSessionsForDateRange(int startMs, int endMs);
  Future<List<SessionModel>> getAllSessions({int limit = 100});
  Future<List<int>> getCompletedFocusSessionStartTimes();
}

class SessionLocalDataSource implements ISessionLocalDataSource {
  final DatabaseHelper _databaseHelper;

  SessionLocalDataSource({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _databaseHelper.database;

  @override
  Future<int> insertSession(SessionModel session) async {
    try {
      final db = await _db;
      return await db.insert(
        DatabaseHelper.tableSessions,
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on Exception catch (e) {
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
      final count = await db.update(
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
        throw DatabaseException('No session found with ID $sessionId to update');
      }
    } on Exception catch (e) {
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
      return results.map((row) => SessionModel.fromMap(row)).toList();
    } on Exception catch (e) {
      throw DatabaseException('Failed to query sessions for date range: $e');
    }
  }

  @override
  Future<List<SessionModel>> getAllSessions({int limit = 100}) async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseHelper.tableSessions,
        orderBy: 'start_time_epoch_ms DESC',
        limit: limit,
      );
      return results.map((row) => SessionModel.fromMap(row)).toList();
    } on Exception catch (e) {
      throw DatabaseException('Failed to query all sessions: $e');
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
      return results
          .map((row) => row['start_time_epoch_ms'] as int)
          .toList();
    } on Exception catch (e) {
      throw DatabaseException(
          'Failed to query completed session timestamps: $e');
    }
  }
}
