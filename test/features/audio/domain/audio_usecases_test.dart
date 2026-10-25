import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/play_chime_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/play_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/set_audio_volume_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/stop_soundscape_usecase.dart';

class _StubAudioRepository implements IAudioRepository {
  String? lastPlayedPath;
  String? lastChimePath;
  double? lastVolume;
  bool didStop = false;

  @override
  Future<Either<Failure, void>> playLoop(String assetPath) async {
    lastPlayedPath = assetPath;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> stopLoop() async {
    didStop = true;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setVolume(double volume) async {
    lastVolume = volume;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> preloadAssets(List<String> assetPaths) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> playChime({
    String assetPath = SoundscapeEntity.chimeCompleteAssetPath,
  }) async {
    lastChimePath = assetPath;
    return const Right(null);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('SoundscapeEntity & Audio UseCases', () {
    test('SoundscapeEntity.fromId resolves known presets and defaults to none',
        () {
      expect(
        SoundscapeEntity.fromId('brown_noise'),
        equals(SoundscapeEntity.brownNoise),
      );
      expect(
        SoundscapeEntity.fromId('gamma_40hz'),
        equals(SoundscapeEntity.gamma40Hz),
      );
      expect(
        SoundscapeEntity.fromId('rain'),
        equals(SoundscapeEntity.rain),
      );
      expect(
        SoundscapeEntity.fromId('unknown_id'),
        equals(SoundscapeEntity.none),
      );
      expect(SoundscapeEntity.none.isNone, isTrue);
      expect(SoundscapeEntity.brownNoise.isNone, isFalse);
      expect(SoundscapeEntity.brownNoise.isProOnly, isFalse);
    });

    test('PlaySoundscapeUseCase validates non-empty assetPath', () async {
      final repo = _StubAudioRepository();
      final useCase = PlaySoundscapeUseCase(repo);

      final invalid = await useCase('   ');
      expect(invalid.isLeft(), isTrue);

      final valid = await useCase(' assets/audio/brown_noise_loop.ogg ');
      expect(valid.isRight(), isTrue);
      expect(repo.lastPlayedPath, equals('assets/audio/brown_noise_loop.ogg'));
    });

    test('StopSoundscapeUseCase delegates to repository.stopLoop', () async {
      final repo = _StubAudioRepository();
      final useCase = StopSoundscapeUseCase(repo);

      final result = await useCase();
      expect(result.isRight(), isTrue);
      expect(repo.didStop, isTrue);
    });

    test('SetAudioVolumeUseCase clamps volume and rejects NaN', () async {
      final repo = _StubAudioRepository();
      final useCase = SetAudioVolumeUseCase(repo);

      final nanResult = await useCase(double.nan);
      expect(nanResult.isLeft(), isTrue);

      await useCase(1.4);
      expect(repo.lastVolume, equals(1.0));

      await useCase(-0.2);
      expect(repo.lastVolume, equals(0.0));
    });

    test('PlayChimeUseCase delegates to repository.playChime', () async {
      final repo = _StubAudioRepository();
      final useCase = PlayChimeUseCase(repo);

      final result = await useCase();
      expect(result.isRight(), isTrue);
      expect(repo.lastChimePath,
          equals(SoundscapeEntity.chimeCompleteAssetPath));
    });
  });
}
