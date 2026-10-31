import 'package:flutter/material.dart';

/// Quick-capture pill button shown during an active focus session for dumping stray thoughts.
class InSessionQuickCapturePill extends StatelessWidget {
  const InSessionQuickCapturePill({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: 'Dump stray thought to Backlog',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('in_session_quick_capture_pill'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '+ Dump stray thought...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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
