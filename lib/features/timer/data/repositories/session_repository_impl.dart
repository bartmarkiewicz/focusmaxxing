import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/timer/data/datasources/session_local_data_source.dart';
import 'package:focusmaxxing/features/timer/data/models/session_model.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';

class SessionRepositoryImpl implements ISessionRepository {
  final ISessionLocalDataSource localDataSource;

  const SessionRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async {
    try {
      final model = SessionModel.fromEntity(session);
      final id = await localDataSource.insertSession(model);
      return Right(id);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async {
    try {
      await localDataSource.updateSessionStatus(
        sessionId,
        status,
        actualDurationSeconds,
      );
      return const Right(null);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async {
    try {
      final models = await localDataSource.getSessionsForDateRange(
        startMs,
        endMs,
      );
      final entities = models.map((m) => m.toEntity()).toList();
      return Right(entities);
    } on DatabaseException catch (e) {
      return Left(DatabaseFailure(e.message));
    }
  }
}
