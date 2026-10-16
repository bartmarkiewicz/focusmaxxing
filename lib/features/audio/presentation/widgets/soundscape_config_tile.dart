import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:provider/provider.dart';

/// Settings configuration tile for selecting neurodivergent ambient soundscapes,
/// toggling live preview playback, and adjusting audio mix volume.
class SoundscapeConfigTile extends StatelessWidget {
  final AudioNotifier? notifier;
  final bool? isProUnlocked;

  const SoundscapeConfigTile({
    super.key,
    this.notifier,
    this.isProUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final audioNotifier = notifier ?? context.watch<AudioNotifier?>();
    final activeSoundscape =
        audioNotifier?.activeSoundscape ?? SoundscapeEntity.none;
    final soundscapes = audioNotifier?.soundscapes ?? SoundscapeEntity.presets;
    final volume = audioNotifier?.volume ?? AudioNotifier.defaultVolume;
    final isPlaying = audioNotifier?.isPlaying ?? false;
    final proUnlocked =
        isProUnlocked ?? audioNotifier?.isProUnlocked ?? false;
    final errorMessage = audioNotifier?.errorMessage;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SoundscapeHeaderRow(
            activeSoundscape: activeSoundscape,
            isPlaying: isPlaying,
            onPreviewTap: () {
              if (audioNotifier != null) {
                unawaited(audioNotifier.togglePreview());
              }
            },
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 6),
            _AudioErrorBanner(
              message: errorMessage,
              onDismiss: audioNotifier?.clearError,
            ),
          ],
          const SizedBox(height: 4),
          RadioGroup<String>(
            groupValue: activeSoundscape.id,
            onChanged: (value) {
              if (value != null && audioNotifier != null) {
                final selected = soundscapes.firstWhere(
                  (s) => s.id == value,
                  orElse: () => SoundscapeEntity.none,
                );
                if (selected.isProOnly && !proUnlocked) {
                  audioNotifier.triggerProRequirement(selected);
                } else {
                  unawaited(audioNotifier.selectSoundscape(value));
                }
              }
            },
            child: Column(
              children: [
                for (final soundscape in soundscapes)
                  _SoundscapeOptionTile(
                    key: ValueKey('soundscape_option_${soundscape.id}'),
                    soundscape: soundscape,
                    isSelected: activeSoundscape.id == soundscape.id,
                    showProBadge: soundscape.isProOnly && !proUnlocked,
                    onTap: () {
                      if (audioNotifier != null) {
                        if (soundscape.isProOnly && !proUnlocked) {
                          audioNotifier.triggerProRequirement(soundscape);
                        } else {
                          unawaited(
                            audioNotifier.selectSoundscape(soundscape.id),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _VolumeControlRow(
            volume: volume,
            onVolumeChanged: (newVolume) {
              if (audioNotifier != null) {
                unawaited(
                  audioNotifier.setVolume(newVolume, persist: false),
                );
              }
            },
            onVolumeChangeEnd: (_) {
              if (audioNotifier != null) {
                unawaited(audioNotifier.persistVolume());
              }
            },
          ),
        ],
      ),
    );
  }
}

class _AudioErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const _AudioErrorBanner({
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        key: const ValueKey('soundscape_error_banner'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.14),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                key: const ValueKey('soundscape_error_dismiss'),
                icon: const Icon(Icons.close_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

class _SoundscapeHeaderRow extends StatelessWidget {
  final SoundscapeEntity activeSoundscape;
  final bool isPlaying;
  final VoidCallback onPreviewTap;

  const _SoundscapeHeaderRow({
    required this.activeSoundscape,
    required this.isPlaying,
    required this.onPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.headphones_outlined,
            color: colorScheme.onSurface,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ambient Audio',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Brown noise, 40Hz, Rain · Mixes with music',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: isPlaying ? 'Stop soundscape preview' : 'Preview soundscape',
            excludeSemantics: true,
            child: OutlinedButton.icon(
              key: const ValueKey('soundscape_preview_button'),
              onPressed: onPreviewTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                  kMinInteractiveDimension,
                  kMinInteractiveDimension,
                ),
                foregroundColor:
                    isPlaying ? colorScheme.primary : colorScheme.onSurface,
                side: BorderSide(
                  color: isPlaying
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: Icon(
                isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 18,
              ),
              label: Text(
                isPlaying ? 'Stop' : 'Preview',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      isPlaying ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundscapeOptionTile extends StatelessWidget {
  final SoundscapeEntity soundscape;
  final bool isSelected;
  final bool showProBadge;
  final VoidCallback onTap;

  const _SoundscapeOptionTile({
    super.key,
    required this.soundscape,
    required this.isSelected,
    required this.showProBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(
              children: [
                Radio<String>(
                  value: soundscape.id,
                  activeColor: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        soundscape.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (soundscape.subtitle.isNotEmpty)
                        Text(
                          soundscape.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showProBadge) ...[
                  const SizedBox(width: 8),
                  _ProPadlockBadge(
                    key: ValueKey('pro_badge_${soundscape.id}'),
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProPadlockBadge extends StatelessWidget {
  const _ProPadlockBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 13,
            color: colorScheme.tertiary,
          ),
          const SizedBox(width: 4),
          Text(
            'PRO',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeControlRow extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;

  const _VolumeControlRow({
    required this.volume,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final clampedVolume = volume.clamp(0.0, 1.0);
    final percentLabel = '${(clampedVolume * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Icon(
            clampedVolume == 0
                ? Icons.volume_off_outlined
                : Icons.volume_up_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Volume',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Slider(
              key: const ValueKey('soundscape_volume_slider'),
              value: clampedVolume,
              min: 0.0,
              max: 1.0,
              activeColor: colorScheme.primary,
              inactiveColor: colorScheme.outlineVariant,
              semanticFormatterCallback: (val) =>
                  'Ambient audio volume ${(val * 100).round()}%',
              onChanged: onVolumeChanged,
              onChangeEnd: onVolumeChangeEnd,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              percentLabel,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
