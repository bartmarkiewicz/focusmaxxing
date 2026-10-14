import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/insights/domain/repositories/i_insights_repository.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

class GetRecentSessionsUseCase {
  final IInsightsRepository repository;

  const GetRecentSessionsUseCase(this.repository);

  Future<Either<Failure, List<SessionEntity>>> call({int days = 7}) {
    return repository.getRecentSessions(days: days);
  }
}
