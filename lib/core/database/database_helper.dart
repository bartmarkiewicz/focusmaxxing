import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v2.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

class DatabaseHelper {
  static const String databaseName = 'focusmaxxing.db';
  static const int databaseVersion = 2;

  static const String tableSessions = 'sessions';
  static const String tableBacklogTasks = 'backlog_tasks';
  static const String tableShieldedApps = 'shielded_apps';

  static Database? _database;
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
    _initFuture = null;
    _databaseFactory = factory;
    _customMigrationRunner = migrationRunner;
  }

  MigrationRunner get _runner =>
      _customMigrationRunner ??
      MigrationRunner(migrations: const [
        MigrationV1(),
        MigrationV2(),
      ]);

  Future<Database> get database async {
    final currentDb = _database;
    if (currentDb != null) {
      if (!currentDb.isOpen) {
        _database = null;
        _initFuture = null;
        throw const DatabaseException('Database is closed');
      }
      return currentDb;
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
    } catch (_) {
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
    _initFuture = null;
    if (currentDb != null && currentDb.isOpen) {
      await currentDb.close();
    }
  }
}
