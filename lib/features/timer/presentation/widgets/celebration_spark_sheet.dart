import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/ui/session_receipt_sheet.dart';

@immutable
class CelebrationResult {
  final bool rollIntoNext;

  const CelebrationResult({this.rollIntoNext = false});
}

/// Legacy wrapper; celebration is now merged into [SessionReceiptSheet].
class CelebrationSparkSheet extends StatelessWidget {
  const CelebrationSparkSheet({
    super.key,
    required this.durationMinutes,
    required this.taskGoal,
  });

  final int durationMinutes;
  final String taskGoal;

  static Future<CelebrationResult?> show(
    BuildContext context, {
    required int durationMinutes,
    required String taskGoal,
  }) async {
    final result = await SessionReceiptSheet.show(
      context,
      durationSeconds: durationMinutes * 60,
      taskGoal: taskGoal,
    );
    if (result == null) return null;
    return CelebrationResult(rollIntoNext: result.rollIntoNext);
  }

  @override
  Widget build(BuildContext context) {
    return SessionReceiptSheet(
      durationSeconds: durationMinutes * 60,
      taskGoal: taskGoal,
    );
  }
}
