import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/box_breathing_exercise.dart';

enum _BreatherStage { none, breathing, decision }

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {},
        child: const HardLockOverlayWidget(),
      ),
    ),
  );
}

class HardLockOverlayWidget extends StatefulWidget {
  const HardLockOverlayWidget({
    super.key,
    this.dataStream,
    this.onClose,
    this.onCancelSession,
    this.onEmergencyPass,
    this.initialGoal = 'Deep Work',
    this.initialRemainingSeconds = 1500,
    this.initialIsBreak = false,
    this.initialIsMaximumFocus = false,
    this.initialIsScheduled = false,
    this.initialScheduleTimeRange = '',
    this.initialEmergencyPassAvailable = true,
    this.breatherDuration = const Duration(seconds: 60),
  });

  final Stream<dynamic>? dataStream;
  final Future<void> Function()? onClose;
  final Future<void> Function()? onCancelSession;

  /// Requests a temporary shield pass; resolves to whether it was granted.
  final Future<bool> Function()? onEmergencyPass;
  final String initialGoal;
  final int initialRemainingSeconds;
  final bool initialIsBreak;
  final bool initialIsMaximumFocus;
  final bool initialIsScheduled;
  final String initialScheduleTimeRange;
  final bool initialEmergencyPassAvailable;
  final Duration breatherDuration;

  @override
  State<HardLockOverlayWidget> createState() => _HardLockOverlayWidgetState();
}

