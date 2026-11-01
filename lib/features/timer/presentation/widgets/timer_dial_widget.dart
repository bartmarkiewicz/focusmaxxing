import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/ui/instrument_dial.dart';

class TimerDialWidget extends StatelessWidget {
  const TimerDialWidget({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.taskGoal,
    this.isPaused = false,
    this.isRestMode = false,
    this.onDurationChanged,
    this.size = 280.0,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final String? taskGoal;
  final bool isPaused;
  final bool isRestMode;
  final ValueChanged<int>? onDurationChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InstrumentDial(
      remainingSeconds: remainingSeconds,
      totalSeconds: totalSeconds,
      taskGoal: taskGoal,
      isPaused: isPaused,
      isRestMode: isRestMode,
      onDurationChanged: onDurationChanged,
      size: size,
    );
  }
}
