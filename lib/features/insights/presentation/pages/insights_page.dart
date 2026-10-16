import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/audio/presentation/widgets/soundscape_config_tile.dart';
import 'package:focusmaxxing/features/insights/domain/entities/daily_summary_entity.dart';
import 'package:focusmaxxing/features/insights/presentation/notifiers/insights_notifier.dart';
import 'package:focusmaxxing/features/insights/presentation/widgets/session_history_list.dart';
import 'package:focusmaxxing/features/insights/presentation/widgets/streak_card.dart';
import 'package:provider/provider.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<InsightsNotifier>().loadInsights());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<InsightsNotifier>();
    final summary = notifier.dailySummary;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Insights & Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        color: colorScheme.primary,
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: _InsightsBody(
          notifier: notifier,
          summary: summary,
        ),
      ),
    );
  }
}

class _InsightsBody extends StatelessWidget {
  final InsightsNotifier notifier;
  final DailySummaryEntity? summary;

  const _InsightsBody({
    required this.notifier,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    if (notifier.isLoading && summary == null) {
      return const _InsightsLoadingView();
    }

    final errorMessage = notifier.errorMessage;
    if (errorMessage != null && summary == null) {
      return _InsightsErrorView(
        errorMessage: errorMessage,
        onRetry: notifier.refresh,
      );
    }

    return _InsightsContentList(
      notifier: notifier,
      summary: summary,
    );
  }
}

class _InsightsLoadingView extends StatelessWidget {
  const _InsightsLoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Loading momentum...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _InsightsErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const _InsightsErrorView({
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load insights',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('RETRY'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsContentList extends StatelessWidget {
  final InsightsNotifier notifier;
  final DailySummaryEntity? summary;

  const _InsightsContentList({
    required this.notifier,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errorMessage = notifier.errorMessage;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const _SectionHeader(title: "TODAY'S MOMENTUM"),
        const SizedBox(height: 8),
        _MomentumRow(
          focusMinutes: summary?.totalFocusMinutes ?? 0,
          completedCount: summary?.completedSessionsCount ?? 0,
        ),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'CURRENT STREAK'),
        const SizedBox(height: 8),
        StreakCard(streakDays: summary?.currentStreakDays ?? 0),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'RECENT SESSIONS'),
        const SizedBox(height: 8),
        SessionHistoryList(sessions: notifier.recentSessions),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'CONFIG & PREFERENCES'),
        const SizedBox(height: 8),
        _PreferencesCard(
          isDailyReminderEnabled: notifier.isDailyReminderEnabled,
          reminderHour: notifier.dailyReminderHour,
          reminderMinute: notifier.dailyReminderMinute,
          dailyReminderTime: notifier.dailyReminderTime,
          onReminderToggle: notifier.setDailyReminderEnabled,
          onReminderTimePick: notifier.setDailyReminderTime,
        ),
        const SizedBox(height: 20),
        const _ProBanner(),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _MomentumRow extends StatelessWidget {
  final int focusMinutes;
  final int completedCount;

  const _MomentumRow({
    required this.focusMinutes,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$focusMinutes MINS',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Locked In Today',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$completedCount',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sessions Finished',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  final bool isDailyReminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final TimeOfDay dailyReminderTime;
  final ValueChanged<bool> onReminderToggle;
  final void Function(int hour, int minute) onReminderTimePick;

  const _PreferencesCard({
    required this.isDailyReminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.dailyReminderTime,
    required this.onReminderToggle,
    required this.onReminderTimePick,
  });

  @override
  Widget build(BuildContext context) {
    final formattedHour = reminderHour.toString().padLeft(2, '0');
    final formattedMinute = reminderMinute.toString().padLeft(2, '0');
    final reminderTimeLabel = '$formattedHour:$formattedMinute';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            secondary: Icon(
              Icons.notifications_active_outlined,
              color: colorScheme.onSurface,
            ),
            title: Text(
              'Daily Focus Reminder',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              isDailyReminderEnabled
                  ? 'Scheduled daily at $reminderTimeLabel'
                  : 'Off (zero notification spam)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: isDailyReminderEnabled,
            activeThumbColor: colorScheme.primary,
            onChanged: onReminderToggle,
          ),
          if (isDailyReminderEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reminder Time',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(reminderTimeLabel),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: dailyReminderTime,
                      );
                      if (!context.mounted) return;
                      if (picked != null) {
                        onReminderTimePick(picked.hour, picked.minute);
                      }
                    },
                  ),
                ],
              ),
            ),
          Divider(color: colorScheme.outlineVariant, height: 1),
          const SoundscapeConfigTile(),
          Divider(color: colorScheme.outlineVariant, height: 1),
          ListTile(
            leading: Icon(
              Icons.timer_outlined,
              color: colorScheme.onSurface,
            ),
            title: Text(
              'Timer Intervals',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              '25m Focus · 5m Rest Break',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProBanner extends StatelessWidget {
  const _ProBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Text(
            '⭐',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIFETIME PRO: ACTIVE',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Zero subscriptions · Unlimited blocking & offline privacy',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
