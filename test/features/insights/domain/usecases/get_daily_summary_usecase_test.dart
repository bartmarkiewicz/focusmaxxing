import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/insights/domain/repositories/i_insights_repository.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_daily_summary_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

class _MockInsightsRepository implements IInsightsRepository {
  DailySummaryEntity? mockSummary;
  Failure? mockFailure;
  DateTime? capturedDate;
  bool? capturedIncludeWeekends;

  @override
  Future<Either<Failure, DailySummaryEntity>> getDailySummary(
    DateTime date, {
    bool includeWeekendsInStreak = false,
  }) async {
    capturedDate = date;
    capturedIncludeWeekends = includeWeekendsInStreak;
    if (mockFailure != null) {
      return Left(mockFailure!);
    }
    return Right(mockSummary!);
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getRecentSessions({int days = 7}) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, int>> calculateStreak({
    DateTime? referenceDate,
    bool includeWeekends = false,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  late _MockInsightsRepository repository;
  late GetDailySummaryUseCase useCase;

  setUp(() {
    repository = _MockInsightsRepository();
    useCase = GetDailySummaryUseCase(repository);
  });

  test('delegates to repository with date and includeWeekends flag', () async {
    final now = DateTime(2026, 10, 14);
    final expectedSummary = DailySummaryEntity(
      date: now,
      totalFocusMinutes: 50,
      completedSessionsCount: 2,
      currentStreakDays: 3,
    );
    repository.mockSummary = expectedSummary;

    final result = await useCase(now, includeWeekendsInStreak: true);

    expect(result, Right<Failure, DailySummaryEntity>(expectedSummary));
    expect(repository.capturedDate, now);
    expect(repository.capturedIncludeWeekends, isTrue);
  });

  test('returns Left when repository returns Failure', () async {
    final now = DateTime(2026, 10, 14);
    repository.mockFailure = const DatabaseFailure('DB query error');

    final result = await useCase(now);

    expect(
      result,
      const Left<Failure, DailySummaryEntity>(DatabaseFailure('DB query error')),
    );
  });
}
