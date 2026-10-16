import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';

/// Clamps the requested volume to [0.0, 1.0] and applies it to the audio player.
class SetAudioVolumeUseCase {
  final IAudioRepository repository;

  const SetAudioVolumeUseCase(this.repository);

  Future<Either<Failure, void>> call(double volume) {
    if (volume.isNaN) {
      return Future.value(
        const Left(ValidationFailure('Audio volume cannot be NaN')),
      );
    }
    final clampedVolume = volume.clamp(0.0, 1.0);
    return repository.setVolume(clampedVolume);
  }
}
