import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/ui/tag.dart';
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
    return KeyedSubtree(
      key: ValueKey('preset_${preset.packageName}'),
      child: Tag(
        label: preset.appName,
        isSelected: isSelected,
        onTap: onTap,
      ),
    );
  }
}
