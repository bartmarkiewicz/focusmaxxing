import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/hold_button.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/overlay_controller.dart';
import 'package:focusmaxxing/features/shield/presentation/overlay/widgets/overlay_theme.dart';

/// Primary Hard-Lock Overlay presentation view designed as a calm, centered, final wall.
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

    final bottomPadding =
        math.max(MediaQuery.paddingOf(context).bottom, 28.0) + 16.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            InstrumentTokens.gutter,
            InstrumentTokens.s24,
            InstrumentTokens.gutter,
            bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 1),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: OverlayTheme.surfaceElevatedColor,
                  borderRadius: BorderRadius.circular(InstrumentTokens.r1),
                  border: Border.all(
                    color: OverlayTheme.borderColor,
                    width: 1,
                  ),
                ),
                child: Text(
                  headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: InstrumentTokens.fontMono,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: OverlayTheme.alertColor,
                  ),
                ),
              ),
              const SizedBox(height: InstrumentTokens.s20),
              // Prominent digital countdown readout
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  controller.timerDisplay,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: InstrumentTokens.fontMono,
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    height: 1.0,
                    color: OverlayTheme.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: InstrumentTokens.s16),
              // Notice headline
              Text(
                noticeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: InstrumentTokens.fontUi,
                  fontSize: 18,
                  height: 24 / 18,
                  fontWeight: FontWeight.w500,
                  color: OverlayTheme.ink,
                ),
              ),
              const SizedBox(height: InstrumentTokens.s16),
              // Task Goal Anchor
              if (!isBreakMode) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: OverlayTheme.surfaceElevatedColor,
                    borderRadius: BorderRadius.circular(InstrumentTokens.r1),
                    border: Border.all(
                      color: OverlayTheme.borderColor,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subheadline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: InstrumentTokens.fontUi,
                          fontSize: 12,
                          color: OverlayTheme.subtextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"$goalText"',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: InstrumentTokens.fontMono,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: OverlayTheme.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(flex: 2),
              // Actions in the thumb zone (above the Android home navigation bar)
              InstrumentButton.primary(
                key: const Key('overlay_return_button'),
                label: isSessionFinished ? AppStrings.save : AppStrings.backToWork,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                onPressed: controller.handleReturn,
              ),
              if (!isSessionFinished) ...[
                const SizedBox(height: InstrumentTokens.s12),
                Center(
                  child: InstrumentButton.text(
                    key: const Key('overlay_take_breather_button'),
                    label: AppStrings.breatheForAMinute,
                    icon: const Icon(Icons.air_rounded, size: 16),
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
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
