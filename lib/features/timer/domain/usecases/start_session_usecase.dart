import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/utils/target_allocation_balancer.dart';

class StartSessionUseCase {
  const StartSessionUseCase(this.repository);

  final ISessionRepository repository;

  Future<Either<Failure, int>> call({
    required String taskGoal,
    required String sessionType,
    required int targetDurationSeconds,
    List<SessionTargetAllocation> targets = const [],
  }) async {
    if (targetDurationSeconds <= 0) {
      return const Left<Failure, int>(
        ValidationFailure('Target duration must be greater than zero'),
      );
    }

    if (targets.isNotEmpty) {
      for (final target in targets) {
        if (target.targetName.trim().length > 60) {
          return const Left<Failure, int>(
            ValidationFailure('Target name cannot exceed 60 characters'),
          );
        }
      }
    } else {
      final trimmedGoal = taskGoal.trim();
      if (trimmedGoal.length > 60) {
        return const Left<Failure, int>(
          ValidationFailure('Task goal cannot exceed 60 characters'),
        );
      }
    }

    final trimmedGoal = taskGoal.trim();
    final effectiveGoal = trimmedGoal.isNotEmpty
        ? trimmedGoal
        : (targets.isNotEmpty
            ? TargetAllocationBalancer.formatGoalSummary(targets)
            : 'Deep Work');

    final now = DateTime.now().millisecondsSinceEpoch;
    final session = SessionEntity(
      taskGoal: effectiveGoal,
      sessionType: sessionType,
      targetDurationSeconds: targetDurationSeconds,
      actualDurationSeconds: 0,
      startTimeEpochMs: now,
      endTimeEpochMs: now + (targetDurationSeconds * 1000),
      status: SessionStatus.cancelled,
      targets: targets,
    );
    return await repository.createSession(session);
  }
}
