import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/utils/date_utils.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_entity.dart';

/// Renders session history as physical instrument list rows grouped by date.
class SessionHistoryList extends StatelessWidget {
  final List<SessionEntity> sessions;

  const SessionHistoryList({
    super.key,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    if (sessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          vertical: InstrumentTokens.s32,
          horizontal: InstrumentTokens.gutter,
        ),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(InstrumentTokens.r2),
          border: Border.all(color: tokens.rule, width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NO SESSIONS RECORDED',
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: tokens.inkMuted,
                ),
              ),
              const SizedBox(height: InstrumentTokens.s8),
              Text(
                AppStrings.insightsNoSessions,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontUi,
                  fontSize: 13,
                  color: tokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = _groupSessionsByDate(sessions);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InstrumentTokens.r2),
        border: Border.all(color: tokens.rule, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in grouped.entries) ...[
            _DateGroupHeader(label: entry.key),
            for (int i = 0; i < entry.value.length; i++) ...[
              _SessionInstrumentRow(session: entry.value[i]),
              if (i < entry.value.length - 1)
                Divider(color: tokens.rule, height: 1, thickness: 1),
            ],
          ],
        ],
      ),
    );
  }

  Map<String, List<SessionEntity>> _groupSessionsByDate(
    List<SessionEntity> list,
  ) {
    final map = <String, List<SessionEntity>>{};
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    for (final session in list) {
      final date =
          DateTime.fromMillisecondsSinceEpoch(session.startTimeEpochMs);
      String key;
      if (AppDateUtils.isSameDay(date, now)) {
        key = 'TODAY';
      } else if (AppDateUtils.isSameDay(date, yesterday)) {
        key = 'YESTERDAY';
      } else {
        key = '${_monthName(date.month)} ${date.day}'.toUpperCase();
      }
      map.putIfAbsent(key, () => []).add(session);
    }
    return map;
  }

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}

class _DateGroupHeader extends StatelessWidget {
  final String label;

  const _DateGroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InstrumentTokens.gutter,
        vertical: InstrumentTokens.s8,
      ),
      color: tokens.bg,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: InstrumentTokens.fontMono,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: tokens.inkMuted,
        ),
      ),
    );
  }
}

class _SessionInstrumentRow extends StatelessWidget {
  final SessionEntity session;

  const _SessionInstrumentRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final timeStr = TimeFormatter.formatTimestamp(session.startTimeEpochMs);
    final durationSeconds = (session.actualDurationSeconds > 0 ||
            session.status == SessionStatus.cancelled)
        ? session.actualDurationSeconds
        : session.targetDurationSeconds;

    final durationFormatted =
        TimeFormatter.formatDurationToMinutes(durationSeconds);
    final (statusGlyph, statusColor) = _resolveStatus(tokens);

    final goal = session.taskGoal.isNotEmpty
        ? session.taskGoal
        : 'Focused session';

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: InstrumentTokens.gutter,
        vertical: InstrumentTokens.s12,
      ),
      child: Row(
        children: [
          // Time in mono
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: InstrumentTokens.fontMono,
              fontSize: 12,
              color: tokens.inkMuted,
            ),
          ),
          const SizedBox(width: InstrumentTokens.s12),
          // Goal
          Expanded(
            child: Text(
              goal,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: InstrumentTokens.fontUi,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: tokens.ink,
              ),
            ),
          ),
          const SizedBox(width: InstrumentTokens.s8),
          // Duration
          Text(
            durationFormatted,
            style: TextStyle(
              fontFamily: InstrumentTokens.fontMono,
              fontSize: 12,
              color: tokens.inkMuted,
            ),
          ),
          const SizedBox(width: InstrumentTokens.s8),
          // Status glyph
          Text(
            statusGlyph,
            style: TextStyle(
              fontFamily: InstrumentTokens.fontMono,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _resolveStatus(InstrumentTokens tokens) {
    switch (session.status) {
      case SessionStatus.lockedIn:
        return ('✓', tokens.ok);
      case SessionStatus.cancelled:
        return ('—', tokens.inkMuted);
      case SessionStatus.derailed:
        return ('×', tokens.danger);
      default:
        return ('✓', tokens.ok);
    }
  }
}