class _HardLockOverlayWidgetState extends State<HardLockOverlayWidget>
    with SingleTickerProviderStateMixin {
  static const Color _surfaceColor = Color(0xFF090A0D);
  static const Color _alertColor = Color(0xFFFF3B30);
  static const Color _subtextColor = Color(0xFF8B92A4);
  static const Color _actionGreen = Color(0xFF00E676);
  static const MethodChannel _overlayBridgeChannel =
      MethodChannel('com.focusmaxxing/overlay_bridge');
  static Stream<dynamic>? _sharedOverlayBroadcastStream;

  static Stream<dynamic> _resolveDefaultOverlayStream() {
    return _sharedOverlayBroadcastStream ??=
        FlutterOverlayWindow.overlayListener.asBroadcastStream();
  }

  late String _taskGoal;
  late int _remainingSeconds;
  late bool _isBreakMode;
  late bool _isMaximumFocus;
  bool _isPaused = false;
  bool _isScheduled = false;
  String _scheduleTimeRange = '';
  int _targetEndTimeEpochMs = 0;
  late bool _emergencyPassAvailable;
  _BreatherStage _breatherStage = _BreatherStage.none;
  StreamSubscription<dynamic>? _subscription;
  Timer? _localCountdownTimer;
  late final AnimationController _holdCancelController;

  @override
  void initState() {
    super.initState();
    _taskGoal = widget.initialGoal;
    _remainingSeconds = widget.initialRemainingSeconds;
    _isBreakMode = widget.initialIsBreak;
    _isMaximumFocus = widget.initialIsMaximumFocus;
    _isScheduled = widget.initialIsScheduled;
    _scheduleTimeRange = widget.initialScheduleTimeRange;
    _emergencyPassAvailable = widget.initialEmergencyPassAvailable;

    _holdCancelController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _holdCancelController.reset();
          unawaited(_handleCancelSession());
        }
      });

    final stream = widget.dataStream ?? _resolveDefaultOverlayStream();
    _subscription = stream.listen(
      _handleIncomingData,
      onError: (Object _, [StackTrace? __]) {},
    );

    if (widget.dataStream == null) {
      _overlayBridgeChannel.setMethodCallHandler(_handleBridgeMethodCall);
      unawaited(_fetchInitialOverlayState());
    }
  }

  void _startOrStopLocalTimer() {
    if (widget.dataStream != null) return;

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
        if (!mounted || _isPaused || _isScheduled || _scheduleTimeRange.isNotEmpty) {
          return;
        }
        if (_targetEndTimeEpochMs > 0) {
          final remainingMs =
              _targetEndTimeEpochMs - DateTime.now().millisecondsSinceEpoch;
          final nextRemaining =
              remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();
          setState(() {
            _remainingSeconds = nextRemaining;
          });
        } else if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
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
    if (mounted) {
      setState(() {
        _remainingSeconds = 0;
        _isMaximumFocus = false;
        _breatherStage = _BreatherStage.none;
      });
    }
    unawaited(_handleReturn());
  }

  Future<dynamic> _handleBridgeMethodCall(MethodCall call) async {
    if (call.method == 'updateOverlayState') {
      _handleIncomingData(call.arguments);
      return true;
    }
    return null;
  }

  Future<void> _fetchInitialOverlayState() async {
    try {
      final state = await _overlayBridgeChannel
          .invokeMapMethod<String, dynamic>('getInitialOverlayState');
      if (state != null) {
        _handleIncomingData(state);
      } else {
        _startOrStopLocalTimer();
      }
    } catch (_) {
      _startOrStopLocalTimer();
    }
  }

  void _handleIncomingData(dynamic data) {
    if (!mounted || data == null) return;

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

    setState(() {
      final goal = payload?['goal'] ?? payload?['taskGoal'];
      if (goal is String && goal.isNotEmpty) {
        _taskGoal = goal;
      }

      final isPaused = payload?['isPaused'];
      if (isPaused is bool) {
        _isPaused = isPaused;
      }

      final isScheduled = payload?['isScheduled'];
      if (isScheduled is bool) {
        _isScheduled = isScheduled;
      }

      final scheduleRange = payload?['scheduleTimeRange'];
      if (scheduleRange is String) {
        _scheduleTimeRange = scheduleRange;
      }

      final targetEnd = payload?['targetEndTimeEpochMs'];
      if (targetEnd is int) {
        _targetEndTimeEpochMs = _isPaused ? 0 : targetEnd;
      } else if (targetEnd is num) {
        _targetEndTimeEpochMs = _isPaused ? 0 : targetEnd.toInt();
      } else if (payload != null &&
          payload.containsKey('targetEndTimeEpochMs') &&
          targetEnd == null) {
        _targetEndTimeEpochMs = 0;
      }

      final seconds = payload?['remainingSeconds'] ?? payload?['remaining'];
      if (seconds is int) {
        _remainingSeconds = seconds;
      } else if (seconds is num) {
        _remainingSeconds = seconds.toInt();
      } else if (!_isPaused && _targetEndTimeEpochMs > 0) {
        final remainingMs =
            _targetEndTimeEpochMs - DateTime.now().millisecondsSinceEpoch;
        _remainingSeconds = remainingMs <= 0 ? 0 : (remainingMs / 1000).ceil();
      }

      final isBreak = payload?['isBreak'] ?? payload?['isBreakMode'];
      if (isBreak is bool) {
        _isBreakMode = isBreak;
      }

      final isMaxFocus = payload?['isMaximumFocus'];
      if (isMaxFocus is bool) {
        _isMaximumFocus = isMaxFocus;
      }

      final passAvailable = payload?['emergencyPassAvailable'];
      if (passAvailable is bool) {
        _emergencyPassAvailable = passAvailable;
      }
    });

    if (_remainingSeconds <= 0 &&
        !_isBreakMode &&
        !_isScheduled &&
        widget.dataStream == null) {
      _onSessionCountdownComplete();
    } else {
      _startOrStopLocalTimer();
    }
  }

  @override
  void dispose() {
    _holdCancelController.dispose();
    _localCountdownTimer?.cancel();
    if (widget.dataStream == null) {
      _overlayBridgeChannel.setMethodCallHandler(null);
    }
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _handleReturn() async {
    if (_breatherStage != _BreatherStage.none) {
      setState(() => _breatherStage = _BreatherStage.none);
    }
    if (widget.onClose != null) {
      await widget.onClose!();
    } else {
      var bridgeHandled = false;
      try {
        final result =
            await _overlayBridgeChannel.invokeMethod<bool>('returnToFocusmaxxing');
        bridgeHandled = result ?? false;
      } catch (_) {}

      if (!bridgeHandled) {
        try {
          await FlutterOverlayWindow.closeOverlay();
        } catch (_) {}
      }
    }
  }

  Future<void> _handleCancelSession() async {
    unawaited(HapticFeedback.heavyImpact());
    if (widget.onCancelSession != null) {
      await widget.onCancelSession!();
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

  void _startBreather() {
    unawaited(HapticFeedback.lightImpact());
    setState(() => _breatherStage = _BreatherStage.breathing);
  }

  void _onBreatherComplete() {
    if (!mounted) return;
    setState(() => _breatherStage = _BreatherStage.decision);
  }

  Future<void> _handleEmergencyPass() async {
    var granted = false;
    if (widget.onEmergencyPass != null) {
      granted = await widget.onEmergencyPass!();
    } else {
      try {
        granted = await _overlayBridgeChannel
                .invokeMethod<bool>('grantEmergencyPass') ??
            false;
      } catch (_) {
        granted = false;
      }
    }
    if (!mounted) return;
    setState(() {
      if (granted) {
        _breatherStage = _BreatherStage.none;
      } else {
        _emergencyPassAvailable = false;
      }
    });
  }

  void _onHoldStart(TapDownDetails _) {
    unawaited(HapticFeedback.lightImpact());
    _holdCancelController.forward();
  }

  void _onHoldEnd([dynamic _]) {
    if (_holdCancelController.status != AnimationStatus.completed) {
      _holdCancelController.reverse();
    }
  }

  String _getRoastAffirmation({
    required bool isSessionFinished,
    required bool isBreakMode,
    required bool isScheduled,
  }) {
    if (isSessionFinished) {
      return '⚡ Flow state logged. Rest days build stamina.';
    }
    if (isBreakMode) {
      return '🧘 Rest your eyes, not your thumb. Step away from the screen.';
    }
    if (isScheduled) {
      return '🛡️ Scheduled deep work hours. Protect your future.';
    }
    return '⚡ Caught you scrolling. Reclaim your focus.';
  }

  Widget _buildShell(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: _surfaceColor,
        body: SizedBox.expand(
          child: ColoredBox(
            color: _surfaceColor,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreatherBody() {
    final isBreathing = _breatherStage == _BreatherStage.breathing;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'URGE SURFING',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isBreathing
              ? 'Dopamine spikes peak at 60 seconds and dissipate. Breathe.'
              : 'The urge has passed. What do you need?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: _subtextColor),
        ),
        const SizedBox(height: 36),
        if (isBreathing)
          BoxBreathingExercise(
            key: const Key('overlay_box_breathing'),
            totalDuration: widget.breatherDuration,
            color: _actionGreen,
            onComplete: _onBreatherComplete,
          )
        else ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              key: const Key('overlay_breather_ready_button'),
              style: FilledButton.styleFrom(
                backgroundColor: _actionGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: _handleReturn,
              child: const Text(
                "I'M READY TO FOCUS 🚀",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              key: const Key('overlay_emergency_pass_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              onPressed: _emergencyPassAvailable ? _handleEmergencyPass : null,
              child: Text(
                _emergencyPassAvailable
                    ? '2-MIN EMERGENCY PASS ⏱️'
                    : 'EMERGENCY PASS USED TODAY',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_breatherStage != _BreatherStage.none) {
      return _buildShell(_buildBreatherBody());
    }

    final clampedSeconds = _remainingSeconds > 0 ? _remainingSeconds : 0;
    final minutes = (clampedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (clampedSeconds % 60).toString().padLeft(2, '0');
    final isMaxFocusActive =
        _isMaximumFocus && !_isBreakMode && !_isScheduled && clampedSeconds > 0;
    final isSessionFinished =
        clampedSeconds <= 0 && !_isBreakMode && !_isScheduled;
    final timerDisplay = _isScheduled && _scheduleTimeRange.isNotEmpty
        ? _scheduleTimeRange
        : '$minutes:$seconds';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: _surfaceColor,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: SizedBox.expand(
          child: ColoredBox(
            color: _surfaceColor,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSessionFinished
                          ? Icons.celebration_rounded
                          : (isMaxFocusActive
                              ? Icons.gpp_maybe_rounded
                              : Icons.lock_rounded),
                      size: 64,
                      color: isSessionFinished
                          ? _actionGreen
                          : (isMaxFocusActive ? _alertColor : _alertColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isSessionFinished
                          ? 'SESSION COMPLETE 🎉'
                          : (_isBreakMode
                              ? 'RECHARGE YOUR BRAIN'
                              : (_isScheduled
                                  ? 'AUTO-SHIELD ACTIVE'
                                  : (isMaxFocusActive
                                      ? 'MAXIMUM FOCUS'
                                      : 'LOCKED IN'))),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isSessionFinished
                          ? 'Great job locking in! Tap below to check in.'
                          : (_isBreakMode
                              ? 'Social feeds remain locked during your break.'
                              : (_isScheduled
                                  ? 'Scheduled focus shield is active.'
                                  : '"$_taskGoal"')),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: _subtextColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        _getRoastAffirmation(
                          isSessionFinished: isSessionFinished,
                          isBreakMode: _isBreakMode,
                          isScheduled: _isScheduled,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB0B7C3),
                        ),
                      ),
                    ),
                    if (isMaxFocusActive) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _alertColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _alertColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'Full phone lock active until timer finishes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _alertColor,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        timerDisplay,
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    if (isMaxFocusActive)
                      GestureDetector(
                        key: const Key('overlay_hold_to_cancel_button'),
                        onTapDown: _onHoldStart,
                        onTapUp: _onHoldEnd,
                        onTapCancel: _onHoldEnd,
                        child: AnimatedBuilder(
                          animation: _holdCancelController,
                          builder: (context, _) {
                            final progress = _holdCancelController.value;
                            final remainingHoldSeconds =
                                (5 - (progress * 5)).ceil().clamp(1, 5);
                            return Container(
                              width: double.infinity,
                              height: 56,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: const Color(0xFF141720),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: _alertColor.withValues(
                                    alpha: progress > 0 ? 0.85 : 0.45,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progress,
                                    child: ColoredBox(
                                      color:
                                          _alertColor.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      progress > 0
                                          ? 'KEEP HOLDING ($remainingHoldSeconds S) TO CANCEL...'
                                          : 'HOLD 5S TO CANCEL SESSION',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 1.1,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _actionGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: _handleReturn,
                          child: Text(
                            isSessionFinished
                                ? 'COMPLETE CHECK-IN 🎉'
                                : 'RETURN TO FOCUSMAXXING',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    if (!isSessionFinished) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          key: const Key('overlay_take_breather_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          onPressed: _startBreather,
                          child: const Text(
                            '🌬️ TAKE A BREATHER (60S)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
