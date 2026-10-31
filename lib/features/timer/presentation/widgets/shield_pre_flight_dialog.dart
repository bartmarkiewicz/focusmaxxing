import 'package:flutter/material.dart';

/// Pre-flight warning dialog displayed when shielded apps are selected but Android
/// usage/overlay permissions have not been granted yet.
abstract final class ShieldPreFlightDialog {
  static Future<bool?> show(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Icon(
          Icons.shield_outlined,
          color: colorScheme.error,
          size: 32,
        ),
        title: Text(
          'Shield Not Armed',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Brainrot Shield is not armed yet. Enable Android permissions to physically block distraction apps during your focus session.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            key: const Key('shield_gate_start_timer_only_button'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Start Timer Only',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          FilledButton.icon(
            key: const Key('shield_gate_arm_shield_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            icon: const Icon(Icons.security, size: 18),
            label: const Text('Arm Shield (30s)'),
          ),
        ],
      ),
    );
  }
}
