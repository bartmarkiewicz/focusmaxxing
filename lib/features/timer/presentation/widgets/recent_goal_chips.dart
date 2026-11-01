import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/ui/tag.dart';

/// Displays quick-select tags for recently used focus goals when the timer is idle.
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

    final normalizedCurrent = currentGoal.trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final goal in recentGoals)
            Tag(
              label: goal,
              isSelected: goal.toLowerCase() == normalizedCurrent,
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
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
