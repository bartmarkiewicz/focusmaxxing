import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const String databaseName = 'focusmaxxing.db';
  static const int databaseVersion = 1;

  static const String tableSessions = 'sessions';
  static const String tableBacklogTasks = 'backlog_tasks';

  static Database? _database;
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
    _databaseFactory = factory;
    _customMigrationRunner = migrationRunner;
  }

  MigrationRunner get _runner =>
      _customMigrationRunner ??
      MigrationRunner(migrations: const [
        MigrationV1(),
      ]);

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
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
  }

  Future<void> _onCreate(Database db, int version) async {
    await _runner.run(db, oldVersion: 0, targetVersion: version);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _runner.run(db, oldVersion: oldVersion, targetVersion: newVersion);
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
