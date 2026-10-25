import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/utils/haptic_feedback_helper.dart';

enum BreathingPhase {
  inhale('INHALE'),
  holdFull('HOLD'),
  exhale('EXHALE'),
  holdEmpty('HOLD');

  const BreathingPhase(this.label);

  final String label;
}

/// A guided box-breathing exercise (inhale, hold, exhale, hold) that calls
/// [onComplete] once [totalDuration] has elapsed.
class BoxBreathingExercise extends StatefulWidget {
  const BoxBreathingExercise({
    super.key,
    required this.onComplete,
    this.totalDuration = const Duration(seconds: 60),
    this.phaseDuration = const Duration(seconds: 4),
    this.color = const Color(0xFF00E676),
    this.enableHaptics = true,
  });

  final VoidCallback onComplete;
  final Duration totalDuration;
  final Duration phaseDuration;
  final Color color;
  final bool enableHaptics;

  @override
  State<BoxBreathingExercise> createState() => _BoxBreathingExerciseState();
}

class _BoxBreathingExerciseState extends State<BoxBreathingExercise>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 0.45;
  static const int _phaseCount = 4;

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
    if (status == AnimationStatus.completed && mounted) {
      widget.onComplete();
    }
  }

  void _onTick() {
    final phase = _phaseAt(_elapsed);
    if (phase != _lastPhase) {
      _lastPhase = phase;
      if (widget.enableHaptics) {
        unawaited(HapticFeedbackHelper.selectionClick());
      }
    }
  }

  Duration get _elapsed => widget.totalDuration * _controller.value;

  BreathingPhase _phaseAt(Duration elapsed) {
    final phaseMicros = widget.phaseDuration.inMicroseconds;
    if (phaseMicros <= 0) return BreathingPhase.inhale;
    final index = (elapsed.inMicroseconds ~/ phaseMicros) % _phaseCount;
    return BreathingPhase.values[index];
  }

  double _scaleAt(Duration elapsed) {
    final phaseMicros = widget.phaseDuration.inMicroseconds;
    if (phaseMicros <= 0) return 1.0;
    final progress = (elapsed.inMicroseconds % phaseMicros) / phaseMicros;
    return switch (_phaseAt(elapsed)) {
      BreathingPhase.inhale => _minScale + (1 - _minScale) * progress,
      BreathingPhase.holdFull => 1.0,
      BreathingPhase.exhale => 1 - (1 - _minScale) * progress,
      BreathingPhase.holdEmpty => _minScale,
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final elapsed = _elapsed;
        final phase = _phaseAt(elapsed);
        final secondsLeft = math.max(
          0,
          (widget.totalDuration - elapsed).inMilliseconds / 1000,
        ).ceil();

        return Semantics(
          label: 'Box breathing: ${phase.label}, $secondsLeft seconds remaining',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: Center(
                  child: Transform.scale(
                    scale: _scaleAt(elapsed),
                    child: ExcludeSemantics(
                      child: Container(
                        key: const Key('breathing_circle'),
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withValues(alpha: 0.18),
                          border: Border.all(color: widget.color, width: 3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                phase.label,
                key: const Key('breathing_phase_label'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${secondsLeft}s',
                key: const Key('breathing_seconds_left'),
                style: const TextStyle(fontSize: 14, color: Color(0xFF8B92A4)),
              ),
            ],
          ),
        );
      },
    );
  }
}
