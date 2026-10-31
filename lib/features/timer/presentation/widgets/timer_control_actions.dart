import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/hold_to_cancel_button.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (timerNotifier.status) {
      case TimerStatus.idle:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onStartLockIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              '🚀 LOCK IN',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );

      case TimerStatus.running:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: timerNotifier.pause,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pause_rounded, size: 22),
                const SizedBox(width: 8),
                Text(
                  'PAUSE FOCUS',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );

      case TimerStatus.paused:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: timerNotifier.resume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'RESUME FOCUS',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            HoldToCancelButton(
              progress: timerNotifier.cancelHoldProgress,
              progressListenable: timerNotifier.cancelHoldProgressNotifier,
              onHoldStart: timerNotifier.startHoldToCancel,
              onHoldEnd: timerNotifier.releaseHoldToCancel,
              onCancelImmediate: timerNotifier.cancelSession,
            ),
          ],
        );

      case TimerStatus.completed:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onTriggerCheckIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'COMPLETE CHECK-IN 🎉',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );

      case TimerStatus.breakRunning:
      case TimerStatus.breakCompleted:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                key: const Key('timer_roll_into_next_block_button'),
                onPressed: () async {
                  unawaited(
                    HapticFeedback.heavyImpact().catchError((Object _) {}),
                  );
                  await timerNotifier.startNextFocusFromBreak();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  '🚀 ROLL INTO NEXT BLOCK (${timerNotifier.focusDurationMinutes}m)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                key: const Key('timer_end_all_sessions_button'),
                onPressed: () {
                  unawaited(
                    HapticFeedback.mediumImpact().catchError((Object _) {}),
                  );
                  timerNotifier.endAllSessions();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: Icon(
                  Icons.stop_circle_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                label: Text(
                  'END ALL SESSIONS',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }
}
