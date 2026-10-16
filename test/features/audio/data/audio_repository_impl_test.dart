import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/audio/data/repositories/audio_repository_impl.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';
import 'package:just_audio/just_audio.dart';

class _FakeAudioPlayerEngine implements IAudioPlayerEngine {
  int configureSessionCount = 0;
  final List<String> setAssetCalls = [];
  final List<LoopMode> loopModes = [];
  int playCount = 0;
  int stopCount = 0;
  final List<double> volumes = [];
  final List<String> oneShotAssets = [];
  int disposeCount = 0;
  Exception? exceptionToThrow;

  @override
  Future<void> configureAudioSession() async {
    if (exceptionToThrow case final ex?) throw ex;
    configureSessionCount++;
  }

  @override
  Future<void> setAsset(String assetPath) async {
    if (exceptionToThrow case final ex?) throw ex;
    setAssetCalls.add(assetPath);
  }

  @override
  Future<void> setLoopMode(LoopMode loopMode) async {
    if (exceptionToThrow case final ex?) throw ex;
    loopModes.add(loopMode);
  }

  @override
  Future<void> play() async {
    if (exceptionToThrow case final ex?) throw ex;
    playCount++;
  }

  @override
  Future<void> stop() async {
    if (exceptionToThrow case final ex?) throw ex;
    stopCount++;
  }

  @override
  Future<void> setVolume(double volume) async {
    if (exceptionToThrow case final ex?) throw ex;
    volumes.add(volume);
  }

  @override
  Future<void> playOneShotAsset(String assetPath, {double volume = 1.0}) async {
    if (exceptionToThrow case final ex?) throw ex;
    oneShotAssets.add(assetPath);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

void main() {
  late _FakeAudioPlayerEngine engine;
  late AudioRepositoryImpl repository;

  setUp(() {
    engine = _FakeAudioPlayerEngine();
    repository = AudioRepositoryImpl(engine: engine);
  });

  group('AudioRepositoryImpl', () {
    test('playLoop configures session once, sets asset, sets LoopMode.one, and plays', () async {
      final result1 = await repository.playLoop('assets/audio/brown_noise_loop.ogg');
      final result2 = await repository.playLoop('assets/audio/brown_noise_loop.ogg');

      expect(result1.isRight(), isTrue);
      expect(result2.isRight(), isTrue);
      expect(engine.configureSessionCount, equals(1));
      expect(engine.setAssetCalls, equals(['assets/audio/brown_noise_loop.ogg']));
      expect(engine.loopModes, equals([LoopMode.one, LoopMode.one]));
      expect(engine.playCount, equals(2));
    });

    test('playLoop returns ValidationFailure when assetPath is empty', () async {
      final result = await repository.playLoop('   ');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected Left'),
      );
      expect(engine.playCount, equals(0));
    });

    test('playLoop maps PlatformException to PlatformFailure', () async {
      engine.exceptionToThrow = PlatformException(
        code: 'AUDIO_ERR',
        message: 'Failed to decode OGG stream',
      );

      final result = await repository.playLoop('assets/audio/rain_canvas_loop.ogg');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<PlatformFailure>());
          expect(failure.message, contains('Failed to decode OGG stream'));
        },
        (_) => fail('Expected Left'),
      );
    });

    test('stopLoop invokes engine stop', () async {
      final result = await repository.stopLoop();

      expect(result.isRight(), isTrue);
      expect(engine.stopCount, equals(1));
    });

    test('setVolume clamps values to [0.0, 1.0] and rejects NaN', () async {
      final resValid = await repository.setVolume(0.75);
      final resHigh = await repository.setVolume(2.5);
      final resLow = await repository.setVolume(-1.0);
      final resNan = await repository.setVolume(double.nan);

      expect(resValid.isRight(), isTrue);
      expect(resHigh.isRight(), isTrue);
      expect(resLow.isRight(), isTrue);
      expect(resNan.isLeft(), isTrue);
      expect(engine.volumes, equals([0.75, 1.0, 0.0]));
    });

    test('preloadAssets configures session and preloads first valid asset', () async {
      final result = await repository.preloadAssets([
        '',
        'assets/audio/gamma_40hz_loop.ogg',
      ]);

      expect(result.isRight(), isTrue);
      expect(engine.configureSessionCount, equals(1));
      expect(engine.setAssetCalls, equals(['assets/audio/gamma_40hz_loop.ogg']));
      expect(engine.loopModes, equals([LoopMode.one]));
    });

    test('playChime plays completion chime asset', () async {
      final result = await repository.playChime();

      expect(result.isRight(), isTrue);
      expect(
        engine.oneShotAssets,
        equals([SoundscapeEntity.chimeCompleteAssetPath]),
      );
    });

    test('dispose cleans up engine resources', () async {
      await repository.dispose();
      expect(engine.disposeCount, equals(1));
    });
  });
}
