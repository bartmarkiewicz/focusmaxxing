import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';
import 'package:focusmaxxing/features/audio/domain/repositories/i_audio_repository.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/play_chime_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/play_soundscape_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/set_audio_volume_usecase.dart';
import 'package:focusmaxxing/features/audio/domain/usecases/stop_soundscape_usecase.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State manager for ambient soundscapes, volume control, and live previewing.
class AudioNotifier extends ChangeNotifier {
  static const double defaultVolume = 0.5;
  static const String selectedSoundscapePrefsKey = 'selected_soundscape_id';
  static const String audioVolumePrefsKey = 'ambient_audio_volume';
  static const String proUnlockedPrefsKey = 'is_lifetime_pro';
  static const String billingProUnlockedPrefsKey = 'is_pro_unlocked';

  final PlaySoundscapeUseCase playSoundscapeUseCase;
  final StopSoundscapeUseCase stopSoundscapeUseCase;
  final SetAudioVolumeUseCase setAudioVolumeUseCase;
  final PlayChimeUseCase? playChimeUseCase;
  final IAudioRepository? repository;
  final SharedPreferences? sharedPreferences;

  AudioNotifier({
    required this.playSoundscapeUseCase,
    required this.stopSoundscapeUseCase,
    required this.setAudioVolumeUseCase,
    this.playChimeUseCase,
    this.repository,
    this.sharedPreferences,
    bool isProUnlocked = false,
  }) {
    _isProUnlocked = isProUnlocked;
    _loadSavedPreferencesSync();
  }

  SoundscapeEntity _activeSoundscape = SoundscapeEntity.none;
  double _volume = defaultVolume;
  bool _isPlaying = false;
  bool _isProUnlocked = false;
  String? _errorMessage;
  bool _isDisposed = false;
  int _operationToken = 0;

  TimerNotifier? _attachedTimerNotifier;
  TimerStatus? _lastTimerStatus;

  SoundscapeEntity get activeSoundscape => _activeSoundscape;
  String get activeSoundscapeId => _activeSoundscape.id;
  List<SoundscapeEntity> get soundscapes => SoundscapeEntity.presets;
  double get volume => _volume;
  bool get isPlaying => _isPlaying;
  bool get isProUnlocked => _isProUnlocked;
  String? get errorMessage => _errorMessage;

  void _loadSavedPreferencesSync() {
    final prefs = sharedPreferences;
    if (prefs == null) return;

    final savedId = prefs.getString(selectedSoundscapePrefsKey);
    if (savedId != null && savedId.isNotEmpty) {
      _activeSoundscape = SoundscapeEntity.fromId(savedId);
    }

    final savedVolume = prefs.getDouble(audioVolumePrefsKey);
    if (savedVolume != null && !savedVolume.isNaN) {
      _volume = savedVolume.clamp(0.0, 1.0);
      unawaited(setAudioVolumeUseCase(_volume));
    }

    final proLegacy = prefs.getBool(proUnlockedPrefsKey);
    final proBilling = prefs.getBool(billingProUnlockedPrefsKey);
    if (proLegacy == true || proBilling == true) {
      _isProUnlocked = true;
    }
  }

