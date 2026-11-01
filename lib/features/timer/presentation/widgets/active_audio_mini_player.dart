import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';

/// Single mono line audio mini-player matching "The Instrument" aesthetic.
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
    final tokens = context.tokens;

    return Container(
      key: const ValueKey('active_audio_mini_player'),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: InstrumentTokens.s12, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InstrumentTokens.r1),
        border: Border.all(color: tokens.rule, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('mini_player_play_pause'),
            iconSize: 20,
            padding: const EdgeInsets.all(InstrumentTokens.s8),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              isPlaying ? Icons.pause_outlined : Icons.play_arrow_outlined,
              color: isPlaying ? tokens.accent : tokens.inkMuted,
            ),
            onPressed: audioNotifier.togglePreview,
            tooltip: isPlaying ? 'Pause soundscape' : 'Play soundscape',
          ),
          const SizedBox(width: InstrumentTokens.s4),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Ambient soundscape: ${active.title}. Tap to open selector.',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenSheet,
                child: Text(
                  '♪ ${active.title} · ${isPlaying ? "Playing" : "Paused"}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontMono,
                    fontSize: 12,
                    color: tokens.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
