import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v2.dart';
import 'package:focusmaxxing/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final runner = MigrationRunner(
      migrations: const [MigrationV1(), MigrationV2()],
    );
    await runner.run(db, oldVersion: 0, targetVersion: 2);
    DatabaseHelper.setMockDatabase(db);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.setMockDatabase(null);
  });

  testWidgets('FocusmaxxingApp launches and displays app title',
      (tester) async {
    await tester.pumpWidget(const FocusmaxxingApp());
    await tester.pumpAndSettle();

    expect(find.text('FOCUSMAXXING'), findsOneWidget);
  });
}
