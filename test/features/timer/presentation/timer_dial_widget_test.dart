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
    testWidgets('renders formatted time and task goal in active mode',
        (tester) async {
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

    testWidgets('renders rest mode prompt when isRestMode is true',
        (tester) async {
      await tester.pumpWidget(buildWidget(
        remainingSeconds: 300,
        totalSeconds: 300,
        isRestMode: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('RECHARGE YOUR BRAIN'), findsOneWidget);
    });

    testWidgets(
        'displays ROTATE TO SET TIME when onDurationChanged is provided and goal is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimerDialWidget(
              remainingSeconds: 1500,
              totalSeconds: 1500,
              onDurationChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ROTATE TO SET TIME'), findsOneWidget);
    });

    testWidgets('circular drag calls onDurationChanged with snapped seconds',
        (tester) async {
      int? changedSeconds;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimerDialWidget(
              remainingSeconds: 1500,
              totalSeconds: 1500,
              onDurationChanged: (val) => changedSeconds = val,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dialFinder = find.byType(TimerDialWidget);
      final center = tester.getCenter(dialFinder);

      // Drag from top (12 o'clock) to right (3 o'clock, 15 minutes = 900s)
      final gesture = await tester.startGesture(center + const Offset(0, -100));
      await gesture.moveTo(center + const Offset(100, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(changedSeconds, isNotNull);
      expect(changedSeconds, 15 * 60);
    });

    testWidgets(
        'renders correct dial progress for interactive setting mode vs active countdown',
        (tester) async {
      // Interactive mode with 30 minutes (1800s) on 60m face -> 0.5 progress
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimerDialWidget(
              remainingSeconds: 1800,
              totalSeconds: 1800,
              onDurationChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dialPaintFinder = find.descendant(
        of: find.byType(TimerDialWidget),
        matching: find.byType(CustomPaint),
      );
      var customPaint = tester.widget<CustomPaint>(dialPaintFinder);
      dynamic painter = customPaint.painter;
      expect(painter.progress as double, closeTo(0.5, 0.01));

      // Active running mode with 1500s total, 750s remaining -> 0.5 progress
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TimerDialWidget(
              remainingSeconds: 750,
              totalSeconds: 1500,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      customPaint = tester.widget<CustomPaint>(dialPaintFinder);
      painter = customPaint.painter;
      expect(painter.progress as double, closeTo(0.5, 0.01));
    });
  });
}
