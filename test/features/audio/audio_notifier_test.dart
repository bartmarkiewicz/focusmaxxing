import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/core/notifications/notification_service.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/play_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/set_audio_volume_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/stop_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';
import 'package:focusmaxxing/features/timer/domain/repositories/i_session_repository.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/cancel_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/complete_session_usecase.dart';
import 'package:focusmaxxing/features/timer/domain/usecases/start_session_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioRepository implements IAudioRepository {
  final List<String> playedAssets = [];
  final List<double> volumeHistory = [];
  final List<String> playedChimes = [];
  int stopCallCount = 0;
  int disposeCallCount = 0;
  Failure? failureToReturn;
  Completer<void>? playLoopGate;

  @override
  Future<Either<Failure, void>> playLoop(String assetPath) async {
    if (playLoopGate case final gate?) {
      await gate.future;
    }
    if (failureToReturn case final failure?) {
      return Left(failure);
    }
    playedAssets.add(assetPath);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> stopLoop() async {
    stopCallCount++;
    if (failureToReturn case final failure?) {
      return Left(failure);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> setVolume(double volume) async {
    if (failureToReturn case final failure?) {
      return Left(failure);
    }
    volumeHistory.add(volume);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> preloadAssets(List<String> assetPaths) async {
    if (failureToReturn case final failure?) {
      return Left(failure);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> playChime({
    String assetPath = SoundscapeEntity.chimeCompleteAssetPath,
  }) async {
    if (failureToReturn case final failure?) {
      return Left(failure);
    }
    playedChimes.add(assetPath);
    return const Right(null);
  }

  @override
  Future<void> dispose() async {
    disposeCallCount++;
  }
}

class _FakeSessionRepository implements ISessionRepository {
  @override
  Future<Either<Failure, int>> createSession(SessionEntity session) async =>
      const Right(1);

  @override
  Future<Either<Failure, void>> updateSessionStatus(
    int sessionId,
    String status,
    int actualDurationSeconds,
  ) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<SessionEntity>>> getSessionsForDateRange(
    int startMs,
    int endMs,
  ) async =>
      const Right([]);
}

void main() {
  late _FakeAudioRepository repository;
  late AudioNotifier notifier;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = _FakeAudioRepository();
    notifier = AudioNotifier(
      playSoundscapeUseCase: PlaySoundscapeUseCase(repository),
      stopSoundscapeUseCase: StopSoundscapeUseCase(repository),
      setAudioVolumeUseCase: SetAudioVolumeUseCase(repository),
      repository: repository,
      sharedPreferences: prefs,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  group('AudioNotifier', () {
    test(
        'initial state defaults to None soundscape, 0.5 volume, and not playing',
        () {
      expect(notifier.activeSoundscape, equals(SoundscapeEntity.none));
      expect(notifier.activeSoundscapeId, equals('none'));
      expect(notifier.volume, equals(0.5));
      expect(notifier.isPlaying, isFalse);
      expect(notifier.isProUnlocked, isFalse);
      expect(notifier.errorMessage, isNull);
    });

    test('non-pro user cannot select pro soundscapes and error is reported',
        () async {
      await notifier.selectSoundscape('brown_noise');

      expect(notifier.activeSoundscape, equals(SoundscapeEntity.none));
      expect(notifier.isPlaying, isFalse);
      expect(
        notifier.errorMessage,
        equals('Unlock Lifetime Pro to access Brown Noise'),
      );

      await notifier.selectSoundscape('gamma_40hz');
      expect(notifier.activeSoundscape, equals(SoundscapeEntity.none));
      expect(
        notifier.errorMessage,
        equals('Unlock Lifetime Pro to access 40Hz Gamma'),
      );

      await notifier.selectSoundscape('rain');
      expect(notifier.activeSoundscape, equals(SoundscapeEntity.none));
      expect(
        notifier.errorMessage,
        equals('Unlock Lifetime Pro to access Rain on Canvas'),
      );
    });

    test(
        'selecting soundscape updates active state without premature autoplay when timer is not running',
        () async {
      notifier.setProUnlocked(true);

      await notifier.selectSoundscape('brown_noise');

      expect(notifier.activeSoundscape, equals(SoundscapeEntity.brownNoise));
      expect(notifier.activeSoundscapeId, equals('brown_noise'));
      expect(notifier.isPlaying, isFalse);
      expect(repository.playedAssets, isEmpty);
      expect(
        prefs.getString(AudioNotifier.selectedSoundscapePrefsKey),
        equals('brown_noise'),
      );

      await notifier.selectSoundscape('gamma_40hz');

      expect(notifier.activeSoundscape, equals(SoundscapeEntity.gamma40Hz));
      expect(notifier.isPlaying, isFalse);
      expect(
        prefs.getString(AudioNotifier.selectedSoundscapePrefsKey),
        equals('gamma_40hz'),
      );
    });

    test(
        'selecting soundscape starts playback immediately if timer is actively running',
        () async {
      final sessionRepo = _FakeSessionRepository();
      final timerNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepo),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
        notificationService: NotificationService(),
        prefs: prefs,
      );
      addTearDown(timerNotifier.dispose);

      notifier.setProUnlocked(true);
      notifier.attachTimerNotifier(timerNotifier);

      await timerNotifier.startFocusSession('Test running session');
      await Future<void>.delayed(Duration.zero);

      await notifier.selectSoundscape('brown_noise');

      expect(notifier.activeSoundscape, equals(SoundscapeEntity.brownNoise));
      expect(notifier.isPlaying, isTrue);
      expect(
        repository.playedAssets,
        equals(['assets/audio/brown_noise_loop.ogg']),
      );
    });

    test('volume slider dispatches clamped values to repository', () async {
      await notifier.setVolume(0.8);
      expect(notifier.volume, equals(0.8));
      expect(repository.volumeHistory.last, equals(0.8));
      expect(
        prefs.getDouble(AudioNotifier.audioVolumePrefsKey),
        equals(0.8),
      );

      await notifier.setVolume(1.75);
      expect(notifier.volume, equals(1.0));
      expect(repository.volumeHistory.last, equals(1.0));

      await notifier.setVolume(-0.4);
      expect(notifier.volume, equals(0.0));
      expect(repository.volumeHistory.last, equals(0.0));

      await notifier.setVolume(double.nan);
      expect(notifier.volume, equals(0.0));
    });

    test(
        'setVolume with persist false defers SharedPreferences write until persistVolume',
        () async {
      await notifier.setVolume(0.35, persist: false);
      expect(notifier.volume, equals(0.35));
      expect(repository.volumeHistory.last, equals(0.35));
      expect(prefs.getDouble(AudioNotifier.audioVolumePrefsKey), isNull);

      await notifier.persistVolume();
      expect(prefs.getDouble(AudioNotifier.audioVolumePrefsKey), equals(0.35));
    });

    test('selecting None stops player and resets playing flag', () async {
      notifier.setProUnlocked(true);
      await notifier.togglePreview('rain');
      expect(notifier.isPlaying, isTrue);
      expect(notifier.activeSoundscapeId, equals('rain'));

      await notifier.selectSoundscape('none');

      expect(notifier.activeSoundscape, equals(SoundscapeEntity.none));
      expect(notifier.activeSoundscapeId, equals('none'));
      expect(notifier.isPlaying, isFalse);
      expect(repository.stopCallCount, equals(1));
    });

    test(
        'guards against race condition when selecting None while playLoop is in flight',
        () async {
      notifier.setProUnlocked(true);
      final gate = Completer<void>();
      repository.playLoopGate = gate;

      final playFuture = notifier.togglePreview('brown_noise');
      final stopFuture = notifier.selectSoundscape('none');

      gate.complete();
      await Future.wait([playFuture, stopFuture]);

      expect(notifier.activeSoundscape, equals(SoundscapeEntity.none));
      expect(notifier.isPlaying, isFalse);
    });

    test(
        'togglePreview fails for free user on pro soundscape when active is none',
        () async {
      expect(notifier.isProUnlocked, isFalse);
      await notifier.togglePreview();

      expect(notifier.activeSoundscape, equals(SoundscapeEntity.none));
      expect(notifier.isPlaying, isFalse);
      expect(
        notifier.errorMessage,
        equals('Unlock Lifetime Pro to access Brown Noise'),
      );
    });

    test(
        'togglePreview selects Brown Noise when None is active and toggles playback for Pro user',
        () async {
      notifier.setProUnlocked(true);
      expect(notifier.activeSoundscape, equals(SoundscapeEntity.none));

      await notifier.togglePreview();
      expect(notifier.activeSoundscape, equals(SoundscapeEntity.brownNoise));
      expect(notifier.isPlaying, isTrue);

      await notifier.togglePreview();
      expect(notifier.isPlaying, isFalse);
      expect(repository.stopCallCount, equals(1));

      await notifier.togglePreview();
      expect(notifier.isPlaying, isTrue);
      expect(repository.playedAssets.length, equals(2));
    });

    test('records errorMessage and sets isPlaying false when playback fails',
        () async {
      notifier.setProUnlocked(true);
      repository.failureToReturn =
          const PlatformFailure('Audio hardware unavailable');

      await notifier.togglePreview('brown_noise');

      expect(notifier.activeSoundscape, equals(SoundscapeEntity.brownNoise));
      expect(notifier.isPlaying, isFalse);
      expect(notifier.errorMessage, equals('Audio hardware unavailable'));
    });

    test(
        'loads persisted soundscape, volume, and Pro status and syncs volume to repository',
        () async {
      SharedPreferences.setMockInitialValues({
        AudioNotifier.selectedSoundscapePrefsKey: 'rain',
        AudioNotifier.audioVolumePrefsKey: 0.75,
        AudioNotifier.proUnlockedPrefsKey: true,
      });
      final savedPrefs = await SharedPreferences.getInstance();
      final freshRepo = _FakeAudioRepository();

      final restoredNotifier = AudioNotifier(
        playSoundscapeUseCase: PlaySoundscapeUseCase(freshRepo),
        stopSoundscapeUseCase: StopSoundscapeUseCase(freshRepo),
        setAudioVolumeUseCase: SetAudioVolumeUseCase(freshRepo),
        repository: freshRepo,
        sharedPreferences: savedPrefs,
      );
      addTearDown(restoredNotifier.dispose);

      expect(restoredNotifier.activeSoundscape, equals(SoundscapeEntity.rain));
      expect(restoredNotifier.volume, equals(0.75));
      expect(restoredNotifier.isProUnlocked, isTrue);
      expect(freshRepo.volumeHistory, contains(0.75));
    });

    test('synchronizes playback with attached TimerNotifier lifecycle',
        () async {
      final sessionRepo = _FakeSessionRepository();
      final timerNotifier = TimerNotifier(
        startSessionUseCase: StartSessionUseCase(sessionRepo),
        completeSessionUseCase: CompleteSessionUseCase(sessionRepo),
        cancelSessionUseCase: CancelSessionUseCase(sessionRepo),
        notificationService: NotificationService(),
        prefs: prefs,
      );
      addTearDown(timerNotifier.dispose);

      notifier.setProUnlocked(true);
      notifier.attachTimerNotifier(timerNotifier);
      await notifier.selectSoundscape('brown_noise');
      expect(notifier.isPlaying, isFalse);

      await timerNotifier.startFocusSession('Write audio tests');
      await Future<void>.delayed(Duration.zero);
      expect(notifier.isPlaying, isTrue);

      timerNotifier.pause();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.isPlaying, isFalse);

      timerNotifier.resume();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.isPlaying, isTrue);

      await timerNotifier.cancelSession();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.isPlaying, isFalse);
    });
  });
}
