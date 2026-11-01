import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';

abstract final class TargetAllocationBalancer {
  static const int maxTargets = 3;

  /// Returns uniform percentage splits for [count] targets (up to 3).
  static List<int> defaultSplit(int count) {
    if (count <= 1) return const [100];
    if (count == 2) return const [50, 50];
    return const [33, 33, 34];
  }

  /// Calculates exact allocated seconds per target according to Section 4.1.
  ///
  /// Each target receives floor(totalSeconds * percentage / 100).
  /// The remainder is added to the primary target (index 0) so that
  /// the sum of allocated seconds strictly matches [totalSeconds].
  static List<int> calculateAllocatedSeconds({
    required int totalSeconds,
    required List<int> percentages,
  }) {
    if (percentages.isEmpty) return const [];
    if (totalSeconds <= 0) {
      return List<int>.filled(percentages.length, 0);
    }
    if (percentages.length == 1) {
      return [totalSeconds];
    }

    final allocated = <int>[];
    var sum = 0;

    for (var i = 0; i < percentages.length; i++) {
      final p = percentages[i];
      final seconds = (totalSeconds * (p / 100.0)).floor();
      allocated.add(seconds);
      sum += seconds;
    }

    final remainder = totalSeconds - sum;
    if (remainder > 0 && allocated.isNotEmpty) {
      allocated[0] += remainder;
    }

    return allocated;
  }

  /// Auto-balances linked slider percentages when the user drags slider [changedIndex]
  /// to [newPercentage], following Section 4.2.
  static List<int> rebalancePercentages({
    required List<int> currentPercentages,
    required int changedIndex,
    required int newPercentage,
  }) {
    final count = currentPercentages.length;
    if (count <= 1) return const [100];

    // Each target in a multi-target split must have at least 1% and at most 100 - (count - 1) * 1%
    const minAllowed = 1;
    final maxAllowed = 100 - (count - 1) * minAllowed;
    final clampedNew = newPercentage.clamp(minAllowed, maxAllowed);

    if (count == 2) {
      final otherIndex = changedIndex == 0 ? 1 : 0;
      final result = List<int>.filled(2, 0);
      result[changedIndex] = clampedNew;
      result[otherIndex] = 100 - clampedNew;
      return result;
    }

    // count == 3
    final result = List<int>.from(currentPercentages);
    result[changedIndex] = clampedNew;

    final remainder = 100 - clampedNew;
    final otherIndices = [0, 1, 2]..remove(changedIndex);
    final firstOther = otherIndices[0];
    final secondOther = otherIndices[1];
    final maxForFirst = remainder - minAllowed;

    final sOther = currentPercentages[firstOther] + currentPercentages[secondOther];

    final int share0;
    if (sOther > 0) {
      share0 = (remainder * (currentPercentages[firstOther] / sOther))
          .round()
          .clamp(minAllowed, maxForFirst);
    } else {
      share0 = (remainder / 2.0).round().clamp(minAllowed, maxForFirst);
    }

    result[firstOther] = share0;
    result[secondOther] = remainder - share0;

    return result;
  }

  /// Formats targets for idle pill display according to Section 3.2.
  static String formatAnchorPillText(List<SessionTargetAllocation> targets) {
    if (targets.isEmpty) {
      return '';
    }
    if (targets.length == 1) {
      return '🎯 ${targets.first.targetName}';
    }
    if (targets.length == 2) {
      return '🎯 ${targets[0].targetName} (${targets[0].percentage}%) • ${targets[1].targetName} (${targets[1].percentage}%)';
    }
    return '🎯 ${targets[0].targetName} • +${targets.length - 1} targets';
  }

  /// Summarizes targets into a single string for legacy session task_goal column.
  static String formatGoalSummary(List<SessionTargetAllocation> targets) {
    if (targets.isEmpty) return 'Deep Work';
    return targets.map((t) => t.targetName).join(' • ');
  }
}
