import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/utils/color_utils.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';
import 'package:provider/provider.dart';

/// Displays active session status with clean instrument styling and zero emojis.
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
    final tokens = context.tokens;
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

    final statusTitle = isPaused
        ? 'Focus paused'
        : (isMaxFocus ? 'Maximum Focus active' : 'Session running');

    final statusSubtitle = isPaused
        ? 'Countdown paused'
        : activeShieldCount > 0
            ? '$activeShieldCount ${activeShieldCount == 1 ? "app" : "apps"} blocked by Brainrot Shield'
            : 'Timer active in status bar';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InstrumentTokens.r2),
        border: Border.all(
          color: isPaused ? tokens.ruleStrong : (isMaxFocus ? tokens.danger : tokens.accent),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPaused
                    ? Icons.pause_outlined
                    : (isMaxFocus ? Icons.lock_outlined : Icons.timer_outlined),
                size: 16,
                color: isPaused ? tokens.inkMuted : (isMaxFocus ? tokens.danger : tokens.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            statusSubtitle,
            style: TextStyle(
              fontFamily: InstrumentTokens.fontUi,
              fontSize: 12,
              color: tokens.inkMuted,
            ),
          ),
          if (targets.length > 1) ...[
            const SizedBox(height: 8),
            Container(height: 1, color: tokens.rule),
            const SizedBox(height: 8),
            for (final target in targets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: ColorUtils.fromHex(target.colorHex),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        target.targetName,
                        style: TextStyle(
                          fontFamily: InstrumentTokens.fontUi,
                          fontSize: 13,
                          color: tokens.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${target.percentage}% (${(target.allocatedSeconds / 60).round()}m)',
                      style: TextStyle(
                        fontFamily: InstrumentTokens.fontMono,
                        fontSize: 12,
                        color: tokens.inkMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
