import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:provider/provider.dart';

class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    this.streakDays,
  });

  final int? streakDays;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<InsightsNotifier>();
    final isStreakEnabled = notifier.isStreakEnabled;
    final includeWeekends = notifier.includeWeekendsInStreak;
    final days = streakDays ?? notifier.dailySummary?.currentStreakDays ?? 0;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isStreakEnabled) ...[
              Row(
                children: [
                  const Text(
                    '🔥',
                    style: TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT STREAK: $days ${days == 1 ? "DAY" : "DAYS"}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: colorScheme.tertiary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          days > 0
                              ? 'Momentum is rolling · Every lock-in counts'
                              : 'No active streak · Start a session to ignite it',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: colorScheme.outlineVariant, height: 1),
              const SizedBox(height: 8),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    color: colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Streak Tracking Hidden',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Zero-guilt mode active. Focus at your own pace.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Streak Tracking',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                'Show streak counter and momentum badges',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              value: isStreakEnabled,
              activeThumbColor: colorScheme.primary,
              onChanged: notifier.setStreakEnabled,
            ),
            if (isStreakEnabled)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Include Weekends in Streak',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  includeWeekends
                      ? '7-day discipline: weekends required'
                      : 'Weekends exempt: momentum preserved',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                value: includeWeekends,
                activeThumbColor: colorScheme.primary,
                onChanged: notifier.setIncludeWeekendsInStreak,
              ),
          ],
        ),
      ),
    );
  }
}
