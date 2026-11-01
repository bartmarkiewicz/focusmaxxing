import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomDurationBottomSheet(
        initialDurationSeconds: initialDurationSeconds,
      ),
    );
  }

  @override
  State<CustomDurationBottomSheet> createState() =>
      _CustomDurationBottomSheetState();
}

class _CustomDurationBottomSheetState extends State<CustomDurationBottomSheet> {
  late int _selectedMinutes;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = (widget.initialDurationSeconds / 60).round().clamp(1, 180);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Custom Duration',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$_selectedMinutes min',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          Slider(
            value: _selectedMinutes.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            label: '$_selectedMinutes min',
            onChanged: (val) {
              setState(() {
                _selectedMinutes = val.round();
              });
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selectedMinutes),
            child: const Text('Set Duration'),
          ),
        ],
      ),
    );
  }
}
