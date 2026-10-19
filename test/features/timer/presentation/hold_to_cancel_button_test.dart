import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/hold_to_cancel_button.dart';

void main() {
  Widget buildWidget({
    required double progress,
    VoidCallback? onHoldStart,
    VoidCallback? onHoldEnd,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HoldToCancelButton(
          progress: progress,
          onHoldStart: onHoldStart ?? () {},
          onHoldEnd: onHoldEnd ?? () {},
        ),
      ),
    );
  }

  group('HoldToCancelButton', () {
    testWidgets('renders default 5s label when progress is 0.0',
        (tester) async {
      await tester.pumpWidget(buildWidget(progress: 0.0));
      await tester.pumpAndSettle();

      expect(find.text('Hold to Cancel (5s)'), findsOneWidget);
    });

    testWidgets('renders countdown and warning color when progress > 0.0',
        (tester) async {
      await tester.pumpWidget(buildWidget(progress: 0.5));
      await tester.pumpAndSettle();

      expect(find.text('HOLD TO CANCEL (2.5s)'), findsOneWidget);
    });

    testWidgets(
        'triggers onHoldStart immediately on pointer down without 500ms lag',
        (tester) async {
      var holdStarted = false;
      var holdEnded = false;

      await tester.pumpWidget(buildWidget(
        progress: 0.0,
        onHoldStart: () => holdStarted = true,
        onHoldEnd: () => holdEnded = true,
      ));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldToCancelButton)),
      );
      // Immediate callback invocation without waiting 500ms
      await tester.pump();

      expect(holdStarted, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(holdEnded, isTrue);
      expect(find.text('Hold for 5 full seconds to cancel session'),
          findsOneWidget);
    });

    testWidgets(
        'triggers accessible confirmation dialog on tap and confirms cancel',
        (tester) async {
      var cancelledImmediate = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoldToCancelButton(
            progress: 0.0,
            onHoldStart: () {},
            onHoldEnd: () {},
            onCancelImmediate: () => cancelledImmediate = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();

      tester.semantics.tap(
        find.semantics.byLabel(
          'Hold for 5 seconds to cancel session. Progress: 0 percent.',
        ),
      );
      await tester.pumpAndSettle();

      // Expect confirmation dialog
      expect(find.text('Cancel Active Session?'), findsOneWidget);
      expect(find.text('CONFIRM CANCEL'), findsOneWidget);

      await tester.tap(find.text('CONFIRM CANCEL'));
      await tester.pumpAndSettle();

      expect(cancelledImmediate, isTrue);
      handle.dispose();
    });

    testWidgets(
        'updates progress and countdown dynamically via progressListenable (MED-02)',
        (tester) async {
      final progressNotifier = ValueNotifier<double>(0.0);
      addTearDown(progressNotifier.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HoldToCancelButton(
            progressListenable: progressNotifier,
            onHoldStart: () {},
            onHoldEnd: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hold to Cancel (5s)'), findsOneWidget);

      progressNotifier.value = 0.4;
      await tester.pump();

      expect(find.text('HOLD TO CANCEL (3.0s)'), findsOneWidget);

      progressNotifier.value = 0.8;
      await tester.pump();

      expect(find.text('HOLD TO CANCEL (1.0s)'), findsOneWidget);

      progressNotifier.value = 0.0;
      await tester.pump();

      expect(find.text('Hold to Cancel (5s)'), findsOneWidget);
    });
  });
}
