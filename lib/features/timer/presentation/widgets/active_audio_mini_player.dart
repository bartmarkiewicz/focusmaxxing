import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';

/// Compact audio mini-player shown during an active focus session when a soundscape is selected.
class ActiveAudioMiniPlayer extends StatelessWidget {
  const ActiveAudioMiniPlayer({
    super.key,
    required this.audioNotifier,
    required this.onOpenSheet,
  });

  final AudioNotifier audioNotifier;
  final VoidCallback onOpenSheet;

  @override
  Widget build(BuildContext context) {
    final active = audioNotifier.activeSoundscape;
    final isPlaying = audioNotifier.isPlaying;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('active_audio_mini_player'),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? colorScheme.primary.withValues(alpha: 0.4)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('mini_player_play_pause'),
            iconSize: 28,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: isPlaying
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            onPressed: audioNotifier.togglePreview,
            tooltip: isPlaying ? 'Pause soundscape' : 'Play soundscape',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              label:
                  'Ambient soundscape: ${active.title}. Tap to open selector.',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenSheet,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      active.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      isPlaying
                          ? (active.isProOnly
                              ? 'Playing • Pro soundscape'
                              : 'Playing • Free ADHD loop')
                          : 'Paused',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 86,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: audioNotifier.volume,
                min: 0.0,
                max: 1.0,
                onChanged: (val) =>
                    audioNotifier.setVolume(val, persist: false),
                onChangeEnd: (_) => audioNotifier.persistVolume(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
