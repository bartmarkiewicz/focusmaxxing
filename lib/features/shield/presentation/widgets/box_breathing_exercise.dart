import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

enum BreathingPhase {
  inhale(AppStrings.breathIn),
  holdFull(AppStrings.breathHold),
  exhale(AppStrings.breathOut),
  holdEmpty(AppStrings.breathHold);

  const BreathingPhase(this.label);

  final String label;
}

/// A guided square-tracing breathing exercise (4s In, 4s Hold, 4s Out, 4s Hold).
class BoxBreathingExercise extends StatefulWidget {
  const BoxBreathingExercise({
    super.key,
    required this.onComplete,
    this.totalDuration = const Duration(seconds: 60),
    this.phaseDuration = const Duration(seconds: 4),
    this.color = const Color(0xFFC9A227),
    this.enableHaptics = true,
    this.size = 180.0,
  });

  final VoidCallback onComplete;
  final Duration totalDuration;
  final Duration phaseDuration;
  final Color color;
  final bool enableHaptics;
  final double size;

  @override
  State<BoxBreathingExercise> createState() => _BoxBreathingExerciseState();
}

class _BoxBreathingExerciseState extends State<BoxBreathingExercise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  BreathingPhase? _lastPhase;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    )
      ..addListener(_onTick)
      ..addStatusListener(_onStatusChanged);
    unawaited(_controller.forward());
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete();
    }
  }

  void _onTick() {
    final cycleDurationMs = widget.phaseDuration.inMilliseconds * 4;
    final elapsedMs = _controller.value * widget.totalDuration.inMilliseconds;
    final msInCurrentCycle = elapsedMs % cycleDurationMs;
    final phaseIndex = (msInCurrentCycle ~/ widget.phaseDuration.inMilliseconds) % 4;
    final currentPhase = BreathingPhase.values[phaseIndex];

    if (currentPhase != _lastPhase) {
      _lastPhase = currentPhase;
      if (widget.enableHaptics) {
        unawaited(HapticFeedback.selectionClick());
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cycleDurationMs = widget.phaseDuration.inMilliseconds * 4;
    final elapsedMs = _controller.value * widget.totalDuration.inMilliseconds;
    final msInCurrentCycle = elapsedMs % cycleDurationMs;
    final cycleProgress = msInCurrentCycle / cycleDurationMs;
    final currentPhase = _lastPhase ?? BreathingPhase.inhale;

    return Semantics(
      label: 'Box breathing: ${currentPhase.label}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _SquareTracePainter(
                progress: cycleProgress,
                accentColor: widget.color,
                trackColor: const Color(0xFF2A2825),
              ),
              child: Center(
                child: Text(
                  currentPhase.label.toUpperCase(),
                  key: const Key('breathing_phase_label'),
                  style: const TextStyle(
                    fontFamily: InstrumentTokens.fontMono,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.0,
                    color: Color(0xFFEDE9E3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: InstrumentTokens.s16),
          const Text(
            '4s In · 4s Hold · 4s Out · 4s Hold',
            style: TextStyle(
              fontFamily: InstrumentTokens.fontMono,
              fontSize: 12,
              color: Color(0xFF9A948B),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareTracePainter extends CustomPainter {
  const _SquareTracePainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final Color accentColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);

    // Track square
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, trackPaint);

    // Tracing active line along the 4 edges
    // Edge 0 (top): 0.0 -> 0.25
    // Edge 1 (right): 0.25 -> 0.50
    // Edge 2 (bottom): 0.50 -> 0.75
    // Edge 3 (left): 0.75 -> 1.0
    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 2.0;

    final path = Path();
    final perimeter = rect.width * 4;
    final currentDistance = progress * perimeter;

    path.moveTo(rect.left, rect.top);

    if (currentDistance <= rect.width) {
      path.lineTo(rect.left + currentDistance, rect.top);
    } else {
      path.lineTo(rect.right, rect.top);
      final remaining = currentDistance - rect.width;
      if (remaining <= rect.height) {
        path.lineTo(rect.right, rect.top + remaining);
      } else {
        path.lineTo(rect.right, rect.bottom);
        final rem2 = remaining - rect.height;
        if (rem2 <= rect.width) {
          path.lineTo(rect.right - rem2, rect.bottom);
        } else {
          path.lineTo(rect.left, rect.bottom);
          final rem3 = rem2 - rect.width;
          path.lineTo(rect.left, rect.bottom - rem3);
        }
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SquareTracePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.trackColor != trackColor;
  }
}
