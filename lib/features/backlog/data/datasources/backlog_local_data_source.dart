import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/features/backlog/data/models/backlog_task_model.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

abstract interface class IBacklogLocalDataSource {
  Future<List<BacklogTaskModel>> getPendingTasks();
  Future<int> insertTask(BacklogTaskModel task);
  Future<void> deleteTask(int id);
  Future<void> markCompleted(int id, [int? sessionId]);
}

class BacklogLocalDataSource implements IBacklogLocalDataSource {
  BacklogLocalDataSource({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<Database> get _db => _databaseHelper.database;

  @override
  Future<List<BacklogTaskModel>> getPendingTasks() async {
    try {
      final db = await _db;
      final results = await db.query(
        DatabaseHelper.tableBacklogTasks,
        where: 'is_completed = ?',
        whereArgs: [0],
        orderBy: 'id DESC',
      );
      return results.map(BacklogTaskModel.fromMap).toList();
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to fetch pending backlog tasks: $e');
    }
  }

  @override
  Future<int> insertTask(BacklogTaskModel task) async {
    try {
      final db = await _db;
      return await db.insert(
        DatabaseHelper.tableBacklogTasks,
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to insert backlog task: $e');
    }
  }

  @override
  Future<void> deleteTask(int id) async {
    try {
      final db = await _db;
      final count = await db.delete(
        DatabaseHelper.tableBacklogTasks,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        throw DatabaseException('No task found with ID $id');
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to delete backlog task $id: $e');
    }
  }

  @override
  Future<void> markCompleted(int id, [int? sessionId]) async {
    try {
      final db = await _db;
      final count = await db.update(
        DatabaseHelper.tableBacklogTasks,
        <String, dynamic>{
          'is_completed': 1,
          'completed_session_id': sessionId,
          'completed_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        throw DatabaseException('No task found to complete with ID $id');
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to complete backlog task $id: $e');
    }
  }
}
