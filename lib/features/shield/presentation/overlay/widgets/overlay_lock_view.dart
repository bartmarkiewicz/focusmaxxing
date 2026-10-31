import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/overlay_controller.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/widgets/overlay_hold_to_cancel_button.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/widgets/overlay_theme.dart';

/// Primary Hard-Lock Overlay presentation view displaying session status,
/// roast affirmation, countdown timer, and action buttons.
class OverlayLockView extends StatelessWidget {
  const OverlayLockView({
    super.key,
    required this.controller,
  });

  final OverlayController controller;

  @override
  Widget build(BuildContext context) {
    final isSessionFinished = controller.isSessionFinished;
    final isMaxFocusActive = controller.isMaxFocusActive;
    final isBreakMode = controller.isBreakMode;
    final isScheduled = controller.isScheduled;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isSessionFinished
              ? Icons.celebration_rounded
              : (isMaxFocusActive
                  ? Icons.gpp_maybe_rounded
                  : Icons.lock_rounded),
          size: 64,
          color: isSessionFinished
              ? OverlayTheme.actionGreen
              : OverlayTheme.alertColor,
        ),
        const SizedBox(height: 16),
        Text(
          isSessionFinished
              ? 'SESSION COMPLETE 🎉'
              : (isBreakMode
                  ? 'RECHARGE YOUR BRAIN'
                  : (isScheduled
                      ? 'AUTO-SHIELD ACTIVE'
                      : (isMaxFocusActive ? 'MAXIMUM FOCUS' : 'LOCKED IN'))),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isSessionFinished
              ? 'Great job locking in! Tap below to check in.'
              : (isBreakMode
                  ? 'Social feeds remain locked during your break.'
                  : (isScheduled
                      ? 'Scheduled focus shield is active.'
                      : '"${controller.taskGoal}"')),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            color: OverlayTheme.subtextColor,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            controller.roastAffirmation,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFFB0B7C3),
            ),
          ),
        ),
        if (isMaxFocusActive) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: OverlayTheme.alertColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: OverlayTheme.alertColor.withValues(alpha: 0.35),
              ),
            ),
            child: const Text(
              'Full phone lock active until timer finishes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OverlayTheme.alertColor,
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            controller.timerDisplay,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 48),
        if (isMaxFocusActive)
          OverlayHoldToCancelButton(
            onCancelCompleted: controller.handleCancelSession,
          )
        else
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: OverlayTheme.actionGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: controller.handleReturn,
              child: Text(
                isSessionFinished
                    ? 'COMPLETE CHECK-IN 🎉'
                    : 'RETURN TO FOCUSMAXXING',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        if (!isSessionFinished) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              key: const Key('overlay_take_breather_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              onPressed: controller.startBreather,
              child: const Text(
                '🌬️ TAKE A BREATHER (60S)',
                style: TextStyle(
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
