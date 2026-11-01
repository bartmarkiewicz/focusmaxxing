import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';
import 'package:focusmaxxing/features/timer/domain/utils/target_allocation_balancer.dart';

/// Displays the current focus anchor goal(s) and allows editing when the timer is idle.
class GoalAnchorPill extends StatelessWidget {
  const GoalAnchorPill({
    super.key,
    required this.goal,
    required this.isIdle,
    required this.onTap,
    this.targets = const [],
  });

  final String goal;
  final bool isIdle;
  final VoidCallback onTap;
  final List<SessionTargetAllocation> targets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String displayText;
    if (targets.isNotEmpty) {
      displayText = TargetAllocationBalancer.formatAnchorPillText(targets);
    } else {
      final trimmed = goal.trim();
      displayText = trimmed.isNotEmpty ? trimmed : 'Set Single Focus Anchor';
    }

    final hasTarget = targets.isNotEmpty || goal.trim().isNotEmpty;

    return Semantics(
      button: isIdle,
      label: hasTarget
          ? 'Active anchors: $displayText'
          : 'No anchor set. Tap to set targets.',
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
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: hasTarget
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