  Future<SharedPreferences?> _resolvePrefs() async {
    if (sharedPreferences != null) return sharedPreferences;
    try {
      return await SharedPreferences.getInstance();
    } on Exception catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _operationToken++;
    _attachedTimerNotifier?.removeListener(_onTimerChanged);
    final repo = repository;
    if (repo != null) {
      unawaited(repo.dispose());
    }
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void attachTimerNotifier(TimerNotifier timerNotifier) {
    if (identical(_attachedTimerNotifier, timerNotifier)) return;
    _attachedTimerNotifier?.removeListener(_onTimerChanged);
    _attachedTimerNotifier = timerNotifier;
    _lastTimerStatus = timerNotifier.status;
    timerNotifier.addListener(_onTimerChanged);
  }

  void _onTimerChanged() {
    final timer = _attachedTimerNotifier;
    if (timer == null) return;

    final currentStatus = timer.status;
    final previousStatus = _lastTimerStatus;
    if (currentStatus == previousStatus) return;
    _lastTimerStatus = currentStatus;

    unawaited(_syncWithTimerStatus(currentStatus));
  }

  Future<void> _syncWithTimerStatus(TimerStatus status) async {
    switch (status) {
      case TimerStatus.running:
        if (!_activeSoundscape.isNone && !_isPlaying) {
          if (_activeSoundscape.isProOnly && !_isProUnlocked) {
            _errorMessage =
                'Unlock Lifetime Pro to access ${_activeSoundscape.title}';
            notifyListeners();
            break;
          }
          final token = ++_operationToken;
          await _startActiveSoundscape(token);
        }
      case TimerStatus.paused:
      case TimerStatus.idle:
        if (_isPlaying) {
          await stop();
        }
      case TimerStatus.completed:
      case TimerStatus.breakCompleted:
        if (_isPlaying) {
          await stop();
        }
        final repo = repository;
        if (repo != null) {
          final chimeResult = await repo.playChime();
          chimeResult.fold(
            (failure) {
              _errorMessage = failure.message;
              notifyListeners();
            },
            (_) {},
          );
        }
      case TimerStatus.breakRunning:
        break;
    }
  }

  /// Selects a soundscape by ID, starting loop playback immediately or stopping
  /// the player when `'none'` is selected.
  Future<void> selectSoundscape(String soundscapeId) async {
    final target = SoundscapeEntity.fromId(soundscapeId.trim().toLowerCase());
    await selectSoundscapeEntity(target);
  }

  /// Selects a [SoundscapeEntity], starting loop playback if timer is running, or stopping when `none`.
  Future<void> selectSoundscapeEntity(SoundscapeEntity soundscape) async {
    if (soundscape.isProOnly && !_isProUnlocked) {
      _errorMessage = 'Unlock Lifetime Pro to access ${soundscape.title}';
      notifyListeners();
      return;
    }

    final token = ++_operationToken;
    _errorMessage = null;
    _activeSoundscape = soundscape;

    final prefs = await _resolvePrefs();
    if (prefs != null) {
      await prefs.setString(selectedSoundscapePrefsKey, soundscape.id);
    }

    if (_isDisposed || token != _operationToken) return;

    if (soundscape.isNone) {
      final result = await stopSoundscapeUseCase();
      if (_isDisposed || token != _operationToken) return;
      _isPlaying = false;
      result.fold(
        (failure) => _errorMessage = failure.message,
        (_) {},
      );
      notifyListeners();
      return;
    }

    if (_attachedTimerNotifier?.status != TimerStatus.running) {
      if (_isPlaying) {
        await stop();
      } else {
        notifyListeners();
      }
      return;
    }

    await _startActiveSoundscape(token);
  }

  Future<void> _startActiveSoundscape(int token) async {
    final targetSoundscape = _activeSoundscape;
    if (targetSoundscape.isNone) return;
    if (targetSoundscape.isProOnly && !_isProUnlocked) {
      _errorMessage = 'Unlock Lifetime Pro to access ${targetSoundscape.title}';
      notifyListeners();
      return;
    }

    await setAudioVolumeUseCase(_volume);
    if (_isDisposed || token != _operationToken || _activeSoundscape.isNone) {
      return;
    }

    final result = await playSoundscapeUseCase(targetSoundscape.assetPath);
    if (_isDisposed || token != _operationToken || _activeSoundscape.isNone) {
      if (_activeSoundscape.isNone) {
        await stopSoundscapeUseCase();
      }
      return;
    }

    result.fold(
      (failure) {
        _isPlaying = false;
        _errorMessage = failure.message;
      },
      (_) {
        _isPlaying = true;
      },
    );
    notifyListeners();
  }

  /// Updates the volume slider value (clamped to `[0.0, 1.0]`) and dispatches
  /// it to the repository. When [persist] is false (e.g., during continuous
  /// slider drag), disk writes are deferred until [persistVolume] is called.
  Future<void> setVolume(double newVolume, {bool persist = true}) async {
    if (newVolume.isNaN) return;
    final clamped = newVolume.clamp(0.0, 1.0);
    _volume = clamped;
    _errorMessage = null;
    notifyListeners();

    final result = await setAudioVolumeUseCase(clamped);
    if (_isDisposed) return;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (_) {},
    );

    if (persist) {
      await persistVolume();
    }
  }

