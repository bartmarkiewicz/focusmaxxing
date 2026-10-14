import 'package:flutter/material.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 40,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'No focus sessions recorded yet',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete a focus session to build your momentum.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (int i = 0; i < sessions.length; i++) ...[
            if (i > 0)
              Divider(
                color: colorScheme.outlineVariant,
                height: 1,
              ),
            _SessionHistoryTile(session: sessions[i]),
          ],
        ],
      ),
    );
  }
}

class _SessionHistoryTile extends StatelessWidget {
  const _SessionHistoryTile({required this.session});

  final SessionEntity session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusBadge = _resolveStatusBadge(session.status, colorScheme);
    final durationText = session.actualDurationSeconds > 0
        ? TimeFormatter.formatDurationToMinutes(session.actualDurationSeconds)
        : TimeFormatter.formatDurationToMinutes(session.targetDurationSeconds);
    final timeStr = _formatSessionDateTime(session.startTimeEpochMs);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
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
                    color: colorScheme.onSurface,
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
              color: colorScheme.onSurfaceVariant,
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

  _StatusBadge _resolveStatusBadge(String status, ColorScheme colorScheme) {
    switch (status) {
      case SessionStatus.lockedIn:
        return _StatusBadge(
          emoji: '🚀',
          label: 'Locked In',
          color: colorScheme.primary,
        );
      case SessionStatus.derailed:
        return _StatusBadge(
          emoji: '💀',
          label: 'Derailed',
          color: colorScheme.error,
        );
      case SessionStatus.cancelled:
        return _StatusBadge(
          emoji: '⏹️',
          label: 'Cancelled',
          color: colorScheme.onSurfaceVariant,
        );
      default:
        return _StatusBadge(
          emoji: '⏹️',
          label: 'Session',
          color: colorScheme.onSurfaceVariant,
        );
    }
  }
}

class _StatusBadge {
  const _StatusBadge({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String label;
  final Color color;
}
