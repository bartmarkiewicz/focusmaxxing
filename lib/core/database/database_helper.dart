import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v2.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v3.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v4.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

class DatabaseHelper {
  static const String databaseName = 'focusmaxxing.db';
  static const int databaseVersion = 4;

  static const String tableSessions = 'sessions';
  static const String tableBacklogTasks = 'backlog_tasks';
  static const String tableShieldedApps = 'shielded_apps';
  static const String tableDailyFocusMetrics = 'daily_focus_metrics';
  static const String tableFocusTargets = 'focus_targets';
  static const String tableSessionTargets = 'session_targets';

  static Database? _database;
  static bool _isMockDatabase = false;
  static Future<Database>? _initFuture;
  static DatabaseFactory? _databaseFactory;
  static MigrationRunner? _customMigrationRunner;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static void setMockDatabase(
    Database? db, {
    DatabaseFactory? factory,
    MigrationRunner? migrationRunner,
  }) {
    _database = db;
    _isMockDatabase = db != null;
    _initFuture = null;
    _databaseFactory = factory;
    _customMigrationRunner = migrationRunner;
  }

  MigrationRunner get _runner =>
      _customMigrationRunner ??
      MigrationRunner(migrations: const [
        MigrationV1(),
        MigrationV2(),
        MigrationV3(),
        MigrationV4(),
      ]);

  Future<Database> get database async {
    final currentDb = _database;
    if (currentDb != null) {
      if (currentDb.isOpen) {
        return currentDb;
      }
      if (_isMockDatabase) {
        throw const DatabaseException('Database is closed');
      }
      _database = null;
      _initFuture = null;
    }
    final future = _initFuture ??= _initDatabase();
    try {
      final db = await future;
      if (_initFuture != future) {
        if (db.isOpen) await db.close();
        throw const DatabaseException(
            'Database was closed during initialization');
      }
      _database = db;
      if (db.isOpen) return db;
      throw const DatabaseException('Database failed to initialize');
    } catch (_) {
      if (_initFuture == future) {
        _database = null;
        _initFuture = null;
      }
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final factory = _databaseFactory ?? databaseFactory;
    final databasesPath = await factory.getDatabasesPath();
    final path = p.join(databasesPath, databaseName);

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      ),
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL;');
    } on Exception catch (_) {
      // Ignore if WAL mode is unsupported on the current SQLite driver.
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _runner.run(db,
        oldVersion: 0, targetVersion: version, useTransaction: false);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _runner.run(db,
        oldVersion: oldVersion,
        targetVersion: newVersion,
        useTransaction: false);
  }

  Future<void> close() async {
    final currentDb = _database;
    _database = null;
    _isMockDatabase = false;
    _initFuture = null;
    if (currentDb != null && currentDb.isOpen) {
      await currentDb.close();
    }
  }
}
