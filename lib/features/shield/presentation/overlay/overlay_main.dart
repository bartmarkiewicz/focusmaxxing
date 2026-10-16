import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

@pragma('vm:entry-point')
void overlayMain() {
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
    this.initialGoal = 'Deep Work',
    this.initialRemainingSeconds = 1500,
    this.initialIsBreak = false,
  });

  final Stream<dynamic>? dataStream;
  final Future<void> Function()? onClose;
  final String initialGoal;
  final int initialRemainingSeconds;
  final bool initialIsBreak;

  @override
  State<HardLockOverlayWidget> createState() => _HardLockOverlayWidgetState();
}

class _HardLockOverlayWidgetState extends State<HardLockOverlayWidget> {
  static const Color _surfaceColor = Color(0xFF090A0D);
  static const Color _alertColor = Color(0xFFFF3B30);
  static const Color _subtextColor = Color(0xFF8B92A4);
  static const Color _actionGreen = Color(0xFF00E676);

  late String _taskGoal;
  late int _remainingSeconds;
  late bool _isBreakMode;
  StreamSubscription<dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _taskGoal = widget.initialGoal;
    _remainingSeconds = widget.initialRemainingSeconds;
    _isBreakMode = widget.initialIsBreak;

    final stream = widget.dataStream ?? FlutterOverlayWindow.overlayListener;
    _subscription = stream.listen(
      _handleIncomingData,
      onError: (Object _, [StackTrace? _]) {},
    );
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
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _handleReturn() async {
    if (widget.onClose != null) {
      await widget.onClose!();
    } else {
      try {
        await FlutterOverlayWindow.shareData(
          jsonEncode({'action': 'returnToFocusmaxxing'}),
        );
      } catch (_) {}
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clampedSeconds = _remainingSeconds > 0 ? _remainingSeconds : 0;
    final minutes = (clampedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (clampedSeconds % 60).toString().padLeft(2, '0');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: _surfaceColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 64,
                  color: _alertColor,
                ),
                const SizedBox(height: 16),
                Text(
                  _isBreakMode ? 'RECHARGE YOUR BRAIN' : 'LOCKED IN',
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
    );
  }
}
