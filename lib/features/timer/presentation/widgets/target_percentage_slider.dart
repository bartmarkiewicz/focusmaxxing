import 'package:flutter/material.dart';

class TargetPercentageSlider extends StatelessWidget {
  const TargetPercentageSlider({
    super.key,
    required this.targetName,
    required this.percentage,
    required this.totalMinutes,
    required this.color,
    required this.onChanged,
    this.maxPercentage = 98,
    this.enabled = true,
  });

  final String targetName;
  final int percentage;
  final int totalMinutes;
  final Color color;
  final ValueChanged<int> onChanged;
  final int maxPercentage;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allocatedMinutes = (totalMinutes * (percentage / 100.0)).round();

    final maxVal = maxPercentage.clamp(2, 99).toDouble();
    final clampedValue = percentage.toDouble().clamp(1.0, maxVal);
    final divisionsCount = (maxVal - 1.0).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  targetName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '$percentage% (${allocatedMinutes}m)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: clampedValue,
              min: 1.0,
              max: maxVal,
              divisions: divisionsCount > 0 ? divisionsCount : null,
              onChanged: enabled
                  ? (val) {
                      onChanged(val.round());
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
