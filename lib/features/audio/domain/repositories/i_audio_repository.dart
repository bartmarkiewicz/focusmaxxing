import 'package:dartz/dartz.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';

/// Domain contract for ambient soundscape playback and audio session management.
abstract interface class IAudioRepository {
  Future<Either<Failure, void>> playLoop(String assetPath);

  Future<Either<Failure, void>> stopLoop();

  Future<Either<Failure, void>> setVolume(double volume);

  Future<Either<Failure, void>> preloadAssets(List<String> assetPaths);

  Future<Either<Failure, void>> playChime({
    String assetPath = SoundscapeEntity.chimeCompleteAssetPath,
  });

  Future<void> dispose();
}
