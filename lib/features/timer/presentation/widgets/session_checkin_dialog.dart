import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/utils/haptic_feedback_helper.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';

@immutable
class SessionCheckInResult {
  const SessionCheckInResult({
    required this.lockedIn,
    this.endAllSessions = false,
  });

  final bool lockedIn;
  final bool endAllSessions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionCheckInResult &&
          runtimeType == other.runtimeType &&
          lockedIn == other.lockedIn &&
          endAllSessions == other.endAllSessions;

  @override
  int get hashCode => Object.hash(lockedIn, endAllSessions);
}

class SessionCheckInDialog extends StatelessWidget {
  const SessionCheckInDialog({
    super.key,
    required this.durationSeconds,
    required this.taskGoal,
  });

  final int durationSeconds;
  final String taskGoal;

  static Future<bool?> show(
    BuildContext context, {
    required int durationSeconds,
    required String taskGoal,
  }) async {
    final result = await showWithOutcome(
      context,
      durationSeconds: durationSeconds,
      taskGoal: taskGoal,
    );
    return result?.lockedIn;
  }

  static Future<SessionCheckInResult?> showWithOutcome(
    BuildContext context, {
    required int durationSeconds,
    required String taskGoal,
  }) {
    return showDialog<SessionCheckInResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: SessionCheckInDialog(
          durationSeconds: durationSeconds,
          taskGoal: taskGoal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formattedDuration =
        TimeFormatter.formatDurationToMinutes(durationSeconds);

    return Dialog(
      backgroundColor: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎉 $formattedDuration Complete',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (taskGoal.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '"${taskGoal.trim()}"',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Did you lock in?',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        unawaited(
                          HapticFeedback.mediumImpact()
                              .catchError((Object _) {}),
                        );
                        Navigator.of(context).pop(
                          const SessionCheckInResult(lockedIn: false),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DERAILED 💀',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '(Got Distracted)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        unawaited(
                          HapticFeedbackHelper.victoryBurst()
                              .catchError((Object _) {}),
                        );
                        Navigator.of(context).pop(
                          const SessionCheckInResult(lockedIn: true),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'LOCKED IN 🚀',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '(Flow State)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  colorScheme.onPrimary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('checkin_end_all_sessions_button'),
                  onPressed: () {
                    unawaited(
                      HapticFeedback.heavyImpact().catchError((Object _) {}),
                    );
                    Navigator.of(context).pop(
                      const SessionCheckInResult(
                        lockedIn: true,
                        endAllSessions: true,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    Icons.stop_circle_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  label: Text(
                    'LOCKED IN & END ALL SESSIONS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
