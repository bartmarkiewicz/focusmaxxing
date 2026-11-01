import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/hold_button.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/overlay_controller.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/widgets/overlay_theme.dart';

/// Primary Hard-Lock Overlay presentation view designed as a calm, final wall.
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

    final goalText = controller.taskGoal.trim().isEmpty
        ? 'Deep Work'
        : controller.taskGoal.trim();

    final headline = isSessionFinished
        ? 'COMPLETE'
        : (isBreakMode
            ? 'BREAK'
            : (isScheduled
                ? 'SCHEDULED'
                : (isMaxFocusActive ? 'MAXIMUM FOCUS' : 'LOCKED IN')));

    final noticeText = isSessionFinished
        ? 'Session time has elapsed.'
        : (isBreakMode
            ? 'Social feeds remain locked during your break.'
            : (isScheduled
                ? 'Focus schedule is currently active.'
                : 'App is blocked during active session.'));

    final subheadline = isSessionFinished
        ? 'Session completed'
        : AppStrings.youAreWorkingOn;

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
              Text(
                headline,
                style: const TextStyle(
                  fontFamily: InstrumentTokens.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: OverlayTheme.alertColor,
                ),
              ),
              const SizedBox(height: InstrumentTokens.s16),
              Text(
                noticeText,
                style: const TextStyle(
                  fontFamily: InstrumentTokens.fontUi,
                  fontSize: 24,
                  height: 30 / 24,
                  fontWeight: FontWeight.w600,
                  color: OverlayTheme.ink,
                ),
              ),
              const SizedBox(height: InstrumentTokens.s20),
              // Prominent digital countdown readout
              Text(
                controller.timerDisplay,
                style: const TextStyle(
                  fontFamily: InstrumentTokens.fontMono,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: OverlayTheme.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: InstrumentTokens.s12),
              if (!isBreakMode) ...[
                Text(
                  subheadline,
                  style: const TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 14,
                    color: OverlayTheme.subtextColor,
                  ),
                ),
                const SizedBox(height: InstrumentTokens.s4),
                Text(
                  '"$goalText"',
                  style: const TextStyle(
                    fontFamily: InstrumentTokens.fontMono,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: OverlayTheme.ink,
                  ),
                ),
              ],
              const Spacer(),
              // Actions in the thumb zone
              InstrumentButton.primary(
                key: const Key('overlay_return_button'),
                label: isSessionFinished ? AppStrings.save : AppStrings.backToWork,
                onPressed: controller.handleReturn,
              ),
              if (!isSessionFinished) ...[
                const SizedBox(height: InstrumentTokens.s12),
                Center(
                  child: InstrumentButton.text(
                    key: const Key('overlay_take_breather_button'),
                    label: AppStrings.breatheForAMinute,
                    onPressed: controller.startBreather,
                  ),
                ),
              ],
              if (isMaxFocusActive && !isSessionFinished) ...[
                const SizedBox(height: InstrumentTokens.s12),
                HoldButton(
                  key: const Key('overlay_hold_to_cancel_button'),
                  label: AppStrings.holdToEndSession,
                  holdDuration: const Duration(seconds: 5),
                  onTriggered: controller.handleCancelSession,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
