import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays quick-select chips for recently used focus goals when the timer is idle.
class RecentGoalChips extends StatelessWidget {
  const RecentGoalChips({
    super.key,
    required this.recentGoals,
    required this.currentGoal,
    required this.onSelectGoal,
    required this.onStartLockIn,
  });

  final List<String> recentGoals;
  final String currentGoal;
  final ValueChanged<String> onSelectGoal;
  final VoidCallback onStartLockIn;

  @override
  Widget build(BuildContext context) {
    if (recentGoals.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final normalizedCurrent = currentGoal.trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final goal in recentGoals)
            ActionChip(
              avatar: const Icon(Icons.bolt_rounded, size: 14),
              label: Text(
                goal,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: goal.toLowerCase() == normalizedCurrent
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              backgroundColor: goal.toLowerCase() == normalizedCurrent
                  ? colorScheme.primary.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              side: BorderSide(
                color: goal.toLowerCase() == normalizedCurrent
                    ? colorScheme.primary.withValues(alpha: 0.5)
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () {
                try {
                  unawaited(HapticFeedback.selectionClick());
                } catch (_) {}
                final isAlreadyActive = goal.toLowerCase() == normalizedCurrent;
                onSelectGoal(goal);
                if (isAlreadyActive) {
                  onStartLockIn();
                }
              },
            ),
        ],
      ),
    );
  }
}
