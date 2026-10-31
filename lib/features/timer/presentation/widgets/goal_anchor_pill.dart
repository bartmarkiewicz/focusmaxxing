import 'package:flutter/material.dart';

/// Displays the current focus anchor goal and allows editing when the timer is idle.
class GoalAnchorPill extends StatelessWidget {
  const GoalAnchorPill({
    super.key,
    required this.goal,
    required this.isIdle,
    required this.onTap,
  });

  final String goal;
  final bool isIdle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trimmed = goal.trim();

    return Semantics(
      button: isIdle,
      label: trimmed.isNotEmpty
          ? 'Active anchor: $trimmed'
          : 'No anchor set. Tap to set anchor.',
      child: InkWell(
        onTap: isIdle ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.anchor_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  trimmed.isNotEmpty ? trimmed : 'Set Single Focus Anchor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: trimmed.isNotEmpty
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isIdle) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
