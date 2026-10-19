import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

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
    this.initialGoal = 'Deep Work',
    this.initialRemainingSeconds = 1500,
    this.initialIsBreak = false,
    this.initialIsMaximumFocus = false,
  });

  final Stream<dynamic>? dataStream;
  final Future<void> Function()? onClose;
  final Future<void> Function()? onCancelSession;
  final String initialGoal;
  final int initialRemainingSeconds;
  final bool initialIsBreak;
  final bool initialIsMaximumFocus;

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

  late String _taskGoal;
  late int _remainingSeconds;
  late bool _isBreakMode;
  late bool _isMaximumFocus;
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

    _holdCancelController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _holdCancelController.reset();
          unawaited(_handleCancelSession());
        }
      });

    final stream = widget.dataStream ?? FlutterOverlayWindow.overlayListener;
    _subscription = stream.listen(
      _handleIncomingData,
      onError: (Object _, [StackTrace? _]) {},
    );

    if (widget.dataStream == null) {
      _overlayBridgeChannel.setMethodCallHandler(_handleBridgeMethodCall);
      unawaited(_fetchInitialOverlayState());
      _localCountdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (mounted && _remainingSeconds > 0) {
            setState(() {
              _remainingSeconds--;
            });
          }
        },
      );
    }
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
      }
    } catch (_) {}
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

      final seconds = payload?['remainingSeconds'] ?? payload?['remaining'];
      if (seconds is int) {
        _remainingSeconds = seconds;
      } else if (seconds is num) {
        _remainingSeconds = seconds.toInt();
      }

      final isBreak = payload?['isBreak'] ?? payload?['isBreakMode'];
      if (isBreak is bool) {
        _isBreakMode = isBreak;
      }

      final isMaxFocus = payload?['isMaximumFocus'];
      if (isMaxFocus is bool) {
        _isMaximumFocus = isMaxFocus;
      }
    });
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
    if (widget.onClose != null) {
      await widget.onClose!();
    } else {
      try {
        await _overlayBridgeChannel.invokeMethod<bool>('returnToFocusmaxxing');
      } catch (_) {}
      try {
        await FlutterOverlayWindow.shareData(
          jsonEncode({'action': 'returnToFocusmaxxing'}),
        );
      } catch (_) {}
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (_) {}
    }
  }

  Future<void> _handleCancelSession() async {
    unawaited(HapticFeedback.heavyImpact());
    if (widget.onCancelSession != null) {
      await widget.onCancelSession!();
    } else {
      try {
        await _overlayBridgeChannel
            .invokeMethod<bool>('cancelSessionFromOverlay');
      } catch (_) {}
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

  void _onHoldStart(TapDownDetails _) {
    unawaited(HapticFeedback.lightImpact());
    _holdCancelController.forward();
  }

  void _onHoldEnd([dynamic _]) {
    if (_holdCancelController.status != AnimationStatus.completed) {
      _holdCancelController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clampedSeconds = _remainingSeconds > 0 ? _remainingSeconds : 0;
    final minutes = (clampedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (clampedSeconds % 60).toString().padLeft(2, '0');
    final isMaxFocusActive = _isMaximumFocus && !_isBreakMode;

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
                      isMaxFocusActive
                          ? Icons.gpp_maybe_rounded
                          : Icons.lock_rounded,
                      size: 64,
                      color: _alertColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isBreakMode
                          ? 'RECHARGE YOUR BRAIN'
                          : (isMaxFocusActive ? 'MAXIMUM FOCUS' : 'LOCKED IN'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isBreakMode
                          ? 'Social feeds remain locked during your break.'
                          : '"$_taskGoal"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: _subtextColor,
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
                    Text(
                      '$minutes:$seconds',
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: Colors.white,
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
                                      color: _alertColor.withValues(alpha: 0.35),
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
                          child: const Text(
                            'RETURN TO FOCUSMAXXING',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
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
