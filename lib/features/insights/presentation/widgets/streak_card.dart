import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:provider/provider.dart';

/// Card displaying streak status and zero-guilt streak toggles in instrument aesthetic.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    this.streakDays,
  });

  final int? streakDays;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<InsightsNotifier>();
    final tokens = context.tokens;
    final isEnabled = notifier.isStreakEnabled;
    final includeWeekends = notifier.includeWeekendsInStreak;
    final days = streakDays ?? notifier.dailySummary?.currentStreakDays ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InstrumentTokens.r2),
        border: Border.all(color: tokens.rule, width: 1),
      ),
      padding: const EdgeInsets.all(InstrumentTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEnabled) ...[
            Text(
              'CURRENT STREAK: $days ${days == 1 ? "DAY" : "DAYS"}',
              style: TextStyle(
                fontFamily: InstrumentTokens.fontMono,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: InstrumentTokens.s12),
          ] else ...[
            Text(
              'Streak Tracking Hidden',
              style: TextStyle(
                fontFamily: InstrumentTokens.fontUi,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: tokens.inkMuted,
              ),
            ),
            const SizedBox(height: InstrumentTokens.s12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Streak Tracking',
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontUi,
                  fontSize: 14,
                  color: tokens.ink,
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: notifier.setStreakEnabled,
              ),
            ],
          ),
          if (isEnabled) ...[
            const SizedBox(height: InstrumentTokens.s8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Include Weekends in Streak',
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 14,
                    color: tokens.ink,
                  ),
                ),
                Switch(
                  value: includeWeekends,
                  onChanged: notifier.setIncludeWeekendsInStreak,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
