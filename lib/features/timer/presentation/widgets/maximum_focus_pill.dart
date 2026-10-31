import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:provider/provider.dart';

/// Toggle pill enabling or disabling Maximum Focus (full phone lock) mode.
class MaximumFocusPill extends StatelessWidget {
  const MaximumFocusPill({super.key});

  @override
  Widget build(BuildContext context) {
    final shieldState =
        context.select<ShieldNotifier?, ({bool hasNotifier, bool isEnabled})>(
      (notifier) => (
        hasNotifier: notifier != null,
        isEnabled: notifier?.isMaximumFocusEnabled ?? false,
      ),
    );
    if (!shieldState.hasNotifier) return const SizedBox.shrink();

    final isEnabled = shieldState.isEnabled;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeColor = colorScheme.error;

    return Semantics(
      button: true,
      toggled: isEnabled,
      label: isEnabled
          ? 'Maximum Focus enabled (full phone lock). Tap to disable.'
          : 'Maximum Focus disabled. Tap to enable full phone lock.',
      child: InkWell(
        key: const Key('timer_maximum_focus_pill'),
        onTap: () async {
          final shieldNotifier = context.read<ShieldNotifier?>();
          if (shieldNotifier == null) return;
          try {
            unawaited(HapticFeedback.selectionClick());
          } catch (_) {}
          final next = !isEnabled;
          await shieldNotifier.setMaximumFocusEnabled(next);
          if (next && !shieldNotifier.permissionStatus.hasOverlayPermission) {
            await shieldNotifier
                .requestPermission(ShieldPermissionType.overlay);
          }
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
                isEnabled
                    ? Icons.gpp_maybe_rounded
                    : Icons.lock_outline_rounded,
                size: 16,
                color: isEnabled ? activeColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                isEnabled ? 'Max Focus: ON' : 'Max Focus: OFF',
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
