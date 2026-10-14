import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';
import 'package:focusmaxxing/core/utils/date_utils.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

class SessionHistoryList extends StatelessWidget {
  final List<SessionEntity> sessions;

  const SessionHistoryList({
    super.key,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.history_toggle_off_rounded,
                  size: 40,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'No focus sessions recorded yet',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHighContrast,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete a focus session to build your momentum.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sessions.length,
        separatorBuilder: (context, index) => const Divider(
          color: AppColors.surfaceHairline,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final session = sessions[index];
          return _SessionHistoryTile(session: session);
        },
      ),
    );
  }
}

class _SessionHistoryTile extends StatelessWidget {
  final SessionEntity session;

  const _SessionHistoryTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final statusBadge = _resolveStatusBadge(session.status);
    final durationText = session.actualDurationSeconds > 0
        ? TimeFormatter.formatDurationToMinutes(session.actualDurationSeconds)
        : TimeFormatter.formatDurationToMinutes(session.targetDurationSeconds);
    final timeStr = _formatSessionDateTime(session.startTimeEpochMs);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            statusBadge.emoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.taskGoal.isNotEmpty
                      ? session.taskGoal
                      : 'Focused Session',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHighContrast,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$durationText · ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: statusBadge.color,
                      ),
                    ),
                    Text(
                      statusBadge.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: statusBadge.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSessionDateTime(int epochMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final timeStr = TimeFormatter.formatTimestamp(epochMs);
    final now = DateTime.now();

    if (AppDateUtils.isSameDay(date, now)) {
      return timeStr;
    }

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (AppDateUtils.isSameDay(date, yesterday)) {
      return 'Yesterday, $timeStr';
    }

    return '${date.month}/${date.day}, $timeStr';
  }

  _StatusBadge _resolveStatusBadge(String status) {
    switch (status) {
      case SessionStatus.lockedIn:
        return const _StatusBadge(
          emoji: '🚀',
          label: 'Locked In',
          color: AppColors.accentLockIn,
        );
      case SessionStatus.derailed:
        return const _StatusBadge(
          emoji: '💀',
          label: 'Derailed',
          color: AppColors.accentHardLock,
        );
      case SessionStatus.cancelled:
        return const _StatusBadge(
          emoji: '⏹️',
          label: 'Cancelled',
          color: AppColors.textMuted,
        );
      default:
        return const _StatusBadge(
          emoji: '⏹️',
          label: 'Session',
          color: AppColors.textMuted,
        );
    }
  }
}

class _StatusBadge {
  final String emoji;
  final String label;
  final Color color;

  const _StatusBadge({
    required this.emoji,
    required this.label,
    required this.color,
  });
}
