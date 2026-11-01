import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/box_breathing_exercise.dart';

void main() {
  Widget buildExercise({
    required VoidCallback onComplete,
    Duration total = const Duration(seconds: 16),
    Duration phase = const Duration(seconds: 4),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BoxBreathingExercise(
          totalDuration: total,
          phaseDuration: phase,
          enableHaptics: false,
          onComplete: onComplete,
        ),
      ),
    );
  }

  String phaseLabel(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('breathing_phase_label')))
      .data!;

  testWidgets('starts in inhale phase with square trace painter',
      (tester) async {
    await tester.pumpWidget(buildExercise(onComplete: () {}));

    expect(phaseLabel(tester), 'IN');
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('4s In · 4s Hold · 4s Out · 4s Hold'), findsOneWidget);
  });

  testWidgets('cycles inhale, hold, exhale, hold across four phases',
      (tester) async {
    await tester.pumpWidget(buildExercise(onComplete: () {}));

    await tester.pump(const Duration(seconds: 3));
    expect(phaseLabel(tester), 'IN');

    await tester.pump(const Duration(seconds: 2));
    expect(phaseLabel(tester), 'HOLD');

    await tester.pump(const Duration(seconds: 4));
    expect(phaseLabel(tester), 'OUT');

    await tester.pump(const Duration(seconds: 4));
    expect(phaseLabel(tester), 'HOLD');
  });

  testWidgets('invokes onComplete exactly once after total duration',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(buildExercise(onComplete: () => completions++));

    await tester.pump(const Duration(seconds: 15));
    expect(completions, 0);

    await tester.pump(const Duration(seconds: 2));
    expect(completions, 1);

    await tester.pump(const Duration(seconds: 5));
    expect(completions, 1);
  });

  testWidgets('does not complete when disposed mid-exercise', (tester) async {
    var completions = 0;
    await tester.pumpWidget(buildExercise(onComplete: () => completions++));
    await tester.pump(const Duration(seconds: 5));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));

    expect(completions, 0);
  });
}
