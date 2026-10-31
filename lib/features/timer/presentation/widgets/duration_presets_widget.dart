import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Displays quick duration preset chips (15m, 25m, 45m, 60m, Custom) when idle.
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              child: ChoiceChip(
                label: Text(preset.label),
                selected: selectedSeconds == preset.seconds,
                onSelected: (selected) {
                  if (selected) {
                    onPresetSelected(preset.seconds);
                  }
                },
                selectedColor: colorScheme.primary.withValues(alpha: 0.25),
                backgroundColor: colorScheme.surfaceContainerHighest,
                side: BorderSide(
                  color: selectedSeconds == preset.seconds
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: selectedSeconds == preset.seconds
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                isCustom ? '${(selectedSeconds / 60).round()}m' : 'Custom',
              ),
              selected: isCustom,
              onSelected: (_) => onCustomTapped(),
              selectedColor: colorScheme.primary.withValues(alpha: 0.25),
              backgroundColor: colorScheme.surfaceContainerHighest,
              side: BorderSide(
                color: isCustom
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: isCustom
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal bottom sheet allowing the user to select a custom duration between 5 and 120 minutes.
abstract final class CustomDurationBottomSheet {
  static Future<int?> show(
    BuildContext context, {
    required int initialDurationSeconds,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    var currentMinutes = (initialDurationSeconds / 60).round().clamp(5, 120);

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Set Custom Duration',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$currentMinutes min',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Slider(
                  value: currentMinutes.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: '$currentMinutes min',
                  activeColor: colorScheme.primary,
                  onChanged: (val) {
                    final rounded = val.round();
                    if (rounded != currentMinutes) {
                      try {
                        unawaited(HapticFeedback.selectionClick());
                      } catch (_) {}
                      setModalState(() {
                        currentMinutes = rounded;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final delta in [-15, -5, 5, 15, 30])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: const Size(48, 36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              final newVal =
                                  (currentMinutes + delta).clamp(5, 120);
                              if (newVal != currentMinutes) {
                                try {
                                  unawaited(HapticFeedback.selectionClick());
                                } catch (_) {}
                                setModalState(() {
                                  currentMinutes = newVal;
                                });
                              }
                            },
                            child: Text(
                              delta > 0 ? '+$delta' : '$delta',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(currentMinutes),
                    child: Text(
                      'APPLY DURATION',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
