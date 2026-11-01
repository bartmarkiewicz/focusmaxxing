import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/app_theme.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/celebration_spark_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSheetHarness({
    required int durationMinutes,
    required String taskGoal,
    void Function(CelebrationResult? result)? onResult,
  }) {
    return MaterialApp(
      theme: AppTheme.buildDarkTheme(null),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                final result = await CelebrationSparkSheet.show(
                  context,
                  durationMinutes: durationMinutes,
                  taskGoal: taskGoal,
                );
                onResult?.call(result);
              },
              child: const Text('Open Sheet'),
            );
          },
        ),
      ),
    );
  }

  group('CelebrationSparkSheet Widget Tests', () {
    testWidgets('renders duration minutes, session receipt, and goal text',
        (tester) async {
      await tester.pumpWidget(
        buildSheetHarness(
          durationMinutes: 45,
          taskGoal: 'Ship Core Engine',
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('45:00'), findsOneWidget);
      expect(find.text('Ship Core Engine'), findsOneWidget);
      expect(find.text(AppStrings.howDidItGo), findsOneWidget);
      expect(find.text(AppStrings.startAnother25), findsOneWidget);
      expect(find.text(AppStrings.break5Min), findsOneWidget);
    });

    testWidgets('tapping start another returns rollIntoNext true',
        (tester) async {
      CelebrationResult? capturedResult;

      await tester.pumpWidget(
        buildSheetHarness(
          durationMinutes: 25,
          taskGoal: 'Deep Work',
          onResult: (res) => capturedResult = res,
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('celebration_roll_next_button')));
      await tester.pumpAndSettle();

      expect(capturedResult, isNotNull);
      expect(capturedResult!.rollIntoNext, isTrue);
    });

    testWidgets('tapping take break returns rollIntoNext false',
        (tester) async {
      CelebrationResult? capturedResult;

      await tester.pumpWidget(
        buildSheetHarness(
          durationMinutes: 25,
          taskGoal: 'Study Architecture',
          onResult: (res) => capturedResult = res,
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('celebration_take_break_button')));
      await tester.pumpAndSettle();

      expect(capturedResult, isNotNull);
      expect(capturedResult!.rollIntoNext, isFalse);
    });
  });
}
