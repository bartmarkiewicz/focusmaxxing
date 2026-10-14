import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/timer_dial_widget.dart';

void main() {
  Widget buildWidget({
    required int remainingSeconds,
    required int totalSeconds,
    String? taskGoal,
    bool isPaused = false,
    bool isRestMode = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TimerDialWidget(
          remainingSeconds: remainingSeconds,
          totalSeconds: totalSeconds,
          taskGoal: taskGoal,
          isPaused: isPaused,
          isRestMode: isRestMode,
        ),
      ),
    );
  }

  group('TimerDialWidget', () {
    testWidgets('renders formatted time and task goal in active mode', (tester) async {
      await tester.pumpWidget(buildWidget(
        remainingSeconds: 1475,
        totalSeconds: 1500,
        taskGoal: 'Clean Architecture Refactor',
      ));
      await tester.pumpAndSettle();

      expect(find.text('24:35'), findsOneWidget);
      expect(find.text('"Clean Architecture Refactor"'), findsOneWidget);
      expect(find.text('PAUSED'), findsNothing);
    });

    testWidgets('renders PAUSED chip when isPaused is true', (tester) async {
      await tester.pumpWidget(buildWidget(
        remainingSeconds: 900,
        totalSeconds: 1500,
        isPaused: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('PAUSED'), findsOneWidget);
    });

    testWidgets('renders rest mode prompt when isRestMode is true', (tester) async {
      await tester.pumpWidget(buildWidget(
        remainingSeconds: 300,
        totalSeconds: 300,
        isRestMode: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('RECHARGE YOUR BRAIN'), findsOneWidget);
    });
  });
}