  /// Persists the current [_volume] to [SharedPreferences].
  Future<void> persistVolume() async {
    final prefs = await _resolvePrefs();
    if (prefs != null && !_isDisposed) {
      await prefs.setDouble(audioVolumePrefsKey, _volume);
    }
  }

  /// Toggles live preview playback for the currently selected soundscape.
  /// If `'none'` is currently selected, selects and previews [SoundscapeEntity.brownNoise].
  Future<void> togglePreview([String? soundscapeId]) async {
    if (soundscapeId != null && soundscapeId != _activeSoundscape.id) {
      final target = SoundscapeEntity.fromId(soundscapeId.trim().toLowerCase());
      if (target.isProOnly && !_isProUnlocked) {
        _errorMessage = 'Unlock Lifetime Pro to access ${target.title}';
        notifyListeners();
        return;
      }
      final token = ++_operationToken;
      _errorMessage = null;
      _activeSoundscape = target;
      final prefs = await _resolvePrefs();
      if (prefs != null) {
        await prefs.setString(selectedSoundscapePrefsKey, target.id);
      }
      if (_isDisposed || token != _operationToken) return;
      if (target.isNone) {
        await stop();
        return;
      }
      await _startActiveSoundscape(token);
      return;
    }

    if (_activeSoundscape.isNone) {
      if (_isPlaying) {
        await stop();
      } else {
        if (SoundscapeEntity.brownNoise.isProOnly && !_isProUnlocked) {
          _errorMessage =
              'Unlock Lifetime Pro to access ${SoundscapeEntity.brownNoise.title}';
          notifyListeners();
          return;
        }
        final token = ++_operationToken;
        _errorMessage = null;
        _activeSoundscape = SoundscapeEntity.brownNoise;
        final prefs = await _resolvePrefs();
        if (prefs != null) {
          await prefs.setString(
            selectedSoundscapePrefsKey,
            SoundscapeEntity.brownNoise.id,
          );
        }
        if (_isDisposed || token != _operationToken) return;
        await _startActiveSoundscape(token);
      }
      return;
    }

    if (_isPlaying) {
      await stop();
    } else {
      if (_activeSoundscape.isProOnly && !_isProUnlocked) {
        _errorMessage =
            'Unlock Lifetime Pro to access ${_activeSoundscape.title}';
        notifyListeners();
        return;
      }
      final token = ++_operationToken;
      await _startActiveSoundscape(token);
    }
  }

  /// Stops active soundscape playback without clearing the selected soundscape.
  Future<void> stop() async {
    final token = ++_operationToken;
    _errorMessage = null;
    final result = await stopSoundscapeUseCase();
    if (_isDisposed || token != _operationToken) return;
    _isPlaying = false;
    result.fold(
      (failure) => _errorMessage = failure.message,
      (_) {},
    );
    notifyListeners();
  }

  /// Updates Lifetime Pro unlock status and notifies listeners.
  void setProUnlocked(bool unlocked) {
    if (_isProUnlocked == unlocked) return;
    _isProUnlocked = unlocked;
    notifyListeners();
  }

  /// Clears the active [_errorMessage] and notifies listeners.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets an error message indicating that Lifetime Pro is required for [soundscape].
  void triggerProRequirement(SoundscapeEntity soundscape) {
    _errorMessage = 'Unlock Lifetime Pro to access ${soundscape.title}';
    notifyListeners();
  }

  /// Plays the completion chime sound effect.
  Future<void> playChime() async {
    final useCase = playChimeUseCase ??
        (repository != null ? PlayChimeUseCase(repository!) : null);
    if (useCase == null) return;

    final chimeResult = await useCase();
    if (_isDisposed) return;

    chimeResult.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (_) {},
    );
  }
}
