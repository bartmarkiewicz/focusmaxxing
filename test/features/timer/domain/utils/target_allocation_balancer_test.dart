import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';
import 'package:focusmaxxing/features/timer/domain/utils/target_allocation_balancer.dart';

void main() {
  group('TargetAllocationBalancer', () {
    test('defaultSplit returns uniform splits', () {
      expect(TargetAllocationBalancer.defaultSplit(1), [100]);
      expect(TargetAllocationBalancer.defaultSplit(2), [50, 50]);
      expect(TargetAllocationBalancer.defaultSplit(3), [33, 33, 34]);
      expect(
        TargetAllocationBalancer.defaultSplit(3).reduce((a, b) => a + b),
        100,
      );
    });

    group('calculateAllocatedSeconds', () {
      test('allocates 100% of duration to single target', () {
        final result = TargetAllocationBalancer.calculateAllocatedSeconds(
          totalSeconds: 1500,
          percentages: [100],
        );
        expect(result, [1500]);
      });

      test('allocates 50/50 evenly with zero remainder', () {
        final result = TargetAllocationBalancer.calculateAllocatedSeconds(
          totalSeconds: 1500,
          percentages: [50, 50],
        );
        expect(result, [750, 750]);
        expect(result[0] + result[1], 1500);
      });

      test('allocates 3-way split 33/33/34 and adds remainder to primary target', () {
        // 1500 * 0.33 = 495
        // 1500 * 0.33 = 495
        // 1500 * 0.34 = 510
        // Sum = 1500 (remainder = 0)
        final result = TargetAllocationBalancer.calculateAllocatedSeconds(
          totalSeconds: 1500,
          percentages: [33, 33, 34],
        );
        expect(result, [495, 495, 510]);
        expect(result.reduce((a, b) => a + b), 1500);
      });

      test('odd duration with rounding remainder strictly sums to totalSeconds', () {
        // 1501 seconds split [33, 33, 34]
        // 1501 * 0.33 = 495.33 -> 495
        // 1501 * 0.33 = 495.33 -> 495
        // 1501 * 0.34 = 510.34 -> 510
        // Sum = 1500. Remainder = 1.
        // Remainder added to index 0 -> 496, 495, 510. Total = 1501.
        final result = TargetAllocationBalancer.calculateAllocatedSeconds(
          totalSeconds: 1501,
          percentages: [33, 33, 34],
        );
        expect(result, [496, 495, 510]);
        expect(result.reduce((a, b) => a + b), 1501);
      });

      test('returns 0 for zero or negative totalSeconds', () {
        final result = TargetAllocationBalancer.calculateAllocatedSeconds(
          totalSeconds: 0,
          percentages: [50, 50],
        );
        expect(result, [0, 0]);
      });
    });

    group('rebalancePercentages', () {
      test('2 targets: dragging target 0 to 70 adjusts target 1 to 30', () {
        final result = TargetAllocationBalancer.rebalancePercentages(
          currentPercentages: [50, 50],
          changedIndex: 0,
          newPercentage: 70,
        );
        expect(result, [70, 30]);
        expect(result.reduce((a, b) => a + b), 100);
      });

      test('2 targets: dragging target 1 to 20 adjusts target 0 to 80', () {
        final result = TargetAllocationBalancer.rebalancePercentages(
          currentPercentages: [50, 50],
          changedIndex: 1,
          newPercentage: 20,
        );
        expect(result, [80, 20]);
        expect(result.reduce((a, b) => a + b), 100);
      });

      test('3 targets: dragging any slider rebalances others proportionally', () {
        final result = TargetAllocationBalancer.rebalancePercentages(
          currentPercentages: [33, 33, 34],
          changedIndex: 0,
          newPercentage: 60,
        );
        expect(result[0], 60);
        expect(result.reduce((a, b) => a + b), 100);
      });

      test('3 targets: clamps to at least 1% and at most 98%', () {
        final result = TargetAllocationBalancer.rebalancePercentages(
          currentPercentages: [33, 33, 34],
          changedIndex: 0,
          newPercentage: 100,
        );
        expect(result[0], 98);
        expect(result[1], 1);
        expect(result[2], 1);
        expect(result.reduce((a, b) => a + b), 100);
      });

      test('3 targets: dragging to 97% strictly sums to 100% without rounding overflow', () {
        final result = TargetAllocationBalancer.rebalancePercentages(
          currentPercentages: [33, 33, 34],
          changedIndex: 0,
          newPercentage: 97,
        );
        expect(result[0], 97);
        expect(result.reduce((a, b) => a + b), 100);
        expect(result.every((p) => p >= 1), isTrue);
      });

      test('3 targets: exhaustive check that every integer slider value 1..98 strictly sums to 100', () {
        for (var p = 1; p <= 98; p++) {
          final result = TargetAllocationBalancer.rebalancePercentages(
            currentPercentages: [33, 33, 34],
            changedIndex: 0,
            newPercentage: p,
          );
          expect(result.reduce((a, b) => a + b), 100, reason: 'Failed for p=$p');
          expect(result.every((val) => val >= 1), isTrue, reason: 'Failed min check for p=$p');
        }
      });
    });

    group('formatAnchorPillText', () {
      test('returns empty for no targets', () {
        expect(TargetAllocationBalancer.formatAnchorPillText(const []), '');
      });

      test('formats single target', () {
        const targets = [
          SessionTargetAllocation(targetName: 'Mobile UI', percentage: 100),
        ];
        expect(
          TargetAllocationBalancer.formatAnchorPillText(targets),
          'Mobile UI',
        );
      });

      test('formats 2 targets with percentages', () {
        const targets = [
          SessionTargetAllocation(targetName: 'Mobile UI', percentage: 60),
          SessionTargetAllocation(targetName: 'API Refactor', percentage: 40),
        ];
        expect(
          TargetAllocationBalancer.formatAnchorPillText(targets),
          'Mobile UI (60%) • API Refactor (40%)',
        );
      });

      test('formats 3 targets with primary and count', () {
        const targets = [
          SessionTargetAllocation(targetName: 'Mobile UI', percentage: 50),
          SessionTargetAllocation(targetName: 'API Refactor', percentage: 30),
          SessionTargetAllocation(targetName: 'Tests', percentage: 20),
        ];
        expect(
          TargetAllocationBalancer.formatAnchorPillText(targets),
          'Mobile UI • +2 targets',
        );
      });
    });
  });
}
