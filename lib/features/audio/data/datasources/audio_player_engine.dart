import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Abstraction over the underlying audio player and session configuration
/// to isolate platform plugin calls and enable deterministic unit testing.
abstract interface class IAudioPlayerEngine {
  Future<void> configureAudioSession();

  Future<void> setAsset(String assetPath);

  Future<void> setLoopMode(LoopMode loopMode);

  Future<void> play();

  Future<void> stop();

  Future<void> setVolume(double volume);

  Future<void> playOneShotAsset(String assetPath, {double volume = 1.0});

  Future<void> dispose();
}

/// Default production engine backed by `just_audio` and `audio_session`.
class JustAudioPlayerEngine implements IAudioPlayerEngine {
  AudioPlayer? _loopPlayer;
  AudioPlayer? _chimePlayer;
  bool _isDisposed = false;

  JustAudioPlayerEngine({
    AudioPlayer? loopPlayerInstance,
    AudioPlayer? chimePlayerInstance,
  })  : _loopPlayer = loopPlayerInstance,
        _chimePlayer = chimePlayerInstance;

  AudioPlayer get _resolvedLoopPlayer => _loopPlayer ??= AudioPlayer(
        handleAudioSessionActivation: false,
      );
  AudioPlayer get _resolvedChimePlayer => _chimePlayer ??= AudioPlayer(
        handleAudioSessionActivation: false,
      );

  @override
  Future<void> configureAudioSession() async {
    if (_isDisposed) return;
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidWillPauseWhenDucked: false,
      ),
    );
  }

  @override
  Future<void> setAsset(String assetPath) async {
    if (_isDisposed) return;
    await _resolvedLoopPlayer.setAsset(assetPath);
  }

  @override
  Future<void> setLoopMode(LoopMode loopMode) async {
    if (_isDisposed) return;
    await _resolvedLoopPlayer.setLoopMode(loopMode);
  }

  @override
  Future<void> play() {
    if (_isDisposed) return Future<void>.value();
    // In just_audio, play() returns a Future that stays pending for the entire
    // duration of playback (forever when LoopMode.one is active) and may reject
    // with PlayerInterruptedException when stopped or switched. Suppressing async
    // completion errors on the detached play future prevents uncaught Zone errors.
    unawaited(_resolvedLoopPlayer.play().catchError((Object _) {}));
    return Future<void>.value();
  }

  @override
  Future<void> stop() async {
    if (_isDisposed) return;
    if (_loopPlayer != null) {
      await _loopPlayer!.stop();
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    await _resolvedLoopPlayer.setVolume(volume);
  }

  @override
  Future<void> playOneShotAsset(String assetPath, {double volume = 1.0}) async {
    if (_isDisposed) return;
    final chime = _resolvedChimePlayer;
    await chime.setLoopMode(LoopMode.off);
    await chime.setVolume(volume);
    await chime.setAsset(assetPath);
    unawaited(chime.play().catchError((Object _) {}));
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    final loop = _loopPlayer;
    final chime = _chimePlayer;
    _loopPlayer = null;
    _chimePlayer = null;
    if (loop != null) {
      await loop.dispose();
    }
    if (chime != null) {
      await chime.dispose();
    }
  }
}
