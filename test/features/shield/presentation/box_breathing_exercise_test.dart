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

  double circleScale(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byKey(const Key('breathing_circle')),
            matching: find.byType(Transform),
          )
          .last,
    );
    return transform.transform.storage[0];
  }

  testWidgets('starts in inhale phase with a contracted circle',
      (tester) async {
    await tester.pumpWidget(buildExercise(onComplete: () {}));

    expect(phaseLabel(tester), 'INHALE');
    expect(circleScale(tester), closeTo(0.45, 0.01));
    expect(find.text('16s'), findsOneWidget);
  });

  testWidgets('cycles inhale, hold, exhale, hold across four phases',
      (tester) async {
    await tester.pumpWidget(buildExercise(onComplete: () {}));

    await tester.pump(const Duration(seconds: 3));
    expect(phaseLabel(tester), 'INHALE');
    expect(circleScale(tester), greaterThan(0.8));

    await tester.pump(const Duration(seconds: 2));
    expect(phaseLabel(tester), 'HOLD');
    expect(circleScale(tester), closeTo(1.0, 0.001));

    await tester.pump(const Duration(seconds: 4));
    expect(phaseLabel(tester), 'EXHALE');

    await tester.pump(const Duration(seconds: 4));
    expect(phaseLabel(tester), 'HOLD');
    expect(circleScale(tester), closeTo(0.45, 0.001));
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
