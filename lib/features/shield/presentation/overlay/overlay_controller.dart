import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Tracks the urge-surfing box breathing workflow stage on the hard-lock overlay.
enum OverlayBreatherStage { none, breathing, decision }

/// Presentation controller managing the state, IPC synchronization, and
/// countdown timer for the Hard-Lock Overlay window.
class OverlayController extends ChangeNotifier {
  static const MethodChannel _overlayBridgeChannel =
      MethodChannel('com.focusmaxxing/overlay_bridge');
  static Stream<dynamic>? _sharedOverlayBroadcastStream;

  static Stream<dynamic> _resolveDefaultOverlayStream() {
    return _sharedOverlayBroadcastStream ??=
        FlutterOverlayWindow.overlayListener.asBroadcastStream();
  }

  final Stream<dynamic>? dataStream;
  final Future<void> Function()? onClose;
  final Future<void> Function()? onCancelSession;
  final Future<bool> Function()? onEmergencyPass;

  String _taskGoal;
  int _remainingSeconds;
  bool _isBreakMode;
  bool _isMaximumFocus;
  bool _isPaused = false;
  bool _isScheduled;
  String _scheduleTimeRange;
  int _targetEndTimeEpochMs = 0;
  bool _emergencyPassAvailable;
  OverlayBreatherStage _breatherStage = OverlayBreatherStage.none;
  bool _isDisposed = false;

  StreamSubscription<dynamic>? _subscription;
  Timer? _localCountdownTimer;

  OverlayController({
    this.dataStream,
    this.onClose,
    this.onCancelSession,
    this.onEmergencyPass,
    String initialGoal = 'Deep Work',
    int initialRemainingSeconds = 1500,
    bool initialIsBreak = false,
    bool initialIsMaximumFocus = false,
    bool initialIsScheduled = false,
    String initialScheduleTimeRange = '',
    bool initialEmergencyPassAvailable = true,
  })  : _taskGoal = initialGoal,
        _remainingSeconds = initialRemainingSeconds,
        _isBreakMode = initialIsBreak,
        _isMaximumFocus = initialIsMaximumFocus,
        _isScheduled = initialIsScheduled,
        _scheduleTimeRange = initialScheduleTimeRange,
        _emergencyPassAvailable = initialEmergencyPassAvailable {
    final stream = dataStream ?? _resolveDefaultOverlayStream();
    _subscription = stream.listen(
      handleIncomingData,
      onError: (Object _, [StackTrace? __]) {},
    );

    if (dataStream == null) {
      _overlayBridgeChannel.setMethodCallHandler(_handleBridgeMethodCall);
      unawaited(_fetchInitialOverlayState());
    }
  }

  String get taskGoal => _taskGoal;
  int get remainingSeconds => _remainingSeconds;
  bool get isBreakMode => _isBreakMode;
  bool get isMaximumFocus => _isMaximumFocus;
  bool get isPaused => _isPaused;
  bool get isScheduled => _isScheduled;
  String get scheduleTimeRange => _scheduleTimeRange;
  bool get emergencyPassAvailable => _emergencyPassAvailable;
  OverlayBreatherStage get breatherStage => _breatherStage;

  int get clampedSeconds => _remainingSeconds > 0 ? _remainingSeconds : 0;

  bool get isMaxFocusActive =>
      _isMaximumFocus && !_isBreakMode && !_isScheduled && clampedSeconds > 0;

  bool get isSessionFinished =>
      clampedSeconds <= 0 && !_isBreakMode && !_isScheduled;

  String get timerDisplay {
    if (_isScheduled && _scheduleTimeRange.isNotEmpty) {
      return _scheduleTimeRange;
    }
    final minutes = (clampedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (clampedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get roastAffirmation {
    if (isSessionFinished) {
      return 'Session complete.';
    }
    if (_isBreakMode) {
      return 'Feeds remain blocked during your break.';
    }
    if (_isScheduled) {
      return 'Scheduled focus shield is active.';
    }
    return 'App is blocked during active focus.';
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void _startOrStopLocalTimer() {
    if (dataStream != null) return;

    if (_isPaused ||
        _isScheduled ||
        _scheduleTimeRange.isNotEmpty ||
        _remainingSeconds <= 0) {
      _localCountdownTimer?.cancel();
      _localCountdownTimer = null;
      return;
    }

    if (_localCountdownTimer != null && _localCountdownTimer!.isActive) {
      return;
    }

    _localCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (_isDisposed ||
            _isPaused ||
            _isScheduled ||
            _scheduleTimeRange.isNotEmpty) {
          return;
        }
        if (_targetEndTimeEpochMs > 0) {
          final remainingMs =
              _targetEndTimeEpochMs - DateTime.now().millisecondsSinceEpoch;
          final nextRemaining =
              remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();
          _remainingSeconds = nextRemaining;
          notifyListeners();
        } else if (_remainingSeconds > 0) {
          _remainingSeconds--;
          notifyListeners();
        }

        if (_remainingSeconds <= 0) {
          _localCountdownTimer?.cancel();
          _localCountdownTimer = null;
          if (!_isBreakMode && !_isScheduled && _scheduleTimeRange.isEmpty) {
            _onSessionCountdownComplete();
          }
        }
      },
    );
  }

  void _onSessionCountdownComplete() {
    if (_isScheduled || _scheduleTimeRange.isNotEmpty || _isBreakMode) {
      return;
    }
    _localCountdownTimer?.cancel();
    _localCountdownTimer = null;
    _targetEndTimeEpochMs = 0;
    if (!_isDisposed) {
      _remainingSeconds = 0;
      _isMaximumFocus = false;
      _breatherStage = OverlayBreatherStage.none;
      notifyListeners();
    }
    unawaited(handleReturn());
  }

  Future<dynamic> _handleBridgeMethodCall(MethodCall call) async {
    if (call.method == 'updateOverlayState') {
      handleIncomingData(call.arguments);
      return true;
    }
    return null;
  }

  Future<void> _fetchInitialOverlayState() async {
    try {
      final state = await _overlayBridgeChannel
          .invokeMapMethod<String, dynamic>('getInitialOverlayState');
      if (state != null) {
        handleIncomingData(state);
      } else {
        _startOrStopLocalTimer();
      }
    } catch (_) {
      _startOrStopLocalTimer();
    }
  }

  void handleIncomingData(dynamic data) {
    if (_isDisposed || data == null) return;

    Map<String, dynamic>? payload;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        } else if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return;
      }
    } else if (data is Map<String, dynamic>) {
      payload = data;
    } else if (data is Map) {
      payload = Map<String, dynamic>.from(data);
    }

