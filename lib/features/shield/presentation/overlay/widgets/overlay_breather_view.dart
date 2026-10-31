import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/overlay_controller.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/widgets/overlay_theme.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/box_breathing_exercise.dart';

/// Displays the urge-surfing box breathing exercise and post-breathing decision prompt.
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'URGE SURFING',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isBreathing
              ? 'Dopamine spikes peak at 60 seconds and dissipate. Breathe.'
              : 'The urge has passed. What do you need?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: OverlayTheme.subtextColor),
        ),
        const SizedBox(height: 36),
        if (isBreathing)
          BoxBreathingExercise(
            key: const Key('overlay_box_breathing'),
            totalDuration: breatherDuration,
            color: OverlayTheme.actionGreen,
            onComplete: onBreatherComplete,
          )
        else ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              key: const Key('overlay_breather_ready_button'),
              style: FilledButton.styleFrom(
                backgroundColor: OverlayTheme.actionGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: onReadyToFocus,
              child: const Text(
                "I'M READY TO FOCUS 🚀",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              key: const Key('overlay_emergency_pass_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              onPressed: emergencyPassAvailable ? onEmergencyPass : null,
              child: Text(
                emergencyPassAvailable
                    ? '2-MIN EMERGENCY PASS ⏱️'
                    : 'EMERGENCY PASS USED TODAY',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
