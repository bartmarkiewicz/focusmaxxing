import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/insights/domain/repositories/i_insights_repository.dart';
import 'package:focusmaxxing/features/insights/domain/usecases/get_recent_sessions_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

class _MockInsightsRepository implements IInsightsRepository {
  List<SessionEntity>? mockSessions;
  Failure? mockFailure;
  int? capturedDays;

  @override
  Future<Either<Failure, DailySummaryEntity>> getDailySummary(
    DateTime date, {
    bool includeWeekendsInStreak = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getRecentSessions({int days = 7}) async {
    capturedDays = days;
    if (mockFailure != null) {
      return Left(mockFailure!);
    }
    return Right(mockSessions!);
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
  late GetRecentSessionsUseCase useCase;

  setUp(() {
    repository = _MockInsightsRepository();
    useCase = GetRecentSessionsUseCase(repository);
  });

  test('delegates to repository with days argument', () async {
    const session = SessionEntity(
      id: 1,
      taskGoal: 'Clean Architecture Test',
      sessionType: SessionType.focus,
      targetDurationSeconds: 1500,
      actualDurationSeconds: 1500,
      startTimeEpochMs: 1000000,
      endTimeEpochMs: 1001500,
      status: SessionStatus.lockedIn,
    );
    repository.mockSessions = const [session];

    final result = await useCase(days: 7);

    expect(result, const Right<Failure, List<SessionEntity>>([session]));
    expect(repository.capturedDays, 7);
  });

  test('returns Left when repository returns Failure', () async {
    repository.mockFailure = const DatabaseFailure('Failed to query sessions');

    final result = await useCase();

    expect(
      result,
      const Left<Failure, List<SessionEntity>>(
        DatabaseFailure('Failed to query sessions'),
      ),
    );
  });
}
