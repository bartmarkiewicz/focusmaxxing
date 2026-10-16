import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/overlay_main.dart';

void main() {
  testWidgets('HardLockOverlayWidget renders default lock state correctly',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: Stream.empty(),
          initialGoal: 'Finish Project Spec',
          initialRemainingSeconds: 1500,
          initialIsBreak: false,
        ),
      ),
    );

    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.text('LOCKED IN'), findsOneWidget);
    expect(find.text('"Finish Project Spec"'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('RETURN TO FOCUSMAXXING'), findsOneWidget);
  });

  testWidgets('HardLockOverlayWidget renders break mode copy when isBreak is true',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: Stream.empty(),
          initialGoal: 'Write Unit Tests',
          initialRemainingSeconds: 300,
          initialIsBreak: true,
        ),
      ),
    );

    expect(find.text('RECHARGE YOUR BRAIN'), findsOneWidget);
    expect(
      find.text('Social feeds remain locked during your break.'),
      findsOneWidget,
    );
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('"Write Unit Tests"'), findsNothing);
  });

  testWidgets('HardLockOverlayWidget updates dynamically on JSON string stream event',
      (tester) async {
    final controller = StreamController<dynamic>(sync: true);
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: controller.stream,
          initialGoal: 'Initial Goal',
          initialRemainingSeconds: 600,
        ),
      ),
    );

    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('"Initial Goal"'), findsOneWidget);

    controller.add(
      jsonEncode({
        'goal': 'Crush Sprint Goal',
        'remainingSeconds': 125,
        'isBreak': false,
      }),
    );
    await tester.pump();

    expect(find.text('02:05'), findsOneWidget);
    expect(find.text('"Crush Sprint Goal"'), findsOneWidget);
    expect(find.text('LOCKED IN'), findsOneWidget);

    controller.add(
      jsonEncode({
        'isBreak': true,
        'remainingSeconds': 59,
      }),
    );
    await tester.pump();

    expect(find.text('00:59'), findsOneWidget);
    expect(find.text('RECHARGE YOUR BRAIN'), findsOneWidget);
    expect(
      find.text('Social feeds remain locked during your break.'),
      findsOneWidget,
    );
  });

  testWidgets('HardLockOverlayWidget updates dynamically on Map stream event',
      (tester) async {
    final controller = StreamController<dynamic>(sync: true);
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: controller.stream,
          initialGoal: 'Code Review',
          initialRemainingSeconds: 3600,
        ),
      ),
    );

    expect(find.text('60:00'), findsOneWidget);

    controller.add({
      'taskGoal': 'Deep Refactor',
      'remaining': 45,
      'isBreakMode': false,
    });
    await tester.pump();

    expect(find.text('00:45'), findsOneWidget);
    expect(find.text('"Deep Refactor"'), findsOneWidget);
  });

  testWidgets('HardLockOverlayWidget clamps zero or negative remaining seconds to 00:00',
      (tester) async {
    final controller = StreamController<dynamic>(sync: true);
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: controller.stream,
          initialRemainingSeconds: 0,
        ),
      ),
    );

    expect(find.text('00:00'), findsOneWidget);

    controller.add({'remainingSeconds': -15});
    await tester.pump();

    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('HardLockOverlayWidget calls onClose when RETURN button tapped',
      (tester) async {
    var closeCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: const Stream.empty(),
          onClose: () async {
            closeCalled = true;
          },
        ),
      ),
    );

    final button = find.widgetWithText(FilledButton, 'RETURN TO FOCUSMAXXING');
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pump();

    expect(closeCalled, isTrue);
  });
}
