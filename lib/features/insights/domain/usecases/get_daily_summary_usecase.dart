import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/insights/domain/repositories/i_insights_repository.dart';

class GetDailySummaryUseCase {
  final IInsightsRepository repository;

  const GetDailySummaryUseCase(this.repository);

  Future<Either<Failure, DailySummaryEntity>> call(
    DateTime date, {
    bool includeWeekendsInStreak = false,
  }) {
    return repository.getDailySummary(
      date,
      includeWeekendsInStreak: includeWeekendsInStreak,
    );
  }
}
