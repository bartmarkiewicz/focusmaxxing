import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/overlay_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OverlayController', () {
    late StreamController<dynamic> dataStreamController;

    setUp(() {
      dataStreamController = StreamController<dynamic>.broadcast();
    });

    tearDown(() async {
      await dataStreamController.close();
    });

    test('initializes with default values and computes display strings', () {
      final controller = OverlayController(
        dataStream: dataStreamController.stream,
        initialGoal: 'Ship Phase 3',
        initialRemainingSeconds: 1500,
      );
      addTearDown(controller.dispose);

      expect(controller.taskGoal, 'Ship Phase 3');
      expect(controller.remainingSeconds, 1500);
      expect(controller.timerDisplay, '25:00');
      expect(controller.isSessionFinished, isFalse);
      expect(controller.isMaxFocusActive, isFalse);
      expect(
        controller.roastAffirmation,
        'App is blocked during active focus.',
      );
    });

    test('updates state from JSON and Map payloads on dataStream', () async {
      final controller = OverlayController(
        dataStream: dataStreamController.stream,
      );
      addTearDown(controller.dispose);

      dataStreamController.add(
        jsonEncode({
          'goal': 'Refactor Architecture',
          'remainingSeconds': 95,
          'isMaximumFocus': true,
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.taskGoal, 'Refactor Architecture');
      expect(controller.remainingSeconds, 95);
      expect(controller.timerDisplay, '01:35');
      expect(controller.isMaxFocusActive, isTrue);

      dataStreamController.add({
        'isScheduled': true,
        'scheduleTimeRange': '22:00 - 06:00',
        'remainingSeconds': 0,
      });
      await Future<void>.delayed(Duration.zero);

      expect(controller.isScheduled, isTrue);
      expect(controller.timerDisplay, '22:00 - 06:00');
      expect(controller.isSessionFinished, isFalse);
      expect(
        controller.roastAffirmation,
        'Scheduled focus shield is active.',
      );
    });

    test('transitions through breather stages and handles emergency pass',
        () async {
      var passGranted = false;
      final controller = OverlayController(
        dataStream: dataStreamController.stream,
        onEmergencyPass: () async => passGranted,
      );
      addTearDown(controller.dispose);

      expect(controller.breatherStage, OverlayBreatherStage.none);

      controller.startBreather();
      expect(controller.breatherStage, OverlayBreatherStage.breathing);

      controller.completeBreather();
      expect(controller.breatherStage, OverlayBreatherStage.decision);

      await controller.handleEmergencyPass();
      expect(controller.breatherStage, OverlayBreatherStage.decision);
      expect(controller.emergencyPassAvailable, isFalse);

      passGranted = true;
      await controller.handleEmergencyPass();
      expect(controller.breatherStage, OverlayBreatherStage.none);
    });
  });
}
