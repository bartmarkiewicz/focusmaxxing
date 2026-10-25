import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/in_session_quick_capture_sheet.dart';

void main() {
  Widget buildSubject({
    required Future<void> Function(String title) onCaptured,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              unawaited(
                InSessionQuickCaptureSheet.show(
                  context,
                  onCaptured: onCaptured,
                ),
              );
            },
            child: const Text('OPEN QUICK CAPTURE'),
          ),
        ),
      ),
    );
  }

  group('InSessionQuickCaptureSheet', () {
    testWidgets('renders modal header, text field, and capture button',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(onCaptured: (_) async {}),
      );

      await tester.tap(find.text('OPEN QUICK CAPTURE'));
      await tester.pumpAndSettle();

      expect(find.text('Brain Dump Stray Thought'), findsOneWidget);
      expect(
        find.text('Offload distractions instantly. Session keeps running.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('in_session_quick_capture_input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('in_session_quick_capture_submit_button')),
        findsOneWidget,
      );
    });

    testWidgets('submitting text calls onCaptured and dismisses sheet',
        (tester) async {
      String? capturedTitle;

      await tester.pumpWidget(
        buildSubject(
          onCaptured: (title) async {
            capturedTitle = title;
          },
        ),
      );

      await tester.tap(find.text('OPEN QUICK CAPTURE'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('in_session_quick_capture_input')),
        '  Call accountant tomorrow  ',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('in_session_quick_capture_submit_button')),
      );
      await tester.pumpAndSettle();

      expect(capturedTitle, 'Call accountant tomorrow');
      expect(find.text('Brain Dump Stray Thought'), findsNothing);
    });

    testWidgets('pressing submit with empty text does not invoke onCaptured',
        (tester) async {
      var wasCaptured = false;

      await tester.pumpWidget(
        buildSubject(
          onCaptured: (_) async {
            wasCaptured = true;
          },
        ),
      );

      await tester.tap(find.text('OPEN QUICK CAPTURE'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('in_session_quick_capture_submit_button')),
      );
      await tester.pumpAndSettle();

      expect(wasCaptured, isFalse);
      expect(find.text('Brain Dump Stray Thought'), findsOneWidget);
    });
  });
}
