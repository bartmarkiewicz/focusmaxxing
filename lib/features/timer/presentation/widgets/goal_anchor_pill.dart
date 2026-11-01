import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
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
    final tokens = context.tokens;

    final String displayText;
    if (targets.isNotEmpty) {
      displayText = TargetAllocationBalancer.formatAnchorPillText(targets);
    } else {
      final trimmed = goal.trim();
      displayText = trimmed.isNotEmpty ? trimmed : 'Set focus target';
    }

    final hasTarget = targets.isNotEmpty || goal.trim().isNotEmpty;

    return Semantics(
      button: isIdle,
      label: hasTarget
          ? 'Active anchors: $displayText'
          : 'No anchor set. Tap to set targets.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isIdle ? onTap : null,
          borderRadius: BorderRadius.circular(InstrumentTokens.r1),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: InstrumentTokens.s12,
              vertical: InstrumentTokens.s6,
            ),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(InstrumentTokens.r1),
              border: Border.all(color: tokens.ruleStrong, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.adjust_outlined,
                  size: 16,
                  color: hasTarget ? tokens.accent : tokens.inkMuted,
                ),
                const SizedBox(width: InstrumentTokens.s8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: InstrumentTokens.fontUi,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: hasTarget ? tokens.ink : tokens.inkMuted,
                    ),
                  ),
                ),
                if (isIdle) ...[
                  const SizedBox(width: InstrumentTokens.s4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: tokens.inkMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
