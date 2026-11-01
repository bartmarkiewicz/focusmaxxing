import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/ui/sheet.dart';
import 'package:focusmaxxing/features/audio/presentation/widgets/soundscape_config_tile.dart';

/// Modal bottom sheet presenting the soundscape selector in the physical instrument style.
class SoundscapeBottomSheet extends StatelessWidget {
  const SoundscapeBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return Sheet.show<void>(
      context: context,
      builder: (_) => const Sheet(
        title: 'Soundscape',
        child: SoundscapeConfigTile(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SoundscapeConfigTile();
  }
}
