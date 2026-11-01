import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/insights/data/repositories/insights_repository_impl.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/timer/data/datasources/session_local_data_source.dart';
import 'package:focusmaxxing/features/timer/data/models/focus_target_model.dart';
import 'package:focusmaxxing/features/timer/data/models/session_model.dart';
import 'package:focusmaxxing/features/timer/data/models/session_target_allocation_model.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

class _FakeSessionLocalDataSource implements ISessionLocalDataSource {
  List<SessionModel> sessions = [];
  bool shouldThrow = false;

  @override
  Future<int> insertSession(SessionModel session) async => 1;

  @override
  Future<void> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async {}

  @override
  Future<List<SessionModel>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async {
    if (shouldThrow) throw const DatabaseException('Database read error');
    return sessions
        .where(
            (s) => s.startTimeEpochMs >= startMs && s.startTimeEpochMs <= endMs)
        .toList();
  }

  @override
  Future<List<int>> getCompletedFocusSessionStartTimes() async {
    if (shouldThrow) throw const DatabaseException('Database read error');
    return sessions
        .where((s) =>
            s.sessionType == SessionType.focus &&
            s.status == SessionStatus.lockedIn)
        .map((s) => s.startTimeEpochMs)
        .toList();
  }

  @override
  Future<List<FocusTargetModel>> getFocusTargets({bool includeArchived = false}) async => [];

  @override
  Future<FocusTargetModel> findOrCreateFocusTarget(
    String name, {
    String colorHex = '#00E5FF',
  }) async =>
      FocusTargetModel(name: name, colorHex: colorHex);

  @override
  Future<List<FocusTargetModel>> getRecentFocusTargets({int limit = 10}) async => [];

  @override
  Future<List<SessionTargetAllocationModel>> getSessionTargets(int sessionId) async => [];
}

