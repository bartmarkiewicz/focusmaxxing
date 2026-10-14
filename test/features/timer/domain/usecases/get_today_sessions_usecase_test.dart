import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/utils/date_utils.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/get_today_sessions_usecase.dart';

class _MockSessionRepository implements ISessionRepository {
  int? queryStartMs;
  int? queryEndMs;

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async {
    queryStartMs = startMs;
    queryEndMs = endMs;
    return const Right<Failure, List<SessionEntity>>([]);
  }

  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async =>
      const Right<Failure, int>(1);

  @override
  Future<Either<Failure, void>> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async =>
      const Right<Failure, void>(null);
}

void main() {
  late _MockSessionRepository repository;
  late GetTodaySessionsUseCase useCase;

  setUp(() {
    repository = _MockSessionRepository();
    useCase = GetTodaySessionsUseCase(repository);
  });

  group('GetTodaySessionsUseCase', () {
    test('computes start and end of day and queries repository', () async {
      final fixedDate = DateTime(2026, 10, 14, 15, 30);
      final expectedStartMs = AppDateUtils.getStartOfDay(fixedDate).millisecondsSinceEpoch;
      final expectedEndMs = AppDateUtils.getEndOfDay(fixedDate).millisecondsSinceEpoch;

      final result = await useCase(now: fixedDate);

      expect(result.isRight(), isTrue);
      expect(repository.queryStartMs, expectedStartMs);
      expect(repository.queryEndMs, expectedEndMs);
    });
  });
}
