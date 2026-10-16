import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';

/// Stops the currently active ambient soundscape loop.
class StopSoundscapeUseCase {
  final IAudioRepository repository;

  const StopSoundscapeUseCase(this.repository);

  Future<Either<Failure, void>> call() {
    return repository.stopLoop();
  }
}
