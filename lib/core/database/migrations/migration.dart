import 'package:sqflite/sqflite.dart';

abstract class Migration {
  final int version;
  final String description;

  const Migration(this.version, this.description);

  Future<void> up(DatabaseExecutor db);
}
