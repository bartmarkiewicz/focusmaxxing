import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';

class TargetPercentageSlider extends StatelessWidget {
  const TargetPercentageSlider({
    super.key,
    required this.targetName,
    required this.percentage,
    required this.totalMinutes,
    required this.color,
    required this.onChanged,
    this.index = 1,
    this.maxPercentage = 98,
    this.enabled = true,
  });

  final String targetName;
  final int percentage;
  final int totalMinutes;
  final Color color;
  final ValueChanged<int> onChanged;
  final int index;
  final int maxPercentage;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final allocatedMinutes = (totalMinutes * (percentage / 100.0)).round();

    final maxVal = maxPercentage.clamp(2, 99).toDouble();
    final clampedValue = percentage.toDouble().clamp(1.0, maxVal);
    final divisionsCount = (maxVal - 1.0).round();

    final monoIndex = index.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                monoIndex,
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: tokens.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  targetName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tokens.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percentage% · ${allocatedMinutes}m',
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: tokens.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: tokens.accent,
              inactiveTrackColor: tokens.rule,
              thumbColor: tokens.accent,
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: clampedValue,
              min: 1.0,
              max: maxVal,
              divisions: divisionsCount > 0 ? divisionsCount : null,
              onChanged: enabled
                  ? (newVal) => onChanged(newVal.round())
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
