import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
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

    expect(find.text('LOCKED IN'), findsOneWidget);
    expect(find.text('"Finish Project Spec"'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text(AppStrings.backToWork), findsOneWidget);
  });

  testWidgets(
      'HardLockOverlayWidget renders break mode copy when isBreak is true',
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

    expect(find.text('BREAK'), findsOneWidget);
    expect(
      find.text('Social feeds remain locked during your break.'),
      findsOneWidget,
    );
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('"Write Unit Tests"'), findsNothing);
  });

  testWidgets(
      'HardLockOverlayWidget updates dynamically on JSON string stream event',
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
    expect(find.text('BREAK'), findsOneWidget);
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

  testWidgets(
      'HardLockOverlayWidget clamps zero or negative remaining seconds to 00:00',
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

    final button = find.widgetWithText(FilledButton, AppStrings.backToWork);
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pump();

    expect(closeCalled, isTrue);
  });

  testWidgets(
      'HardLockOverlayWidget is protected by PopScope with canPop false (HIGH-04)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: Stream.empty(),
          initialGoal: 'Locked In Task',
          initialRemainingSeconds: 1500,
        ),
      ),
    );

    final popScopeFinder = find.byWidgetPredicate(
      (widget) => widget is PopScope,
    );
    expect(popScopeFinder, findsOneWidget);
    final popScope = tester.widget<PopScope<Object?>>(popScopeFinder);
    expect(popScope.canPop, isFalse);
  });

  testWidgets(
      'HardLockOverlayWidget invokes returnToFocusmaxxing via bridge channel when RETURN tapped with default onClose',
      (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.focusmaxxing/overlay_bridge'),
      (call) async {
        calls.add(call.method);
        if (call.method == 'returnToFocusmaxxing') return true;
        if (call.method == 'getInitialOverlayState') {
          return <String, dynamic>{};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.focusmaxxing/overlay_bridge'),
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: Stream.empty(),
        ),
      ),
    );

    final button = find.widgetWithText(FilledButton, AppStrings.backToWork);
    await tester.tap(button);
    await tester.pump();

    expect(calls, contains('returnToFocusmaxxing'));
  });

  testWidgets(
      'HardLockOverlayWidget invokes cancelSessionFromOverlay via bridge channel on 5s hold completion',
      (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.focusmaxxing/overlay_bridge'),
      (call) async {
        calls.add(call.method);
        if (call.method == 'cancelSessionFromOverlay') return true;
        if (call.method == 'getInitialOverlayState') {
          return <String, dynamic>{};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.focusmaxxing/overlay_bridge'),
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: Stream.empty(),
          initialIsMaximumFocus: true,
        ),
      ),
    );

    final gestureFinder = find.byKey(const Key('overlay_hold_to_cancel_button'));
    expect(gestureFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(gestureFinder));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5, milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(calls, contains('cancelSessionFromOverlay'));
  });

  testWidgets(
      'HardLockOverlayWidget replaces cancel button with Save when remaining seconds is 0 in maximum focus',
      (tester) async {
    final controller = StreamController<dynamic>(sync: true);
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: controller.stream,
          initialIsMaximumFocus: true,
          initialRemainingSeconds: 60,
        ),
      ),
    );

    expect(find.byKey(const Key('overlay_hold_to_cancel_button')), findsOneWidget);
    expect(find.text(AppStrings.holdToEndSession), findsOneWidget);

    controller.add({
      'remainingSeconds': 0,
      'isMaximumFocus': true,
      'isBreak': false,
    });
    await tester.pump();

    // Cancel button must be completely gone when timer hits 00:00
    expect(find.byKey(const Key('overlay_hold_to_cancel_button')), findsNothing);
    expect(find.text(AppStrings.holdToEndSession), findsNothing);
    expect(find.text('COMPLETE'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, AppStrings.save), findsOneWidget);
  });

  testWidgets(
      'HardLockOverlayWidget countdown reaching 0 automatically triggers returnToFocusmaxxing',
      (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.focusmaxxing/overlay_bridge'),
      (call) async {
        calls.add(call.method);
        if (call.method == 'returnToFocusmaxxing') return true;
        if (call.method == 'getInitialOverlayState') {
          return <String, dynamic>{};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.focusmaxxing/overlay_bridge'),
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HardLockOverlayWidget(
          initialRemainingSeconds: 1,
          initialIsMaximumFocus: true,
        ),
      ),
    );

    expect(find.text('00:01'), findsOneWidget);
    expect(find.byKey(const Key('overlay_hold_to_cancel_button')), findsOneWidget);

    // Advance 1 second to let local countdown timer reach 0
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('00:00'), findsOneWidget);
    expect(find.byKey(const Key('overlay_hold_to_cancel_button')), findsNothing);
    expect(find.text('COMPLETE'), findsOneWidget);
    expect(calls, contains('returnToFocusmaxxing'));
  });

  testWidgets(
      'HardLockOverlayWidget restarts local countdown timer for subsequent sessions in cached engine',
      (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.focusmaxxing/overlay_bridge'),
      (call) async {
        calls.add(call.method);
        if (call.method == 'returnToFocusmaxxing') return true;
        if (call.method == 'getInitialOverlayState') {
          return <String, dynamic>{};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.focusmaxxing/overlay_bridge'),
        null,
      );
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HardLockOverlayWidget(
          initialRemainingSeconds: 1,
        ),
      ),
    );

    // Let Session 1 finish its countdown to 00:00
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('00:00'), findsOneWidget);

    // Push Session 2 update over the bridge channel into the same cached widget
    const codec = StandardMethodCodec();
    final ByteData message = codec.encodeMethodCall(
      const MethodCall(
        'updateOverlayState',
        <String, dynamic>{
          'goal': 'Session 2',
          'remainingSeconds': 2,
          'isBreak': false,
          'isMaximumFocus': false,
          'isPaused': false,
        },
      ),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'com.focusmaxxing/overlay_bridge',
      message,
      (_) {},
    );
    await tester.pump();
    expect(find.text('00:02'), findsOneWidget);
    expect(find.text('"Session 2"'), findsOneWidget);

    // Verify local countdown timer ticks Session 2 down to 00:01 and 00:00
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets(
      'HardLockOverlayWidget renders Scheduled Auto-Shield state without false session completion at 0s',
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

    controller.add({
      'isScheduled': true,
      'scheduleTimeRange': '09:00 - 17:00',
      'remainingSeconds': 0,
      'isBreak': false,
    });
    await tester.pump();

    expect(find.text('09:00 - 17:00'), findsOneWidget);
    expect(find.text('SCHEDULED'), findsOneWidget);
    expect(find.text('COMPLETE'), findsNothing);
  });

  group('Emergency Breather', () {
    const breatherDuration = Duration(milliseconds: 200);

    Widget buildOverlay({
      Future<void> Function()? onClose,
      Future<bool> Function()? onEmergencyPass,
      bool passAvailable = true,
      int remainingSeconds = 1500,
    }) {
      return MaterialApp(
        home: HardLockOverlayWidget(
          dataStream: const Stream<dynamic>.empty(),
          initialGoal: 'Ship it',
          initialRemainingSeconds: remainingSeconds,
          initialIsMaximumFocus: true,
          initialEmergencyPassAvailable: passAvailable,
          breatherDuration: breatherDuration,
          onClose: onClose,
          onEmergencyPass: onEmergencyPass,
        ),
      );
    }

    Future<void> completeBreather(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('overlay_take_breather_button')));
      await tester.pump();
      await tester.pump(breatherDuration + const Duration(seconds: 1));
      await tester.pump();
    }

    testWidgets('shows breather button on an active lock', (tester) async {
      await tester.pumpWidget(buildOverlay());

      expect(find.text(AppStrings.breatheForAMinute), findsOneWidget);
    });

    testWidgets('hides breather button once the session is finished',
        (tester) async {
      await tester.pumpWidget(buildOverlay(remainingSeconds: 0));

      expect(find.byKey(const Key('overlay_take_breather_button')),
          findsNothing);
    });

    testWidgets('tapping breather starts the box breathing exercise',
        (tester) async {
      await tester.pumpWidget(buildOverlay());

      await tester.tap(find.byKey(const Key('overlay_take_breather_button')));
      await tester.pump();

      expect(find.byKey(const Key('overlay_box_breathing')), findsOneWidget);
      expect(
        find.text(AppStrings.urgePassesNotice),
        findsOneWidget,
      );
      expect(find.byKey(const Key('overlay_hold_to_cancel_button')),
          findsNothing);
    });

    testWidgets('offers ready and emergency pass choices after breathing',
        (tester) async {
      await tester.pumpWidget(buildOverlay());

      await completeBreather(tester);

      expect(find.byKey(const Key('overlay_box_breathing')), findsNothing);
      expect(find.text(AppStrings.backToWork), findsOneWidget);
      expect(find.text('2 min emergency pass'), findsOneWidget);
    });

    testWidgets('ready button returns to the app and resets the overlay',
        (tester) async {
      var closeCalls = 0;
      await tester.pumpWidget(
        buildOverlay(onClose: () async => closeCalls++),
      );

      await completeBreather(tester);
      await tester.tap(find.byKey(const Key('overlay_breather_ready_button')));
      await tester.pump();

      expect(closeCalls, 1);
      expect(find.text('MAXIMUM FOCUS'), findsOneWidget);
    });

    testWidgets('emergency pass grants pass and resets the overlay',
        (tester) async {
      var passRequests = 0;
      await tester.pumpWidget(
        buildOverlay(onEmergencyPass: () async {
          passRequests++;
          return true;
        }),
      );

      await completeBreather(tester);
      await tester.tap(find.byKey(const Key('overlay_emergency_pass_button')));
      await tester.pump();

      expect(passRequests, 1);
      expect(find.text('MAXIMUM FOCUS'), findsOneWidget);
    });

    testWidgets('denied emergency pass stays on decision and disables button',
        (tester) async {
      await tester.pumpWidget(
        buildOverlay(onEmergencyPass: () async => false),
      );

      await completeBreather(tester);
      await tester.tap(find.byKey(const Key('overlay_emergency_pass_button')));
      await tester.pump();

      expect(find.text('Emergency pass used today'), findsOneWidget);
      expect(find.text(AppStrings.backToWork), findsOneWidget);
    });

    testWidgets('pass already used today renders disabled pass button',
        (tester) async {
      await tester.pumpWidget(buildOverlay(passAvailable: false));

      await completeBreather(tester);

      expect(find.text('Emergency pass used today'), findsOneWidget);
    });

    testWidgets('session ending mid-breather returns to the finished state',
        (tester) async {
      final controller = StreamController<dynamic>(sync: true);
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: HardLockOverlayWidget(
            dataStream: controller.stream,
            initialRemainingSeconds: 1500,
            initialIsMaximumFocus: true,
            breatherDuration: breatherDuration,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('overlay_take_breather_button')));
      await tester.pump();

      expect(find.byKey(const Key('overlay_box_breathing')), findsOneWidget);

      controller.add({
        'remainingSeconds': 0,
        'isMaximumFocus': true,
        'isBreak': false,
      });
      await tester.pump();

      expect(find.byKey(const Key('overlay_box_breathing')), findsNothing);
      expect(find.text('COMPLETE'), findsOneWidget);
    });

    testWidgets('requests emergency pass via bridge channel by default',
        (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.focusmaxxing/overlay_bridge'),
        (call) async {
          calls.add(call.method);
          if (call.method == 'grantEmergencyPass') return true;
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('com.focusmaxxing/overlay_bridge'),
          null,
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HardLockOverlayWidget(
            dataStream: Stream.empty(),
            initialIsMaximumFocus: true,
            breatherDuration: breatherDuration,
          ),
        ),
      );

      await completeBreather(tester);
      await tester.tap(find.byKey(const Key('overlay_emergency_pass_button')));
      await tester.pump();

      expect(calls, contains('grantEmergencyPass'));
      expect(find.text('MAXIMUM FOCUS'), findsOneWidget);
    });
  });
}
