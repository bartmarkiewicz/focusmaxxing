import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:provider/provider.dart';

/// Toggle pill enabling or disabling Single Session Mode (skipping automatic break loops).
class SingleSessionModePill extends StatelessWidget {
  const SingleSessionModePill({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select<TimerNotifier, bool>(
      (notifier) => notifier.isSingleSessionMode,
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeColor = colorScheme.primary;

    return Semantics(
      button: true,
      toggled: isEnabled,
      excludeSemantics: true,
      label: isEnabled
          ? 'Single Session Mode enabled. Session ends after check-in without starting a break. Tap to disable.'
          : 'Single Session Mode disabled. Tap to enable single session mode.',
      child: InkWell(
        key: const Key('timer_single_session_mode_pill'),
        onTap: () async {
          unawaited(
            HapticFeedback.selectionClick().catchError((Object _) {}),
          );
          await context.read<TimerNotifier>().toggleSingleSessionMode();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isEnabled
                ? activeColor.withValues(alpha: 0.14)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isEnabled
                  ? activeColor.withValues(alpha: 0.55)
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnabled ? Icons.looks_one_rounded : Icons.repeat_rounded,
                size: 16,
                color: isEnabled ? activeColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                isEnabled ? 'Single Session: ON' : 'Single Session: OFF',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isEnabled ? activeColor : colorScheme.onSurfaceVariant,
                  fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
