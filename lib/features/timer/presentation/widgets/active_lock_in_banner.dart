import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/utils/color_utils.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';
import 'package:provider/provider.dart';

/// Displays the active focus lock-in status banner when a session is running or paused.
class ActiveLockInBanner extends StatelessWidget {
  const ActiveLockInBanner({
    super.key,
    required this.isPaused,
    this.targets = const [],
  });

  final bool isPaused;
  final List<SessionTargetAllocation> targets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shieldState = context.select<
        ShieldNotifier?,
        ({int activeAppCount, bool isMaximumFocusEnabled})>(
      (notifier) => (
        activeAppCount: notifier?.activeAppCount ?? 0,
        isMaximumFocusEnabled: notifier?.isMaximumFocusEnabled ?? false,
      ),
    );
    final activeShieldCount = shieldState.activeAppCount;
    final isMaxFocus = shieldState.isMaximumFocusEnabled;

    final accentColor = isPaused
        ? colorScheme.tertiary
        : (isMaxFocus ? colorScheme.error : colorScheme.primary);
    final statusTitle = isPaused
        ? '⏸ FOCUS SESSION PAUSED'
        : (isMaxFocus
            ? '🔥 MAXIMUM FOCUS · PHONE LOCKED'
            : '🔒 LOCKED IN · ACTIVE FOCUS');
    final statusSubtitle = isPaused
        ? 'Countdown paused · Resume below to keep your streak'
        : isMaxFocus
            ? 'Full-screen phone lock enforced until session completes'
            : activeShieldCount > 0
                ? 'Brainrot Shield active ($activeShieldCount ${activeShieldCount == 1 ? "app" : "apps"} blocked) · Ongoing timer in notification bar'
                : 'Focus countdown active in notification bar';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPaused
                    ? Icons.pause_circle_filled_rounded
                    : (isMaxFocus
                        ? Icons.gpp_maybe_rounded
                        : Icons.shield_rounded),
                color: accentColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (targets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final target in targets) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ColorUtils.fromHex(target.colorHex)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ColorUtils.fromHex(target.colorHex)
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: ColorUtils.fromHex(target.colorHex),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${target.targetName} (${target.percentage}%)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
