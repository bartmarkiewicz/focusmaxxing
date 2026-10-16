import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/schedule/presentation/notifiers/schedule_notifier.dart';
import 'package:provider/provider.dart';

class ScheduleConfigSection extends StatelessWidget {
  final ScheduleNotifier? notifier;
  final bool? isProUnlocked;

  const ScheduleConfigSection({
    super.key,
    this.notifier,
    this.isProUnlocked,
  });

  static const List<({int day, String label})> _weekdays = [
    (day: DateTime.monday, label: 'Mon'),
    (day: DateTime.tuesday, label: 'Tue'),
    (day: DateTime.wednesday, label: 'Wed'),
    (day: DateTime.thursday, label: 'Thu'),
    (day: DateTime.friday, label: 'Fri'),
    (day: DateTime.saturday, label: 'Sat'),
    (day: DateTime.sunday, label: 'Sun'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheduleNotifier = notifier ?? context.watch<ScheduleNotifier?>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (scheduleNotifier == null) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: scheduleNotifier,
      builder: (context, _) {
        final schedule = scheduleNotifier.schedule;
        final isEnabled = schedule.isEnabled;
        final proUnlocked = isProUnlocked ?? scheduleNotifier.isPro;
        final errorMessage = scheduleNotifier.errorMessage;

        final formattedStart = schedule.formattedStartTime;
        final formattedEnd = schedule.formattedEndTime;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          SwitchListTile.adaptive(
            key: const ValueKey('schedule_master_switch'),
            secondary: Icon(
              Icons.schedule_rounded,
              color: colorScheme.onSurface,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Scheduled Auto-Shield',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (!proUnlocked) ...[
                  const SizedBox(width: 8),
                  const _ScheduleProBadge(
                    key: ValueKey('schedule_pro_badge'),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              isEnabled
                  ? 'Active ${schedule.formattedTimeRange}'
                  : 'Automatically block social feeds during work/study hours',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: isEnabled,
            activeThumbColor: colorScheme.primary,
            onChanged: (value) {
              unawaited(scheduleNotifier.setEnabled(value));
            },
          ),
          if (scheduleNotifier.requiresProPrompt) ...[
            const SizedBox(height: 6),
            _ScheduleProGateBanner(
              onDismiss: scheduleNotifier.dismissProPrompt,
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 6),
            _ScheduleErrorBanner(
              message: errorMessage,
              onDismiss: scheduleNotifier.clearError,
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _TimePickerButton(
                    key: const ValueKey('schedule_start_time_btn'),
                    label: 'Start Time',
                    timeText: formattedStart,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: schedule.startHour,
                          minute: schedule.startMinute,
                        ),
                      );
                      if (context.mounted && picked != null) {
                        unawaited(
                          scheduleNotifier.setStartTime(
                            picked.hour,
                            picked.minute,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerButton(
                    key: const ValueKey('schedule_end_time_btn'),
                    label: 'End Time',
                    timeText: formattedEnd,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: schedule.endHour,
                          minute: schedule.endMinute,
                        ),
                      );
                      if (context.mounted && picked != null) {
                        unawaited(
                          scheduleNotifier.setEndTime(
                            picked.hour,
                            picked.minute,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Days',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in _weekdays)
                      _WeekdayChip(
                        key: ValueKey('weekday_chip_${item.day}'),
                        label: item.label,
                        isSelected: schedule.isActiveOn(item.day),
                        onTap: () {
                          unawaited(scheduleNotifier.toggleWeekday(item.day));
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  final String label;
  final String timeText;
  final VoidCallback onTap;

  const _TimePickerButton({
    super.key,
    required this.label,
    required this.timeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: '$label: $timeText',
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(kMinInteractiveDimension, 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WeekdayChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 44,
        minHeight: kMinInteractiveDimension,
      ),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: colorScheme.primary.withValues(alpha: 0.22),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ScheduleProBadge extends StatelessWidget {
  const _ScheduleProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 13,
            color: colorScheme.tertiary,
          ),
          const SizedBox(width: 4),
          Text(
            'PRO',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleProGateBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const _ScheduleProGateBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        key: const ValueKey('schedule_pro_gate_banner'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.tertiary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.tertiary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.star_rounded,
              color: colorScheme.tertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Scheduled Auto-Shield is a Lifetime Pro feature.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onDismiss,
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ScheduleErrorBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        key: const ValueKey('schedule_error_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Clear error',
            ),
          ],
        ),
      ),
    );
  }
}