void main() {
  late _FakeSessionLocalDataSource fakeDataSource;
  late InsightsRepositoryImpl repository;

  setUp(() {
    fakeDataSource = _FakeSessionLocalDataSource();
    repository = InsightsRepositoryImpl(localDataSource: fakeDataSource);
  });

  group('getDailySummary', () {
    test('aggregates today focus minutes and completed count strictly',
        () async {
      final today = DateTime(2026, 10, 14, 12, 0); // Wednesday

      // 1. Locked in focus session (25 mins = 1500s)
      final session1 = SessionModel(
        id: 1,
        taskGoal: 'Clean Architecture',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 14, 10, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 14, 10, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );

      // 2. Derailed focus session (distracted, should NOT count towards focus minutes or completed)
      final session2 = SessionModel(
        id: 2,
        taskGoal: 'Instagram doomscroll',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 14, 11, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 14, 11, 25).millisecondsSinceEpoch,
        status: SessionStatus.derailed,
      );

      // 3. Short break session (should NOT count towards focus minutes)
      final session3 = SessionModel(
        id: 3,
        taskGoal: 'Rest Break',
        sessionType: SessionType.shortBreak,
        targetDurationSeconds: 300,
        actualDurationSeconds: 300,
        startTimeEpochMs: DateTime(2026, 10, 14, 11, 30).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 14, 11, 35).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );

      // 4. Another locked in focus session (45 mins = 2700s)
      final session4 = SessionModel(
        id: 4,
        taskGoal: 'Feature review',
        sessionType: SessionType.focus,
        targetDurationSeconds: 2700,
        actualDurationSeconds: 2700,
        startTimeEpochMs: DateTime(2026, 10, 14, 14, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 14, 14, 45).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );

      fakeDataSource.sessions = [session1, session2, session3, session4];

      final result = await repository.getDailySummary(today);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (summary) {
          // 25 mins + 45 mins = 70 mins
          expect(summary.totalFocusMinutes, 70);
          expect(summary.completedSessionsCount, 2);
          expect(summary.currentStreakDays, 1);
        },
      );
    });

    test('returns DatabaseFailure when data source throws DatabaseException',
        () async {
      fakeDataSource.shouldThrow = true;

      final result = await repository.getDailySummary(DateTime.now());

      expect(
        result,
        const Left<Failure, DailySummaryEntity>(
          DatabaseFailure('Database read error'),
        ),
      );
    });
  });

  group('calculateStreak', () {
    test('returns 0 when database has no sessions', () async {
      final result = await repository.calculateStreak();
      expect(result, const Right<Failure, int>(0));
    });

    test('computes consecutive weekday streak correctly', () async {
      // Wednesday (2026-10-14), Tuesday (2026-10-13), Monday (2026-10-12)
      final s1 = SessionModel(
        taskGoal: 'Day 1',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 12, 10, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 12, 10, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      final s2 = SessionModel(
        taskGoal: 'Day 2',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 13, 10, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 13, 10, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      final s3 = SessionModel(
        taskGoal: 'Day 3',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 14, 10, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 14, 10, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );

      fakeDataSource.sessions = [s1, s2, s3];

      final result = await repository.calculateStreak(
        referenceDate: DateTime(2026, 10, 14),
      );

      expect(result, const Right<Failure, int>(3));
    });

    test('preserves streak across weekends when includeWeekends is false',
        () async {
      // Friday (2026-10-09): session
      // Saturday (2026-10-10): weekend, no sessions
      // Sunday (2026-10-11): weekend, no sessions
      // Monday (2026-10-12): session
      final fridaySession = SessionModel(
        taskGoal: 'Friday push',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 9, 15, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 9, 15, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      final mondaySession = SessionModel(
        taskGoal: 'Monday start',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 12, 9, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 12, 9, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );

      fakeDataSource.sessions = [fridaySession, mondaySession];

      // With weekend exemption (default)
      final resultExempt = await repository.calculateStreak(
        referenceDate: DateTime(2026, 10, 12),
        includeWeekends: false,
      );
      expect(resultExempt, const Right<Failure, int>(2));

      // With weekends required (strict 7-day mode)
      final resultStrict = await repository.calculateStreak(
        referenceDate: DateTime(2026, 10, 12),
        includeWeekends: true,
      );
      expect(resultStrict, const Right<Failure, int>(1));
    });

    test(
        'preserves active streak when today is in progress and has no sessions yet',
        () async {
      // Yesterday (Tuesday 2026-10-13): 1 completed session
      // Today (Wednesday 2026-10-14): 0 sessions so far
      final tuesdaySession = SessionModel(
        taskGoal: 'Yesterday work',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 13, 14, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 13, 14, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );

      fakeDataSource.sessions = [tuesdaySession];

      final result = await repository.calculateStreak(
        referenceDate: DateTime(2026, 10, 14),
      );

      // Streak remains alive from yesterday
      expect(result, const Right<Failure, int>(1));
    });

    test('Streak Shield auto-freezes one missed weekday in rolling 7-day window',
        () async {
      // Monday (2026-10-12): Session 1
      // Tuesday (2026-10-13): Session 2
      // Wednesday (2026-10-14): MISSED (protected by freeze)
      // Thursday (2026-10-15): Session 3
      final monSession = SessionModel(
        taskGoal: 'Mon Goal',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 12, 9, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 12, 9, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      final tueSession = SessionModel(
        taskGoal: 'Tue Goal',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 13, 9, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 13, 9, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      final thuSession = SessionModel(
        taskGoal: 'Thu Goal',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 15, 9, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 15, 9, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );

      fakeDataSource.sessions = [monSession, tueSession, thuSession];

      final result = await repository.calculateStreak(
        referenceDate: DateTime(2026, 10, 15),
      );

      // 3 completed sessions preserved across Wednesday freeze
      expect(result, const Right<Failure, int>(3));
    });

    test(
        'auto-freeze protects streak on morning launch before completing today\'s session',
        () async {
      // Mon 2026-10-12 and Tue 2026-10-13 completed
      // Wed 2026-10-14 missed
      // Thu 2026-10-15 morning: no session completed yet today
      final monSession = SessionModel(
        taskGoal: 'Mon Goal',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 12, 9, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 12, 9, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      final tueSession = SessionModel(
        taskGoal: 'Tue Goal',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 13, 9, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 13, 9, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );

      fakeDataSource.sessions = [monSession, tueSession];

      final result = await repository.calculateStreak(
        referenceDate: DateTime(2026, 10, 15),
      );

      // Preceding 2-day streak preserved across Wednesday freeze even though Thursday has 0 sessions so far
      expect(result, const Right<Failure, int>(2));
    });

    test('two consecutive missed weekdays break streak when freeze is exhausted',
        () async {
      final monSession = SessionModel(
        taskGoal: 'Mon Goal',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 12, 9, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 12, 9, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      fakeDataSource.sessions = [monSession];

      // Tue 2026-10-13 and Wed 2026-10-14 both missed; Thu 2026-10-15 has no session yet
      final resultNoToday = await repository.calculateStreak(
        referenceDate: DateTime(2026, 10, 15),
      );
      expect(resultNoToday, const Right<Failure, int>(0));

      // Even if Thu 2026-10-15 has a session, Mon is not connected across two consecutive misses
      final thuSession = SessionModel(
        taskGoal: 'Thu Goal',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: DateTime(2026, 10, 15, 9, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 15, 9, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      fakeDataSource.sessions = [monSession, thuSession];
      final resultWithToday = await repository.calculateStreak(
        referenceDate: DateTime(2026, 10, 15),
      );
      expect(resultWithToday, const Right<Failure, int>(1));
    });

    test(
        'streak freeze boundary requires 6 completed active days between two missed days',
        () async {
      SessionModel sessionOn(int year, int month, int day) {
        final start = DateTime(year, month, day, 9, 0);
        return SessionModel(
          taskGoal: 'Goal $day',
          sessionType: SessionType.focus,
          targetDurationSeconds: 1500,
          actualDurationSeconds: 1500,
          startTimeEpochMs: start.millisecondsSinceEpoch,
          endTimeEpochMs: start.add(const Duration(minutes: 25)).millisecondsSinceEpoch,
          status: SessionStatus.lockedIn,
        );
      }

      // Case 1: Only 5 completed days between two missed days (includeWeekends: true)
      // Oct 10 (completed), Oct 11 (MISSED #2), Oct 12..16 (5 completed days), Oct 17 (MISSED #1), Oct 18 (completed today)
      fakeDataSource.sessions = [
        sessionOn(2026, 10, 10),
        sessionOn(2026, 10, 12),
        sessionOn(2026, 10, 13),
        sessionOn(2026, 10, 14),
        sessionOn(2026, 10, 15),
        sessionOn(2026, 10, 16),
        sessionOn(2026, 10, 18),
      ];

      final fiveDayGapResult = await repository.calculateStreak(
        referenceDate: DateTime(2026, 10, 18),
        includeWeekends: true,
      );
      // Oct 18 (1) + Oct 17 (frozen) + Oct 16..12 (5) = 6; Oct 11 breaks because daysSinceLastFreeze == 5 < 6
      expect(fiveDayGapResult, const Right<Failure, int>(6));

      // Case 2: Exactly 6 completed days between two missed days (includeWeekends: true)
      // Oct 9 (completed), Oct 10 (MISSED #2), Oct 11..16 (6 completed days), Oct 17 (MISSED #1), Oct 18 (completed today)
      fakeDataSource.sessions = [
        sessionOn(2026, 10, 9),
        sessionOn(2026, 10, 11),
        sessionOn(2026, 10, 12),
        sessionOn(2026, 10, 13),
        sessionOn(2026, 10, 14),
        sessionOn(2026, 10, 15),
        sessionOn(2026, 10, 16),
        sessionOn(2026, 10, 18),
      ];

      final sixDayGapResult = await repository.calculateStreak(
        referenceDate: DateTime(2026, 10, 18),
        includeWeekends: true,
      );
      // Oct 18 (1) + Oct 17 (frozen #1) + Oct 16..11 (6) + Oct 10 (frozen #2) + Oct 9 (1) = 8
      expect(sixDayGapResult, const Right<Failure, int>(8));
    });
  });

  group('getRecentSessions', () {
    test('returns recent session entities mapped from data source', () async {
      final now = DateTime.now();
      final model = SessionModel(
        id: 99,
        taskGoal: 'Recent deep work',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs: now.millisecondsSinceEpoch,
        endTimeEpochMs: now.millisecondsSinceEpoch + 1500000,
        status: SessionStatus.lockedIn,
      );
      fakeDataSource.sessions = [model];

      final result = await repository.getRecentSessions(days: 7);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (sessions) {
          expect(sessions.length, 1);
          expect(sessions.first.id, 99);
          expect(sessions.first.taskGoal, 'Recent deep work');
        },
      );
    });
  });
}
