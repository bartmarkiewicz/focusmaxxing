import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

abstract class IInsightsRepository {
  Future<Either<Failure, DailySummaryEntity>> getDailySummary(
    DateTime date, {
    bool includeWeekendsInStreak = false,
  });

  Future<Either<Failure, List<SessionEntity>>> getRecentSessions({
    int days = 7,
  });

  Future<Either<Failure, int>> calculateStreak({
    DateTime? referenceDate,
    bool includeWeekends = false,
  });
}
