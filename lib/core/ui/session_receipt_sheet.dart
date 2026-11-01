import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/core/ui/readout_row.dart';
import 'package:focusmaxxing/core/ui/tag.dart';
import 'package:focusmaxxing/core/utils/time_formatter.dart';

enum SessionRating { lockedIn, derailed }

enum SessionReceiptAction { rollIntoNext, takeBreak, done }

@immutable
class SessionReceiptResult {
  const SessionReceiptResult({
    required this.rating,
    required this.action,
  });

  final SessionRating rating;
  final SessionReceiptAction action;

  bool get lockedIn => rating == SessionRating.lockedIn;
  bool get endAllSessions => action == SessionReceiptAction.done;
  bool get rollIntoNext => action == SessionReceiptAction.rollIntoNext;
}

class SessionReceiptSheet extends StatefulWidget {
  const SessionReceiptSheet({
    super.key,
    required this.durationSeconds,
    required this.taskGoal,
    this.sessionNumber = 1,
    this.startTime,
    this.blockedAttempts = 0,
    this.todayTotalMinutes,
  });

  final int durationSeconds;
  final String taskGoal;
  final int sessionNumber;
  final DateTime? startTime;
  final int blockedAttempts;
  final int? todayTotalMinutes;

  static Future<SessionReceiptResult?> show(
    BuildContext context, {
    required int durationSeconds,
    required String taskGoal,
    int sessionNumber = 1,
    DateTime? startTime,
    int blockedAttempts = 0,
    int? todayTotalMinutes,
  }) {
    final isExpanded = MediaQuery.sizeOf(context).width >= 600;
    final content = PopScope(
      canPop: false,
      child: SessionReceiptSheet(
        durationSeconds: durationSeconds,
        taskGoal: taskGoal,
        sessionNumber: sessionNumber,
        startTime: startTime,
        blockedAttempts: blockedAttempts,
        todayTotalMinutes: todayTotalMinutes,
      ),
    );

    if (isExpanded) {
      return showDialog<SessionReceiptResult>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final tokens = ctx.tokens;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(InstrumentTokens.r2),
                  border: Border.all(color: tokens.ruleStrong, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: content,
              ),
            ),
          );
        },
      );
    }

    return showModalBottomSheet<SessionReceiptResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => content,
    );
  }

  @override
  State<SessionReceiptSheet> createState() => _SessionReceiptSheetState();
}

class _SessionReceiptSheetState extends State<SessionReceiptSheet> {
  SessionRating _rating = SessionRating.lockedIn;

  String _formatStartedTime() {
    final start = widget.startTime ??
        DateTime.now().subtract(Duration(seconds: widget.durationSeconds));
    final hh = start.hour.toString().padLeft(2, '0');
    final mm = start.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatTodayTotal() {
    final totalMinutes = widget.todayTotalMinutes ?? (widget.durationSeconds ~/ 60);
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins.toString().padLeft(2, '0')}m';
    }
    return '${mins}m';
  }

  void _finishWith(SessionReceiptAction action) {
    unawaited(HapticFeedback.selectionClick());
    Navigator.of(context).pop(
      SessionReceiptResult(rating: _rating, action: action),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final durationFormatted = TimeFormatter.formatMMSS(widget.durationSeconds);
    final cleanGoal = widget.taskGoal.trim().isEmpty ? 'Focus block' : widget.taskGoal.trim();

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(InstrumentTokens.r3),
        ),
        border: Border(
          top: BorderSide(color: tokens.rule, width: 1),
          left: BorderSide(color: tokens.rule, width: 1),
          right: BorderSide(color: tokens.rule, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        InstrumentTokens.gutter,
        InstrumentTokens.s12,
        InstrumentTokens.gutter,
        InstrumentTokens.s24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.ruleStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: InstrumentTokens.s16),
            Text(
              AppStrings.sessionComplete(widget.sessionNumber),
              style: TextStyle(
                fontFamily: InstrumentTokens.fontMono,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: tokens.ink,
              ),
            ),
            const SizedBox(height: InstrumentTokens.s8),
            Container(height: 1, color: tokens.rule),
            const SizedBox(height: InstrumentTokens.s4),
            ReadoutRow(
              label: cleanGoal,
              value: durationFormatted,
              showDivider: false,
            ),
            ReadoutRow(
              label: AppStrings.started,
              value: _formatStartedTime(),
              showDivider: false,
            ),
            ReadoutRow(
              label: AppStrings.blockedAttempts,
              value: widget.blockedAttempts.toString(),
              showDivider: false,
            ),
            ReadoutRow(
              label: AppStrings.todayTotal,
              value: _formatTodayTotal(),
              showDivider: false,
            ),
            const SizedBox(height: InstrumentTokens.s4),
            Container(height: 1, color: tokens.rule),
            const SizedBox(height: InstrumentTokens.s16),
            Text(
              AppStrings.didYouLockIn,
              style: TextStyle(
                fontFamily: InstrumentTokens.fontUi,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: tokens.inkMuted,
              ),
            ),
            const SizedBox(height: InstrumentTokens.s12),
            Row(
              children: [
                Expanded(
                  child: Tag(
                    label: AppStrings.ratingDerailed,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: _rating == SessionRating.derailed
                          ? tokens.bg
                          : tokens.danger,
                    ),
                    isSelected: _rating == SessionRating.derailed,
                    onTap: () => setState(() => _rating = SessionRating.derailed),
                  ),
                ),
                const SizedBox(width: InstrumentTokens.s12),
                Expanded(
                  child: Tag(
                    label: AppStrings.ratingLockedIn,
                    icon: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: _rating == SessionRating.lockedIn
                          ? tokens.bg
                          : tokens.accent,
                    ),
                    isSelected: _rating == SessionRating.lockedIn,
                    onTap: () => setState(() => _rating = SessionRating.lockedIn),
                  ),
                ),
              ],
            ),
            const SizedBox(height: InstrumentTokens.s24),
            InstrumentButton.primary(
              key: const Key('celebration_roll_next_button'),
              label: AppStrings.startAnother25,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: () => _finishWith(SessionReceiptAction.rollIntoNext),
            ),
            const SizedBox(height: InstrumentTokens.s12),
            Row(
              children: [
                Expanded(
                  child: InstrumentButton.secondary(
                    key: const Key('celebration_take_break_button'),
                    label: AppStrings.break5Min,
                    icon: const Icon(Icons.coffee_outlined, size: 16),
                    onPressed: () => _finishWith(SessionReceiptAction.takeBreak),
                  ),
                ),
                const SizedBox(width: InstrumentTokens.s12),
                Expanded(
                  child: InstrumentButton.text(
                    key: const Key('checkin_end_all_sessions_button'),
                    label: AppStrings.done,
                    onPressed: () => _finishWith(SessionReceiptAction.done),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
