import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/ui/session_receipt_sheet.dart';

@immutable
class SessionCheckInResult {
  const SessionCheckInResult({
    required this.lockedIn,
    this.endAllSessions = false,
  });

  final bool lockedIn;
  final bool endAllSessions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionCheckInResult &&
          runtimeType == other.runtimeType &&
          lockedIn == other.lockedIn &&
          endAllSessions == other.endAllSessions;

  @override
  int get hashCode => Object.hash(lockedIn, endAllSessions);
}

class SessionCheckInDialog extends StatelessWidget {
  const SessionCheckInDialog({
    super.key,
    required this.durationSeconds,
    required this.taskGoal,
  });

  final int durationSeconds;
  final String taskGoal;

  static Future<bool?> show(
    BuildContext context, {
    required int durationSeconds,
    required String taskGoal,
  }) async {
    final result = await showWithOutcome(
      context,
      durationSeconds: durationSeconds,
      taskGoal: taskGoal,
    );
    return result?.lockedIn;
  }

  static Future<SessionCheckInResult?> showWithOutcome(
    BuildContext context, {
    required int durationSeconds,
    required String taskGoal,
    int sessionNumber = 1,
    int? todayTotalMinutes,
    int blockedAttempts = 0,
  }) async {
    final receiptResult = await SessionReceiptSheet.show(
      context,
      durationSeconds: durationSeconds,
      taskGoal: taskGoal,
      sessionNumber: sessionNumber,
      todayTotalMinutes: todayTotalMinutes,
      blockedAttempts: blockedAttempts,
    );

    if (receiptResult == null) return null;
    return SessionCheckInResult(
      lockedIn: receiptResult.lockedIn,
      endAllSessions: receiptResult.endAllSessions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionReceiptSheet(
      durationSeconds: durationSeconds,
      taskGoal: taskGoal,
    );
  }
}
