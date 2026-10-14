import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';
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
        context.read<InsightsNotifier>().loadInsights();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<InsightsNotifier>();
    final summary = notifier.dailySummary;
    final theme = Theme.of(context);

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
        onRefresh: () => notifier.refresh(),
        color: AppColors.accentLockIn,
        backgroundColor: AppColors.surfaceRaised,
        child: _buildBody(context, notifier, summary),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    InsightsNotifier notifier,
    DailySummaryEntity? summary,
  ) {
    if (notifier.isLoading && summary == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Loading momentum...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    if (notifier.errorMessage != null && summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.accentHardLock,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load insights',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHighContrast,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                notifier.errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('RETRY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceRaised,
                  foregroundColor: AppColors.accentLockIn,
                  side: const BorderSide(color: AppColors.surfaceHairline),
                ),
                onPressed: () => notifier.refresh(),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (notifier.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentHardLock.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accentHardLock.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.accentHardLock,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    notifier.errorMessage!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textHighContrast,
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
          onReminderToggle: (val) => notifier.setDailyReminderEnabled(val),
          onReminderTimePick: (hour, minute) =>
              notifier.setDailyReminderTime(hour, minute),
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
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textMuted,
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
                      color: AppColors.accentLockIn,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Locked In Today',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
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
                      color: AppColors.textHighContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sessions Finished',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
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

    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            secondary: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.textHighContrast,
            ),
            title: Text(
              'Daily Focus Reminder',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textHighContrast,
              ),
            ),
            subtitle: Text(
              isDailyReminderEnabled
                  ? 'Scheduled daily at $reminderTimeLabel'
                  : 'Off (zero notification spam)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            value: isDailyReminderEnabled,
            activeThumbColor: AppColors.accentLockIn,
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
                      color: AppColors.textMuted,
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
          const Divider(color: AppColors.surfaceHairline, height: 1),
          ListTile(
            leading: const Icon(
              Icons.headphones_outlined,
              color: AppColors.textHighContrast,
            ),
            title: Text(
              'Ambient Audio',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textHighContrast,
              ),
            ),
            subtitle: Text(
              'Brown noise, 40Hz, Rain (Milestone 3)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            trailing: const Chip(
              label: Text(
                'Default',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.surfaceHairline,
            ),
          ),
          const Divider(color: AppColors.surfaceHairline, height: 1),
          ListTile(
            leading: const Icon(
              Icons.timer_outlined,
              color: AppColors.textHighContrast,
            ),
            title: Text(
              'Timer Intervals',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textHighContrast,
              ),
            ),
            subtitle: Text(
              '25m Focus · 5m Rest Break',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: AppColors.accentStreakGold.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 26)),
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
                    color: AppColors.accentStreakGold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Zero subscriptions · Unlimited blocking & offline privacy',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
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
