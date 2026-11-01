import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/ui/hold_button.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';

/// Renders the primary timer action controls corresponding to the current [TimerStatus].
class TimerControlActions extends StatelessWidget {
  const TimerControlActions({
    super.key,
    required this.timerNotifier,
    required this.onStartLockIn,
    required this.onTriggerCheckIn,
  });

  final TimerNotifier timerNotifier;
  final VoidCallback onStartLockIn;
  final VoidCallback onTriggerCheckIn;

  @override
  Widget build(BuildContext context) {
    switch (timerNotifier.status) {
      case TimerStatus.idle:
        return InstrumentButton.primary(
          label: AppStrings.startSession,
          onPressed: onStartLockIn,
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
        );

      case TimerStatus.running:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InstrumentButton.secondary(
              label: 'Pause',
              onPressed: timerNotifier.pause,
              icon: const Icon(Icons.pause_outlined, size: 20),
            ),
            const SizedBox(height: 12),
            HoldButton(
              label: AppStrings.holdToStop,
              progress: timerNotifier.cancelHoldProgress,
              progressListenable: timerNotifier.cancelHoldProgressNotifier,
              onHoldStart: timerNotifier.startHoldToCancel,
              onHoldEnd: timerNotifier.releaseHoldToCancel,
              onCancelImmediate: timerNotifier.cancelSession,
              holdDuration: const Duration(seconds: 5),
            ),
          ],
        );

      case TimerStatus.paused:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InstrumentButton.primary(
              label: 'Resume focus',
              onPressed: timerNotifier.resume,
              icon: const Icon(Icons.play_arrow_outlined, size: 20),
            ),
            const SizedBox(height: 12),
            HoldButton(
              label: AppStrings.holdToStop,
              progress: timerNotifier.cancelHoldProgress,
              progressListenable: timerNotifier.cancelHoldProgressNotifier,
              onHoldStart: timerNotifier.startHoldToCancel,
              onHoldEnd: timerNotifier.releaseHoldToCancel,
              onCancelImmediate: timerNotifier.cancelSession,
              holdDuration: const Duration(seconds: 5),
            ),
          ],
        );

      case TimerStatus.completed:
        return InstrumentButton.primary(
          label: AppStrings.save,
          onPressed: onTriggerCheckIn,
        );

      case TimerStatus.breakRunning:
      case TimerStatus.breakCompleted:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InstrumentButton.primary(
              key: const Key('timer_roll_into_next_block_button'),
              label: 'Start another ${timerNotifier.focusDurationMinutes} min',
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: () async {
                unawaited(HapticFeedback.heavyImpact());
                await timerNotifier.startNextFocusFromBreak();
              },
            ),
            const SizedBox(height: 12),
            InstrumentButton.text(
              key: const Key('timer_end_all_sessions_button'),
              label: AppStrings.done,
              onPressed: () {
                unawaited(HapticFeedback.selectionClick());
                timerNotifier.endAllSessions();
              },
            ),
          ],
        );
    }
  }
}
