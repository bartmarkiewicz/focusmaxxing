import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/features/shield/data/models/shielded_app_model.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

abstract interface class IShieldLocalDataSource {
  Future<List<ShieldedAppModel>> getShieldedApps();
  Future<List<ShieldedAppModel>> getActiveShieldedApps();
  Future<void> upsertShieldedApp(ShieldedAppModel app);
  Future<void> swapShieldedApp({
    required String deactivatePackageName,
    required ShieldedAppModel activateApp,
  });
  Future<void> purgeUninstalledApps(Set<String> installedPackages);
}

class ShieldLocalDataSource implements IShieldLocalDataSource {
  ShieldLocalDataSource({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<Database> get _db => _databaseHelper.database;

  @override
  Future<List<ShieldedAppModel>> getShieldedApps() async {
    try {
      final db = await _db;
      final rows = await db.query(
        DatabaseHelper.tableShieldedApps,
        orderBy: 'app_name ASC',
      );
      return rows.map(ShieldedAppModel.fromMap).toList();
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to fetch shielded apps: $e');
    }
  }

  @override
  Future<List<ShieldedAppModel>> getActiveShieldedApps() async {
    try {
      final db = await _db;
      final rows = await db.query(
        DatabaseHelper.tableShieldedApps,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'app_name ASC',
      );
      return rows.map(ShieldedAppModel.fromMap).toList();
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to fetch active shielded apps: $e');
    }
  }

  @override
  Future<void> upsertShieldedApp(ShieldedAppModel app) async {
    try {
      final db = await _db;
      await db.insert(
        DatabaseHelper.tableShieldedApps,
        app.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException(
        'Failed to upsert shielded app ${app.packageName}: $e',
      );
    }
  }

  @override
  Future<void> swapShieldedApp({
    required String deactivatePackageName,
    required ShieldedAppModel activateApp,
  }) async {
    try {
      final db = await _db;
      await db.transaction((txn) async {
        await txn.update(
          DatabaseHelper.tableShieldedApps,
          <String, dynamic>{'is_active': 0},
          where: 'package_name = ?',
          whereArgs: [deactivatePackageName],
        );
        await txn.insert(
          DatabaseHelper.tableShieldedApps,
          activateApp.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to swap shielded app: $e');
    }
  }

  @override
  Future<void> purgeUninstalledApps(Set<String> installedPackages) async {
    if (installedPackages.isEmpty) return;
    try {
      final db = await _db;
      final rows = await db.query(
        DatabaseHelper.tableShieldedApps,
        columns: ['package_name', 'is_preset'],
        where: 'is_preset = ?',
        whereArgs: [0],
      );

      final toRemove = <String>[];
      for (final row in rows) {
        final pkg = row['package_name']?.toString();
        if (pkg != null && !installedPackages.contains(pkg)) {
          toRemove.add(pkg);
        }
      }

      if (toRemove.isEmpty) return;

      await db.transaction((txn) async {
        for (final pkg in toRemove) {
          await txn.delete(
            DatabaseHelper.tableShieldedApps,
            where: 'package_name = ? AND is_preset = 0',
            whereArgs: [pkg],
          );
        }
      });
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to purge uninstalled apps: $e');
    }
  }
}
