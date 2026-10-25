import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';

/// Plays the completion chime sound effect once.
class PlayChimeUseCase {
  final IAudioRepository repository;

  const PlayChimeUseCase(this.repository);

  Future<Either<Failure, void>> call({
    String assetPath = SoundscapeEntity.chimeCompleteAssetPath,
  }) {
    return repository.playChime(assetPath: assetPath);
  }
}