    if (payload == null) return;

    final goal = payload['goal'] ?? payload['taskGoal'];
    if (goal is String && goal.isNotEmpty) {
      _taskGoal = goal;
    }

    final isPaused = payload['isPaused'];
    if (isPaused is bool) {
      _isPaused = isPaused;
    }

    final isScheduled = payload['isScheduled'];
    if (isScheduled is bool) {
      _isScheduled = isScheduled;
    }

    final scheduleRange = payload['scheduleTimeRange'];
    if (scheduleRange is String) {
      _scheduleTimeRange = scheduleRange;
    }

    final targetEnd = payload['targetEndTimeEpochMs'];
    if (targetEnd is int) {
      _targetEndTimeEpochMs = _isPaused ? 0 : targetEnd;
    } else if (targetEnd is num) {
      _targetEndTimeEpochMs = _isPaused ? 0 : targetEnd.toInt();
    } else if (payload.containsKey('targetEndTimeEpochMs') &&
        targetEnd == null) {
      _targetEndTimeEpochMs = 0;
    }

    final seconds = payload['remainingSeconds'] ?? payload['remaining'];
    if (seconds is int) {
      _remainingSeconds = seconds;
    } else if (seconds is num) {
      _remainingSeconds = seconds.toInt();
    } else if (!_isPaused && _targetEndTimeEpochMs > 0) {
      final remainingMs =
          _targetEndTimeEpochMs - DateTime.now().millisecondsSinceEpoch;
      _remainingSeconds = remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();
    }

    final isBreak = payload['isBreak'] ?? payload['isBreakMode'];
    if (isBreak is bool) {
      _isBreakMode = isBreak;
    }

    final isMaxFocus = payload['isMaximumFocus'];
    if (isMaxFocus is bool) {
      _isMaximumFocus = isMaxFocus;
    }

    final passAvailable = payload['emergencyPassAvailable'];
    if (passAvailable is bool) {
      _emergencyPassAvailable = passAvailable;
    }

    notifyListeners();

    if (_remainingSeconds <= 0 &&
        !_isBreakMode &&
        !_isScheduled &&
        dataStream == null) {
      _onSessionCountdownComplete();
    } else {
      _startOrStopLocalTimer();
    }
  }

  Future<void> handleReturn() async {
    if (_breatherStage != OverlayBreatherStage.none) {
      _breatherStage = OverlayBreatherStage.none;
      notifyListeners();
    }
    if (onClose != null) {
      await onClose!();
    } else {
      var bridgeHandled = false;
      try {
        final result = await _overlayBridgeChannel
            .invokeMethod<bool>('returnToFocusmaxxing');
        bridgeHandled = result ?? false;
      } catch (_) {}

      if (!bridgeHandled) {
        try {
          await FlutterOverlayWindow.closeOverlay();
        } catch (_) {}
      }
    }
  }

  Future<void> handleCancelSession() async {
    unawaited(HapticFeedback.heavyImpact());
    if (onCancelSession != null) {
      await onCancelSession!();
    } else {
      var bridgeHandled = false;
      try {
        final result = await _overlayBridgeChannel
            .invokeMethod<bool>('cancelSessionFromOverlay');
        bridgeHandled = result ?? false;
      } catch (_) {}

      if (!bridgeHandled) {
        try {
          await FlutterOverlayWindow.shareData(
            jsonEncode({'action': 'cancelSessionFromOverlay'}),
          );
        } catch (_) {}
        try {
          await FlutterOverlayWindow.closeOverlay();
        } catch (_) {}
      }
    }
  }

  void startBreather() {
    unawaited(HapticFeedback.lightImpact());
    _breatherStage = OverlayBreatherStage.breathing;
    notifyListeners();
  }

  void cancelBreather() {
    if (_isDisposed) return;
    unawaited(HapticFeedback.lightImpact());
    _breatherStage = OverlayBreatherStage.none;
    notifyListeners();
  }

  void completeBreather() {
    if (_isDisposed) return;
    _breatherStage = OverlayBreatherStage.decision;
    notifyListeners();
  }

  Future<void> handleEmergencyPass() async {
    var granted = false;
    if (onEmergencyPass != null) {
      granted = await onEmergencyPass!();
    } else {
      try {
        granted = await _overlayBridgeChannel
                .invokeMethod<bool>('grantEmergencyPass') ??
            false;
      } catch (_) {
        granted = false;
      }
    }
    if (_isDisposed) return;
    if (granted) {
      _breatherStage = OverlayBreatherStage.none;
    } else {
      _emergencyPassAvailable = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _localCountdownTimer?.cancel();
    if (dataStream == null) {
      _overlayBridgeChannel.setMethodCallHandler(null);
    }
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
