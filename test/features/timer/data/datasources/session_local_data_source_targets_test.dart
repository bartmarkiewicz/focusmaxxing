import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/database/database_helper.dart';
import 'package:focusmaxxing/core/database/migrations/migration_runner.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v1.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v2.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v3.dart';
import 'package:focusmaxxing/core/database/migrations/migration_v4.dart';
import 'package:focusmaxxing/features/timer/data/datasources/session_local_data_source.dart';
import 'package:focusmaxxing/features/timer/data/models/session_model.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late SessionLocalDataSource dataSource;

  setUp(() async {
    final factory = databaseFactoryFfi;
    db = await factory.openDatabase(inMemoryDatabasePath);

    final runner = MigrationRunner(
      migrations: const [
        MigrationV1(),
        MigrationV2(),
        MigrationV3(),
        MigrationV4(),
      ],
    );
    await runner.run(db, oldVersion: 0, targetVersion: 4);

    DatabaseHelper.setMockDatabase(db, factory: factory);
    dataSource = SessionLocalDataSource();
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.setMockDatabase(null);
  });

  group('SessionLocalDataSource with Targets', () {
    test('insertSession writes targets to focus_targets and session_targets', () async {
      const targets = [
        SessionTargetAllocation(
          targetName: 'Mobile UI',
          percentage: 60,
          colorHex: '#00E5FF',
          displayOrder: 1,
        ),
        SessionTargetAllocation(
          targetName: 'API Refactor',
          percentage: 40,
          colorHex: '#FF4081',
          displayOrder: 2,
        ),
      ];

      const session = SessionModel(
        taskGoal: 'Mobile UI • API Refactor',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 0,
        startTimeEpochMs: 1000,
        endTimeEpochMs: 2500,
        status: SessionStatus.cancelled,
        targets: targets,
      );

      final sessionId = await dataSource.insertSession(session);
      expect(sessionId, greaterThan(0));

      final savedTargets = await dataSource.getSessionTargets(sessionId);
      expect(savedTargets.length, 2);
      expect(savedTargets[0].targetName, 'Mobile UI');
      expect(savedTargets[0].percentage, 60);
      expect(savedTargets[0].allocatedSeconds, 0); // Not locked in yet
      expect(savedTargets[1].targetName, 'API Refactor');
      expect(savedTargets[1].percentage, 40);
    });

    test('updateSessionStatus to LOCKED_IN computes and persists proportional allocated_seconds', () async {
      const targets = [
        SessionTargetAllocation(
          targetName: 'Mobile UI',
          percentage: 70,
          displayOrder: 1,
        ),
        SessionTargetAllocation(
          targetName: 'Bugfix #12',
          percentage: 30,
          displayOrder: 2,
        ),
      ];

      const session = SessionModel(
        taskGoal: 'Mobile UI • Bugfix #12',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 0,
        startTimeEpochMs: 1000,
        endTimeEpochMs: 2500,
        status: SessionStatus.cancelled,
        targets: targets,
      );

      final sessionId = await dataSource.insertSession(session);

      // User locks in for 1500 seconds (25 minutes)
      // 1500 * 0.70 = 1050s
      // 1500 * 0.30 = 450s
      await dataSource.updateSessionStatus(sessionId, SessionStatus.lockedIn, 1500);

      final updatedTargets = await dataSource.getSessionTargets(sessionId);
      expect(updatedTargets.length, 2);
      expect(updatedTargets[0].allocatedSeconds, 1050);
      expect(updatedTargets[1].allocatedSeconds, 450);
      expect(updatedTargets[0].allocatedSeconds + updatedTargets[1].allocatedSeconds, 1500);
    });

    test('updateSessionStatus to DERAILED writes 0 allocated seconds', () async {
      const targets = [
        SessionTargetAllocation(
          targetName: 'Mobile UI',
          percentage: 50,
          displayOrder: 1,
        ),
        SessionTargetAllocation(
          targetName: 'API Refactor',
          percentage: 50,
          displayOrder: 2,
        ),
      ];

      const session = SessionModel(
        taskGoal: 'Mobile UI • API Refactor',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 0,
        startTimeEpochMs: 1000,
        endTimeEpochMs: 2500,
        status: SessionStatus.cancelled,
        targets: targets,
      );

      final sessionId = await dataSource.insertSession(session);
      await dataSource.updateSessionStatus(sessionId, SessionStatus.derailed, 1500);

      final updatedTargets = await dataSource.getSessionTargets(sessionId);
      expect(updatedTargets[0].allocatedSeconds, 0);
      expect(updatedTargets[1].allocatedSeconds, 0);
    });

    test('findOrCreateFocusTarget is idempotent and case-insensitive', () async {
      final t1 = await dataSource.findOrCreateFocusTarget('Mobile UI', colorHex: '#00E5FF');
      final t2 = await dataSource.findOrCreateFocusTarget('  mobile ui  ', colorHex: '#FF4081');

      expect(t1.id, isNotNull);
      expect(t1.id, equals(t2.id));
      expect(t2.name, 'Mobile UI');
    });

    test('getRecentFocusTargets orders by last session usage', () async {
      final targetA = await dataSource.findOrCreateFocusTarget('Target A');
      final targetB = await dataSource.findOrCreateFocusTarget('Target B');

      // Session 1 with Target A
      await dataSource.insertSession(
        SessionModel(
          taskGoal: 'Target A',
          sessionType: SessionType.focus,
          targetDurationSeconds: 1500,
          actualDurationSeconds: 1500,
          startTimeEpochMs: 1000,
          endTimeEpochMs: 2500,
          status: SessionStatus.lockedIn,
          targets: [
            SessionTargetAllocation(
              targetId: targetA.id,
              targetName: targetA.name,
              percentage: 100,
            ),
          ],
        ),
      );

      // Session 2 with Target B (later session)
      await dataSource.insertSession(
        SessionModel(
          taskGoal: 'Target B',
          sessionType: SessionType.focus,
          targetDurationSeconds: 1500,
          actualDurationSeconds: 1500,
          startTimeEpochMs: 3000,
          endTimeEpochMs: 4500,
          status: SessionStatus.lockedIn,
          targets: [
            SessionTargetAllocation(
              targetId: targetB.id,
              targetName: targetB.name,
              percentage: 100,
            ),
          ],
        ),
      );

      final recent = await dataSource.getRecentFocusTargets(limit: 5);
      expect(recent.length, greaterThanOrEqualTo(2));
      expect(recent.first.name, 'Target B');
    });
  });
}
