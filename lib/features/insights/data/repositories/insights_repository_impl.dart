import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/utils/date_utils.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/insights/domain/repositories/i_insights_repository.dart';
import 'package:focusmaxxing/features/timer/data/datasources/session_local_data_source.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

class InsightsRepositoryImpl implements IInsightsRepository {
  final ISessionLocalDataSource localDataSource;

  const InsightsRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, DailySummaryEntity>> getDailySummary(
    DateTime date, {
    bool includeWeekendsInStreak = false,
  }) async {
    try {
      final startOfDay = AppDateUtils.getStartOfDay(date);
      final endOfDay = AppDateUtils.getEndOfDay(date);

      final todayModels = await localDataSource.getSessionsForDateRange(
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      );

      final todaySessions = todayModels.map((m) => m.toEntity()).toList();

      final focusSessions = todaySessions
          .where((s) =>
              s.sessionType == SessionType.focus &&
              s.status == SessionStatus.lockedIn)
          .toList();

      final totalSeconds = focusSessions.fold<int>(
        0,
        (sum, s) => sum + s.actualDurationSeconds,
      );
      final totalFocusMinutes = (totalSeconds / 60).round();

      final completedSessionsCount = focusSessions.length;

      final streakResult = await calculateStreak(
        referenceDate: date,
        includeWeekends: includeWeekendsInStreak,
      );

      final currentStreak = streakResult.fold(
        (failure) => 0,
        (streak) => streak,
      );

      return Right(
        DailySummaryEntity(
          date: date,
          totalFocusMinutes: totalFocusMinutes,
          completedSessionsCount: completedSessionsCount,
          currentStreakDays: currentStreak,
        ),
      );
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getRecentSessions({
    int days = 7,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = AppDateUtils.getStartOfDay(
        DateTime(now.year, now.month, now.day - (days - 1)),
      );
      final endDate = AppDateUtils.getEndOfDay(now);

      final models = await localDataSource.getSessionsForDateRange(
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      );

      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> calculateStreak({
    DateTime? referenceDate,
    bool includeWeekends = false,
  }) async {
    try {
      final startTimes =
          await localDataSource.getCompletedFocusSessionStartTimes();

      final completedDays = <DateTime>{};
      for (final epochMs in startTimes) {
        final sessionDate = DateTime.fromMillisecondsSinceEpoch(epochMs);
        completedDays.add(AppDateUtils.getStartOfDay(sessionDate));
      }

      final refDate =
          AppDateUtils.getStartOfDay(referenceDate ?? DateTime.now());

      int streak = 0;
      DateTime checkDay = refDate;
      final hasToday = completedDays.contains(checkDay);

      if (hasToday) {
        streak++;
        checkDay = DateTime(checkDay.year, checkDay.month, checkDay.day - 1);
      } else {
        checkDay = DateTime(checkDay.year, checkDay.month, checkDay.day - 1);
      }

      while (true) {
        final isWeekend = AppDateUtils.isWeekend(checkDay);
        final hasCompleted = completedDays.contains(checkDay);

        if (hasCompleted) {
          streak++;
          checkDay = DateTime(checkDay.year, checkDay.month, checkDay.day - 1);
        } else if (!includeWeekends && isWeekend) {
          checkDay = DateTime(checkDay.year, checkDay.month, checkDay.day - 1);
        } else {
          break;
        }
      }

      return Right(streak);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
