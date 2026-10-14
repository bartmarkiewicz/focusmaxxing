import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/utils/date_utils.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';

class GetTodaySessionsUseCase {
  final ISessionRepository repository;

  const GetTodaySessionsUseCase(this.repository);

  Future<Either<Failure, List<SessionEntity>>> call({DateTime? now}) {
    final current = now ?? DateTime.now();
    final startOfDayMs = AppDateUtils.getStartOfDay(current).millisecondsSinceEpoch;
    final endOfDayMs = AppDateUtils.getEndOfDay(current).millisecondsSinceEpoch;
    return repository.getSessionsForDateRange(startOfDayMs, endOfDayMs);
  }
}
