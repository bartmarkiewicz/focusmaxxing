import 'dart:math' as math;
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
    this.onCancelBreather,
  });

  final OverlayBreatherStage stage;
  final Duration breatherDuration;
  final bool emergencyPassAvailable;
  final VoidCallback onBreatherComplete;
  final VoidCallback onReadyToFocus;
  final VoidCallback onEmergencyPass;
  final VoidCallback? onCancelBreather;

  @override
  Widget build(BuildContext context) {
    final isBreathing = stage == OverlayBreatherStage.breathing;
    final bottomPadding =
        math.max(MediaQuery.paddingOf(context).bottom, 28.0) + 16.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            InstrumentTokens.gutter,
            InstrumentTokens.s20,
            InstrumentTokens.gutter,
            bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header row with title and exit button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: OverlayTheme.surfaceElevatedColor,
                      borderRadius: BorderRadius.circular(InstrumentTokens.r1),
                      border: Border.all(
                        color: OverlayTheme.borderColor,
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'BREATHE',
                      style: TextStyle(
                        fontFamily: InstrumentTokens.fontMono,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: OverlayTheme.subtextColor,
                      ),
                    ),
                  ),
                  if (onCancelBreather != null)
                    IconButton(
                      key: const Key('overlay_breather_close_button'),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: OverlayTheme.subtextColor,
                        size: 20,
                      ),
                      tooltip: 'Exit to lock screen',
                      onPressed: onCancelBreather,
                    ),
                ],
              ),
              const SizedBox(height: InstrumentTokens.s16),
              Text(
                isBreathing
                    ? AppStrings.urgePassesNotice
                    : 'The urge has passed. Ready to continue?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: InstrumentTokens.fontUi,
                  fontSize: 18,
                  height: 24 / 18,
                  fontWeight: FontWeight.w600,
                  color: OverlayTheme.ink,
                ),
              ),
              const Spacer(),
              if (isBreathing) ...[
                Center(
                  child: BoxBreathingExercise(
                    key: const Key('overlay_box_breathing'),
                    totalDuration: breatherDuration,
                    color: OverlayTheme.actionGreen,
                    onComplete: onBreatherComplete,
                  ),
                ),
                const Spacer(),
                if (onCancelBreather != null)
                  InstrumentButton.text(
                    key: const Key('overlay_breather_cancel_button'),
                    label: 'Exit to lock screen',
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    onPressed: onCancelBreather,
                  ),
              ] else ...[
                const Spacer(),
                InstrumentButton.primary(
                  key: const Key('overlay_breather_ready_button'),
                  label: AppStrings.backToWork,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
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
                if (onCancelBreather != null) ...[
                  const SizedBox(height: InstrumentTokens.s12),
                  InstrumentButton.text(
                    label: 'Exit to lock screen',
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: onCancelBreather,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
