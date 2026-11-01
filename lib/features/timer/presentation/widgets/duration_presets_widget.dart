import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/core/ui/sheet.dart';
import 'package:focusmaxxing/core/ui/tag.dart';

/// Displays quick duration preset tags (15m, 25m, 45m, 60m, Custom) when idle.
class DurationPresetsWidget extends StatelessWidget {
  const DurationPresetsWidget({
    super.key,
    required this.selectedSeconds,
    required this.onPresetSelected,
    required this.onCustomTapped,
  });

  final int selectedSeconds;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onCustomTapped;

  @override
  Widget build(BuildContext context) {
    const presets = [
      (label: '15m', seconds: 15 * 60),
      (label: '25m', seconds: 25 * 60),
      (label: '45m', seconds: 45 * 60),
      (label: '60m', seconds: 60 * 60),
    ];

    final isCustom = !presets.any((p) => p.seconds == selectedSeconds);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final preset in presets) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tag(
                label: preset.label,
                isSelected: selectedSeconds == preset.seconds,
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  onPresetSelected(preset.seconds);
                },
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tag(
              label: isCustom ? '${selectedSeconds ~/ 60}m' : 'Custom',
              isSelected: isCustom,
              icon: const Icon(Icons.tune_outlined, size: 14),
              onTap: onCustomTapped,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomDurationBottomSheet extends StatefulWidget {
  const CustomDurationBottomSheet({
    super.key,
    required this.initialDurationSeconds,
  });

  final int initialDurationSeconds;

  static Future<int?> show(
    BuildContext context, {
    required int initialDurationSeconds,
  }) {
    return Sheet.show<int>(
      context: context,
      builder: (_) => CustomDurationBottomSheet(
        initialDurationSeconds: initialDurationSeconds,
      ),
    );
  }

  @override
  State<CustomDurationBottomSheet> createState() =>
      _CustomDurationBottomSheetState();
}

class _CustomDurationBottomSheetState
    extends State<CustomDurationBottomSheet> {
  late int _selectedMinutes;

  @override
  void initState() {
    super.initState();
    _selectedMinutes =
        (widget.initialDurationSeconds / 60).round().clamp(5, 120);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(InstrumentTokens.r3),
            ),
            border: Border(
              top: BorderSide(color: tokens.rule, width: 1),
              left: BorderSide(color: tokens.rule, width: 1),
              right: BorderSide(color: tokens.rule, width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.ruleStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Custom Duration',
                    style: TextStyle(
                      fontFamily: InstrumentTokens.fontUi,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  Text(
                    '$_selectedMinutes min',
                    style: TextStyle(
                      fontFamily: InstrumentTokens.fontMono,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: tokens.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: tokens.accent,
                  inactiveTrackColor: tokens.rule,
                  thumbColor: tokens.accent,
                  trackHeight: 3.0,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: _selectedMinutes.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  onChanged: (val) {
                    setState(() {
                      _selectedMinutes = val.round();
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              InstrumentButton.primary(
                label: 'Set duration',
                icon: const Icon(Icons.check_rounded, size: 18),
                onPressed: () => Navigator.of(context).pop(_selectedMinutes),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
