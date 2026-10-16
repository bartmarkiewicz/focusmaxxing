import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';

/// Starts gapless loop playback for a given bundled soundscape asset path.
class PlaySoundscapeUseCase {
  final IAudioRepository repository;

  const PlaySoundscapeUseCase(this.repository);

  Future<Either<Failure, void>> call(String assetPath) {
    final trimmedPath = assetPath.trim();
    if (trimmedPath.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Audio asset path cannot be empty')),
      );
    }
    return repository.playLoop(trimmedPath);
  }
}
