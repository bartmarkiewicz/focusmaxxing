import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/overlay_controller.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/widgets/overlay_theme.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/box_breathing_exercise.dart';

/// Displays the urge-surfing square breathing exercise and decision prompt.
class OverlayBreatherView extends StatelessWidget {
  const OverlayBreatherView({
    super.key,
    required this.stage,
    required this.breatherDuration,
    required this.emergencyPassAvailable,
    required this.onBreatherComplete,
    required this.onReadyToFocus,
    required this.onEmergencyPass,
  });

  final OverlayBreatherStage stage;
  final Duration breatherDuration;
  final bool emergencyPassAvailable;
  final VoidCallback onBreatherComplete;
  final VoidCallback onReadyToFocus;
  final VoidCallback onEmergencyPass;

  @override
  Widget build(BuildContext context) {
    final isBreathing = stage == OverlayBreatherStage.breathing;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: InstrumentTokens.gutter,
            vertical: InstrumentTokens.s32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BREATHE',
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: OverlayTheme.subtextColor,
                ),
              ),
              const SizedBox(height: InstrumentTokens.s12),
              Text(
                isBreathing
                    ? AppStrings.urgePassesNotice
                    : 'The urge has passed. Ready to continue?',
                style: const TextStyle(
                  fontFamily: InstrumentTokens.fontUi,
                  fontSize: 20,
                  height: 26 / 20,
                  fontWeight: FontWeight.w600,
                  color: OverlayTheme.ink,
                ),
              ),
              const Spacer(),
              if (isBreathing)
                Center(
                  child: BoxBreathingExercise(
                    key: const Key('overlay_box_breathing'),
                    totalDuration: breatherDuration,
                    color: OverlayTheme.actionGreen,
                    onComplete: onBreatherComplete,
                  ),
                )
              else ...[
                InstrumentButton.primary(
                  key: const Key('overlay_breather_ready_button'),
                  label: AppStrings.backToWork,
                  onPressed: onReadyToFocus,
                ),
                const SizedBox(height: InstrumentTokens.s12),
                InstrumentButton.secondary(
                  key: const Key('overlay_emergency_pass_button'),
                  label: emergencyPassAvailable
                      ? '2 min emergency pass'
                      : 'Emergency pass used today',
                  onPressed: emergencyPassAvailable ? onEmergencyPass : null,
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
