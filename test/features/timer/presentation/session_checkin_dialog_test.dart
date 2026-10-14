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

      expect(find.text('🎉 25m Complete'), findsOneWidget);
      expect(find.text('"Refactor Session"'), findsOneWidget);
      expect(find.text('DERAILED 💀'), findsOneWidget);
      expect(find.text('LOCKED IN 🚀'), findsOneWidget);
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

      await tester.tap(find.text('LOCKED IN 🚀'));
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

      await tester.tap(find.text('DERAILED 💀'));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });
  });
}
