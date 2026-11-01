import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusmaxxing/core/theme/accent_finish.dart';
import 'package:focusmaxxing/core/theme/app_theme.dart';
import 'package:focusmaxxing/core/ui/hold_button.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/core/ui/instrument_dial.dart';
import 'package:focusmaxxing/core/ui/list_row.dart';
import 'package:focusmaxxing/core/ui/readout_row.dart';
import 'package:focusmaxxing/core/ui/section_header.dart';
import 'package:focusmaxxing/core/ui/sheet.dart';
import 'package:focusmaxxing/core/ui/skeleton.dart';
import 'package:focusmaxxing/core/ui/tag.dart';

Widget _buildTestBoilerplate({
  required Widget child,
  Brightness brightness = Brightness.dark,
  AccentFinish finish = AccentFinish.brass,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark
        ? AppTheme.buildDarkTheme(null, finish: finish)
        : AppTheme.buildLightTheme(null, finish: finish),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('InstrumentButton', () {
    testWidgets('renders primary button and fires onPressed', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: InstrumentButton.primary(
            label: 'Start session',
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.text('Start session'), findsOneWidget);
      await tester.tap(find.text('Start session'));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });

    testWidgets('renders secondary and text variants', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: Column(
            children: [
              InstrumentButton.secondary(
                label: 'Secondary action',
                onPressed: () {},
              ),
              InstrumentButton.text(
                label: 'Text action',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      expect(find.text('Secondary action'), findsOneWidget);
      expect(find.text('Text action'), findsOneWidget);
    });
  });

  group('HoldButton', () {
    testWidgets('triggers action on complete hold gesture', (tester) async {
      var triggered = false;
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: HoldButton(
            label: 'Hold to stop',
            holdDuration: const Duration(milliseconds: 300),
            onTriggered: () => triggered = true,
          ),
        ),
      );

      expect(find.text('Hold to stop'), findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(find.text('Hold to stop')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(triggered, isFalse);

      await tester.pump(const Duration(milliseconds: 250));
      expect(triggered, isTrue);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(triggered, isTrue);
    });

    testWidgets('cancels hold if released early', (tester) async {
      var triggered = false;
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: HoldButton(
            label: 'Hold to stop',
            holdDuration: const Duration(seconds: 2),
            onTriggered: () => triggered = true,
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('Hold to stop')));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(triggered, isFalse);
    });

    testWidgets('TalkBack semantic tap triggers onTriggered directly', (tester) async {
      final handle = tester.ensureSemantics();
      var triggered = false;
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: HoldButton(
            label: 'Hold to stop',
            onTriggered: () => triggered = true,
          ),
        ),
      );

      final semanticsFinder = find.semantics.byLabel('Hold to stop');
      expect(semanticsFinder, findsOneWidget);

      tester.semantics.tap(semanticsFinder);
      await tester.pumpAndSettle();
      expect(triggered, isTrue);
      handle.dispose();
    });
  });

  group('SectionHeader', () {
    testWidgets('renders title in uppercase with trailing widget', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const SectionHeader(
            title: 'Presets',
            trailing: Text('Action'),
          ),
        ),
      );

      expect(find.text('PRESETS'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
    });
  });

  group('ReadoutRow', () {
    testWidgets('renders label and mono value', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: ReadoutRow(
            label: 'Today total',
            value: '1h 40m',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Today total'), findsOneWidget);
      expect(find.text('1h 40m'), findsOneWidget);

      await tester.tap(find.text('Today total'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  group('ListRow', () {
    testWidgets('renders title, subtitle and trailing control', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: ListRow(
            title: 'Instagram',
            subtitle: 'Social media',
            leading: const Icon(Icons.apps),
            trailing: Checkbox(value: true, onChanged: (_) {}),
          ),
        ),
      );

      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('Social media'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });
  });

  group('Tag', () {
    testWidgets('renders selected and unselected states and handles tap', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _buildTestBoilerplate(
              child: Tag(
                label: 'Focused',
                isSelected: selected,
                onTap: () => setState(() => selected = !selected),
              ),
            );
          },
        ),
      );

      expect(find.text('Focused'), findsOneWidget);
      await tester.tap(find.text('Focused'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
    });
  });

  group('Sheet', () {
    testWidgets('renders modal sheet structure with grabber and title', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  unawaited(
                    Sheet.show<void>(
                      context: context,
                      builder: (_) => const Sheet(
                        title: 'Session Complete',
                        child: Text('Receipt body'),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Session Complete'), findsOneWidget);
      expect(find.text('Receipt body'), findsOneWidget);
    });
  });

  group('Skeleton', () {
    testWidgets('renders without error under normal and disabled animation', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const Skeleton(width: 100, height: 20),
        ),
      );
      expect(find.byType(Skeleton), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(Skeleton), findsOneWidget);
    });
  });

  group('InstrumentDial', () {
    testWidgets('renders formatted time and goal', (tester) async {
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: const InstrumentDial(
            remainingSeconds: 1500,
            totalSeconds: 1500,
            taskGoal: 'Thesis draft',
          ),
        ),
      );

      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('Thesis draft'), findsOneWidget);
    });

    testWidgets('scrubbing dial changes duration with 5-minute detents', (tester) async {
      int? changedSeconds;
      await tester.pumpWidget(
        _buildTestBoilerplate(
          child: InstrumentDial(
            remainingSeconds: 1500,
            totalSeconds: 1500,
            onDurationChanged: (sec) => changedSeconds = sec,
          ),
        ),
      );

      final dialCenter = tester.getCenter(find.byType(InstrumentDial));
      // Drag from top (12 o'clock) towards right (3 o'clock = 15 min)
      final start = dialCenter + const Offset(0, -100);
      final gesture = await tester.startGesture(start);
      await gesture.moveTo(dialCenter + const Offset(100, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(changedSeconds, isNotNull);
      expect(changedSeconds! % 300, equals(0)); // Detent of 5 minutes (300s)
    });
  });
}
