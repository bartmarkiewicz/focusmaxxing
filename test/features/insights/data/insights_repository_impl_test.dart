import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/insights/data/repositories/insights_repository_impl.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/timer/data/datasources/session_local_data_source.dart';
import 'package:focusmaxxing/features/timer/data/models/session_model.dart';
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
        .where((s) =>
            s.startTimeEpochMs >= startMs && s.startTimeEpochMs <= endMs)
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
        startTimeEpochMs:
            DateTime(2026, 10, 14, 10, 0).millisecondsSinceEpoch,
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
        startTimeEpochMs:
            DateTime(2026, 10, 14, 11, 0).millisecondsSinceEpoch,
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
        startTimeEpochMs:
            DateTime(2026, 10, 14, 11, 30).millisecondsSinceEpoch,
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
        startTimeEpochMs:
            DateTime(2026, 10, 14, 14, 0).millisecondsSinceEpoch,
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
        startTimeEpochMs:
            DateTime(2026, 10, 12, 10, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 12, 10, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      final s2 = SessionModel(
        taskGoal: 'Day 2',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs:
            DateTime(2026, 10, 13, 10, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 13, 10, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      final s3 = SessionModel(
        taskGoal: 'Day 3',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs:
            DateTime(2026, 10, 14, 10, 0).millisecondsSinceEpoch,
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
        startTimeEpochMs:
            DateTime(2026, 10, 9, 15, 0).millisecondsSinceEpoch,
        endTimeEpochMs: DateTime(2026, 10, 9, 15, 25).millisecondsSinceEpoch,
        status: SessionStatus.lockedIn,
      );
      final mondaySession = SessionModel(
        taskGoal: 'Monday start',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs:
            DateTime(2026, 10, 12, 9, 0).millisecondsSinceEpoch,
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

    test('preserves active streak when today is in progress and has no sessions yet',
        () async {
      // Yesterday (Tuesday 2026-10-13): 1 completed session
      // Today (Wednesday 2026-10-14): 0 sessions so far
      final tuesdaySession = SessionModel(
        taskGoal: 'Yesterday work',
        sessionType: SessionType.focus,
        targetDurationSeconds: 1500,
        actualDurationSeconds: 1500,
        startTimeEpochMs:
            DateTime(2026, 10, 13, 14, 0).millisecondsSinceEpoch,
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
