import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:focusmaxxing/core/theme/accent_finish.dart';
import 'package:focusmaxxing/core/theme/app_theme.dart';
import 'package:focusmaxxing/core/ui/hold_button.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/core/ui/instrument_dial.dart';
import 'package:focusmaxxing/core/ui/list_row.dart';
import 'package:focusmaxxing/core/ui/readout_row.dart';
import 'package:focusmaxxing/core/ui/section_header.dart';
import 'package:focusmaxxing/core/ui/skeleton.dart';
import 'package:focusmaxxing/core/ui/tag.dart';

Widget _previewWrapper(Widget child, {bool isDark = true}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: isDark
        ? AppTheme.buildDarkTheme(null, finish: AccentFinish.brass)
        : AppTheme.buildLightTheme(null, finish: AccentFinish.brass),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: child,
        ),
      ),
    ),
  );
}

@Preview(name: 'Instrument Buttons', group: 'Core UI')
Widget previewInstrumentButtons() {
  return _previewWrapper(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InstrumentButton.primary(
          label: 'Start session',
          onPressed: () {},
        ),
        const SizedBox(height: 12),
        InstrumentButton.secondary(
          label: 'Configure targets',
          onPressed: () {},
        ),
        const SizedBox(height: 12),
        InstrumentButton.text(
          label: 'Restore purchases',
          onPressed: () {},
        ),
      ],
    ),
  );
}

@Preview(name: 'Hold Button', group: 'Core UI')
Widget previewHoldButton() {
  return _previewWrapper(
    HoldButton(
      label: 'Hold to stop',
      onTriggered: () {},
    ),
  );
}

@Preview(name: 'Section Header & Readout', group: 'Core UI')
Widget previewReadouts() {
  return _previewWrapper(
    const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: 'SESSION STATS'),
        ReadoutRow(label: 'Today total', value: '1h 40m'),
        ReadoutRow(label: 'Blocked attempts', value: '4'),
      ],
    ),
  );
}

@Preview(name: 'List Row & Tags', group: 'Core UI')
Widget previewListRowAndTags() {
  return _previewWrapper(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Tag(label: 'Focused', isSelected: true),
            SizedBox(width: 8),
            Tag(label: 'Mixed', isSelected: false),
            SizedBox(width: 8),
            Tag(label: "Didn't finish", isSelected: false),
          ],
        ),
        const SizedBox(height: 16),
        ListRow(
          title: 'Instagram',
          subtitle: 'Blocked during focus',
          leading: const Icon(Icons.block_outlined, size: 20),
          trailing: Checkbox(value: true, onChanged: (_) {}),
        ),
      ],
    ),
  );
}

@Preview(name: 'Instrument Dial', group: 'Core UI')
Widget previewInstrumentDial() {
  return _previewWrapper(
    InstrumentDial(
      remainingSeconds: 1500,
      totalSeconds: 1500,
      taskGoal: 'Thesis draft',
      onDurationChanged: (_) {},
    ),
  );
}

@Preview(name: 'Skeleton', group: 'Core UI')
Widget previewSkeleton() {
  return _previewWrapper(
    const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Skeleton(width: double.infinity, height: 20),
        SizedBox(height: 8),
        Skeleton(width: 200, height: 16),
      ],
    ),
  );
}
