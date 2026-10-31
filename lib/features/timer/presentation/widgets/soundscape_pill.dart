import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/audio/presentation/widgets/soundscape_config_tile.dart';
import 'package:provider/provider.dart';

/// Pill button displaying the active ambient soundscape and opening the soundscape selector sheet.
class SoundscapePill extends StatelessWidget {
  const SoundscapePill({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final audioState = context.select<
        AudioNotifier?,
        ({SoundscapeEntity activeSoundscape, bool isPlaying})>(
      (notifier) => (
        activeSoundscape: notifier?.activeSoundscape ?? SoundscapeEntity.none,
        isPlaying: notifier?.isPlaying ?? false,
      ),
    );
    final active = audioState.activeSoundscape;
    final isNone = active.id == 'none';
    final isPlaying = audioState.isPlaying;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final label = isNone
        ? 'Ambient Audio: Off'
        : '${active.title} ${isPlaying ? "🔊" : ""}';

    return Semantics(
      button: true,
      label: 'Ambient Soundscape: $label. Tap to change.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isPlaying
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPlaying
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPlaying
                    ? Icons.music_note_rounded
                    : Icons.headphones_outlined,
                size: 15,
                color: isPlaying
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isPlaying
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: isPlaying
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet displaying the ambient soundscape configuration tiles.
abstract final class SoundscapeBottomSheet {
  static Future<void> show(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🎧 Ambient Soundscapes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const SoundscapeConfigTile(),
            ],
          ),
        ),
      ),
    );
  }
}
