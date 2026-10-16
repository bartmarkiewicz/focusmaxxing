import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/errors/exceptions.dart';
import 'package:focusmaxxing/core/errors/failures.dart';
import 'package:focusmaxxing/features/audio/data/datasources/audio_player_engine.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';
import 'package:just_audio/just_audio.dart';

export 'package:focusmaxxing/features/audio/data/datasources/audio_player_engine.dart'
    show IAudioPlayerEngine, JustAudioPlayerEngine;

/// Concrete implementation of [IAudioRepository] configuring gapless looping
/// (`LoopMode.one`) and non-interruptive background audio mixing.
class AudioRepositoryImpl implements IAudioRepository {
  final IAudioPlayerEngine _engine;
  bool _isSessionConfigured = false;
  double _currentVolume = 0.5;
  String? _loadedAssetPath;

  AudioRepositoryImpl({
    IAudioPlayerEngine? engine,
    AudioPlayer? player,
  }) : _engine = engine ?? JustAudioPlayerEngine(loopPlayerInstance: player);

  Future<void> _ensureSessionConfigured() async {
    if (_isSessionConfigured) return;
    await _engine.configureAudioSession();
    _isSessionConfigured = true;
  }

  @override
  Future<Either<Failure, void>> playLoop(String assetPath) async {
    final trimmedPath = assetPath.trim();
    if (trimmedPath.isEmpty) {
      return const Left(ValidationFailure('Audio asset path cannot be empty'));
    }

    try {
      await _ensureSessionConfigured();
      if (_loadedAssetPath != trimmedPath) {
        await _engine.setAsset(trimmedPath);
        _loadedAssetPath = trimmedPath;
      }
      await _engine.setLoopMode(LoopMode.one);
      await _engine.setVolume(_currentVolume);
      await _engine.play();
      return const Right(null);
    } on PlayerException catch (e) {
      return Left(
        PlatformFailure('Audio player error (${e.code}): ${e.message}'),
      );
    } on PlayerInterruptedException catch (e) {
      return Left(
        PlatformFailure('Audio playback interrupted: ${e.message}'),
      );
    } on PlatformException catch (e) {
      return Left(
        PlatformFailure('Platform audio error: ${e.message ?? e.code}'),
      );
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } on Exception catch (e) {
      return Left(PlatformFailure('Failed to play ambient loop: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> stopLoop() async {
    try {
      await _engine.stop();
      return const Right(null);
    } on PlatformException catch (e) {
      return Left(
        PlatformFailure(
          'Failed to stop audio playback: ${e.message ?? e.code}',
        ),
      );
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } on Exception catch (e) {
      return Left(PlatformFailure('Failed to stop ambient loop: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> setVolume(double volume) async {
    if (volume.isNaN) {
      return const Left(ValidationFailure('Volume cannot be NaN'));
    }
    final clamped = volume.clamp(0.0, 1.0);
    _currentVolume = clamped;

    try {
      await _engine.setVolume(clamped);
      return const Right(null);
    } on PlatformException catch (e) {
      return Left(
        PlatformFailure('Failed to set audio volume: ${e.message ?? e.code}'),
      );
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } on Exception catch (e) {
      return Left(PlatformFailure('Failed to set audio volume: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> preloadAssets(List<String> assetPaths) async {
    try {
      await _ensureSessionConfigured();
      final validPaths = assetPaths
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty)
          .toList(growable: false);
      if (validPaths.isNotEmpty) {
        for (final path in validPaths) {
          await _engine.setAsset(path);
          _loadedAssetPath = path;
        }
        await _engine.setLoopMode(LoopMode.one);
      }
      return const Right(null);
    } on PlayerException catch (e) {
      return Left(
        PlatformFailure(
          'Failed to preload audio asset (${e.code}): ${e.message}',
        ),
      );
    } on PlatformException catch (e) {
      return Left(
        PlatformFailure(
          'Failed to preload audio assets: ${e.message ?? e.code}',
        ),
      );
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } on Exception catch (e) {
      return Left(PlatformFailure('Failed to preload audio assets: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> playChime({
    String assetPath = SoundscapeEntity.chimeCompleteAssetPath,
  }) async {
    final trimmedPath = assetPath.trim();
    if (trimmedPath.isEmpty) {
      return const Left(ValidationFailure('Chime asset path cannot be empty'));
    }

    try {
      await _ensureSessionConfigured();
      await _engine.playOneShotAsset(trimmedPath, volume: _currentVolume);
      return const Right(null);
    } on PlayerException catch (e) {
      return Left(
        PlatformFailure(
          'Failed to play completion chime (${e.code}): ${e.message}',
        ),
      );
    } on PlatformException catch (e) {
      return Left(
        PlatformFailure(
          'Failed to play completion chime: ${e.message ?? e.code}',
        ),
      );
    } on PlatformBridgeException catch (e) {
      return Left(PlatformFailure(e.message));
    } on Exception catch (e) {
      return Left(PlatformFailure('Failed to play completion chime: $e'));
    }
  }

  @override
  Future<void> dispose() async {
    _isSessionConfigured = false;
    _loadedAssetPath = null;
    await _engine.dispose();
  }
}
