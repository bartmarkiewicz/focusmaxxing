import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/session_checkin_dialog.dart';

void main() {
  Widget buildDialog({
    required int durationSeconds,
    required String taskGoal,
    ValueChanged<bool?>? onResult,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await SessionCheckInDialog.show(
                context,
                durationSeconds: durationSeconds,
                taskGoal: taskGoal,
              );
              onResult?.call(result);
            },
            child: const Text('SHOW DIALOG'),
          ),
        ),
      ),
    );
  }

  group('SessionCheckInDialog', () {
    testWidgets('renders duration, goal, and binary options', (tester) async {
      await tester.pumpWidget(buildDialog(
        durationSeconds: 1500,
        taskGoal: 'Refactor Session',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SHOW DIALOG'));
      await tester.pumpAndSettle();

      expect(find.text('Refactor Session'), findsOneWidget);
      expect(find.text('Did you lock in?'), findsOneWidget);
      expect(find.text('Locked in'), findsOneWidget);
      expect(find.text('Derailed'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('tapping LOCKED IN returns true', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(buildDialog(
        durationSeconds: 1500,
        taskGoal: 'Refactor Session',
        onResult: (res) => dialogResult = res,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SHOW DIALOG'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('tapping DERAILED returns false', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(buildDialog(
        durationSeconds: 1500,
        taskGoal: 'Distracted Session',
        onResult: (res) => dialogResult = res,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SHOW DIALOG'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Derailed'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });

    testWidgets(
        'showWithOutcome returns lockedIn true and endAllSessions true when tapping LOCKED IN & END ALL SESSIONS',
        (tester) async {
      SessionCheckInResult? outcome;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  outcome = await SessionCheckInDialog.showWithOutcome(
                    context,
                    durationSeconds: 1500,
                    taskGoal: 'Final Session',
                  );
                },
                child: const Text('SHOW OUTCOME DIALOG'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('SHOW OUTCOME DIALOG'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkin_end_all_sessions_button')));
      await tester.pumpAndSettle();

      expect(outcome, isNotNull);
      expect(
        outcome,
        equals(
          const SessionCheckInResult(
            lockedIn: true,
            endAllSessions: true,
          ),
        ),
      );
      expect(
        outcome.hashCode,
        equals(
          const SessionCheckInResult(
            lockedIn: true,
            endAllSessions: true,
          ).hashCode,
        ),
      );
    });
  });
}
