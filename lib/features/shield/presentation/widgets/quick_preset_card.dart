import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/app_colors.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shielded_app_entity.dart';

class QuickPresetCard extends StatelessWidget {
  const QuickPresetCard({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final ShieldPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: preset.appName,
      child: Material(
        color: isSelected
            ? AppColors.accentLockIn.withValues(alpha: 0.14)
            : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('preset_${preset.packageName}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentLockIn
                      : AppColors.surfaceHairline,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 18,
                    color: isSelected
                        ? AppColors.accentLockIn
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    preset.emoji,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    preset.appName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? AppColors.textHighContrast
                          : AppColors.textMuted,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
