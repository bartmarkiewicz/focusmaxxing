import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/copy/strings.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/session_receipt_sheet.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/audio/presentation/widgets/soundscape_bottom_sheet.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/backlog_modal_sheet.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/in_session_quick_capture_sheet.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/permission_guidance_sheet.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/active_audio_mini_player.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/active_lock_in_banner.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/break_info_card.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/duration_presets_widget.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/goal_anchor_pill.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/in_session_quick_capture_pill.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/multi_target_picker_sheet.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/recent_goal_chips.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/shield_pre_flight_dialog.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/timer_control_actions.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/timer_dial_widget.dart';
import 'package:focusmaxxing/main_scaffold.dart';
import 'package:provider/provider.dart';

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  bool _isCheckingIn = false;
  TimerNotifier? _timerNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<TimerNotifier>();
    if (_timerNotifier != notifier) {
      _timerNotifier?.removeListener(_handleTimerStatusChange);
      _timerNotifier = notifier;
      _timerNotifier?.addListener(_handleTimerStatusChange);
    }

    if (notifier.status == TimerStatus.completed && !_isCheckingIn) {
      _scheduleCheckIn(notifier);
    }
  }

  @override
  void dispose() {
    _timerNotifier?.removeListener(_handleTimerStatusChange);
    _timerNotifier = null;
    super.dispose();
  }

  void _handleTimerStatusChange() {
    final notifier = _timerNotifier;
    if (notifier != null &&
        notifier.status == TimerStatus.completed &&
        !_isCheckingIn) {
      _scheduleCheckIn(notifier);
    }
  }

  void _scheduleCheckIn(TimerNotifier notifier) {
    if (_isCheckingIn) return;
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !_isCheckingIn &&
          notifier.status == TimerStatus.completed) {
        unawaited(_triggerCheckIn(notifier));
      }
    });
  }

  Future<void> _triggerCheckIn(TimerNotifier notifier) async {
    if (_isCheckingIn || notifier.status != TimerStatus.completed) return;
    _isCheckingIn = true;
    final durationSeconds = notifier.targetDurationSeconds;
    final goal = notifier.currentTaskGoal;

    try {
      final result = await SessionReceiptSheet.show(
        context,
        durationSeconds: durationSeconds,
        taskGoal: goal,
      );

      if (!mounted) return;
      await notifier.checkInSession(
        lockedIn: result?.lockedIn ?? false,
        endAllSessions: result?.endAllSessions ?? false,
      );

      if (result?.rollIntoNext == true && mounted) {
        final audioNotifier = context.read<AudioNotifier?>();
        if (audioNotifier != null) {
          unawaited(audioNotifier.playChime());
        }
        unawaited(notifier.startNextFocusFromBreak(goal));
      }
    } finally {
      _isCheckingIn = false;
    }
  }

  Future<void> _handleEditGoal(TimerNotifier timerNotifier) async {
    final durationMinutes = (timerNotifier.targetDurationSeconds / 60).round();
    final result = await MultiTargetPickerSheet.show(
      context,
      durationMinutes: durationMinutes,
      initialTargets: timerNotifier.currentTargets,
    );
    if (!mounted || result == null) return;
    if (result.targets.isNotEmpty) {
      timerNotifier.setTargets(result.targets);
    }
    if (result.startImmediately) {
      await _handleStartLockIn(timerNotifier);
    }
  }

  Future<void> _handleStartLockIn(TimerNotifier timerNotifier) async {
    final shieldNotifier = context.read<ShieldNotifier?>();
    if (shieldNotifier != null &&
        shieldNotifier.activeAppCount > 0 &&
        (!shieldNotifier.permissionStatus.hasUsageStatsPermission ||
            !shieldNotifier.permissionStatus.hasOverlayPermission)) {
      final shouldArm = await ShieldPreFlightDialog.show(context);
      if (!mounted || shouldArm == null) return;
      if (shouldArm) {
        final missingType =
            !shieldNotifier.permissionStatus.hasUsageStatsPermission
                ? ShieldPermissionType.usageStats
                : ShieldPermissionType.overlay;
        if (mounted) {
          await PermissionGuidanceSheet.show(
            context,
            permissionType: missingType,
            onOpenSettings: () {
              unawaited(shieldNotifier.requestPermission(missingType));
            },
          );
        }
        return;
      }
    }

    String goal = timerNotifier.currentTaskGoal.trim();
    if (goal.isEmpty) {
      goal = 'Deep Work';
    }

    if (!mounted) return;
    try {
      unawaited(HapticFeedback.heavyImpact());
    } catch (_) {}

    final started = await timerNotifier.startFocusSession(
      goal,
      backlogTaskId: timerNotifier.linkedBacklogTaskId,
    );

    if (!mounted) return;
    if (!started && timerNotifier.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(timerNotifier.errorMessage!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleInSessionQuickCapture(BuildContext context) {
    final backlogNotifier = context.read<BacklogNotifier?>();
    if (backlogNotifier == null) return;
    unawaited(
      InSessionQuickCaptureSheet.show(
        context,
        onCaptured: (task) async {
          final success = await backlogNotifier.addTask(task);
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved "$task" to Backlog'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _openBacklog(
      BuildContext context, TimerNotifier timerNotifier) async {
    final task = await BacklogModalSheet.show(context);
    if (!mounted) return;
    if (task != null) {
      timerNotifier.setTaskGoal(task.title, backlogTaskId: task.id);
    }
  }

  Future<void> _promptCustomDuration(TimerNotifier timerNotifier) async {
    final selectedMinutes = await CustomDurationBottomSheet.show(
      context,
      initialDurationSeconds: timerNotifier.targetDurationSeconds,
    );
    if (!mounted || selectedMinutes == null) return;
    timerNotifier.setDurationPreset(selectedMinutes * 60);
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName ${now.day} $monthName';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final timerNotifier = context.read<TimerNotifier>();

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isExpanded =
                constraints.maxWidth >= 600 || constraints.maxHeight < 500;
            final dialSize = isExpanded
                ? (constraints.maxHeight < 500 ? 180.0 : 300.0)
                : (constraints.maxHeight * 0.28).clamp(160.0, 220.0);

            return Selector<TimerNotifier, TimerStatus>(
              selector: (_, notifier) => notifier.status,
              builder: (context, status, _) {
                final isIdle = status == TimerStatus.idle;
                final isRunningOrPaused =
                    status == TimerStatus.running || status == TimerStatus.paused;
                final isRestMode = status == TimerStatus.breakRunning ||
                    status == TimerStatus.breakCompleted;

                final topReadoutRow = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FOCUSMAXXING',
                        style: TextStyle(
                          fontFamily: InstrumentTokens.fontMono,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                          color: isRunningOrPaused ? tokens.inkFaint : tokens.inkMuted,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTodayDate(),
                            style: TextStyle(
                              fontFamily: InstrumentTokens.fontMono,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.8,
                              color: isRunningOrPaused ? tokens.inkFaint : tokens.inkMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final backlogNotifier = context.watch<BacklogNotifier?>();
                              final pendingCount = backlogNotifier?.pendingTasks.length ?? 0;
                              return IconButton(
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: pendingCount > 0
                                    ? Badge.count(
                                        count: pendingCount,
                                        backgroundColor: tokens.accent,
                                        child: Icon(Icons.inbox_outlined, color: tokens.ink),
                                      )
                                    : Icon(Icons.inbox_outlined, color: tokens.inkMuted),
                                tooltip: 'Backlog',
                                onPressed: () => _openBacklog(context, timerNotifier),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final dialWidget = Selector<
                    TimerNotifier,
                    ({
                      int remainingSeconds,
                      int targetDurationSeconds,
                      String currentTaskGoal,
                    })>(
                  selector: (_, notifier) => (
                    remainingSeconds: notifier.remainingSeconds,
                    targetDurationSeconds: notifier.targetDurationSeconds,
                    currentTaskGoal: notifier.currentTaskGoal,
                  ),
                  builder: (context, dialState, _) {
                    return TimerDialWidget(
                      remainingSeconds: dialState.remainingSeconds,
                      totalSeconds: dialState.targetDurationSeconds,
                      taskGoal: dialState.currentTaskGoal,
                      isPaused: status == TimerStatus.paused,
                      isRestMode: isRestMode,
                      size: dialSize,
                      onDurationChanged:
                          isIdle ? timerNotifier.setDurationPreset : null,
                    );
                  },
                );

                final blockedSummaryWidget = Consumer<ShieldNotifier?>(
                  builder: (context, shieldNotifier, _) {
                    final activeCount = shieldNotifier?.activeAppCount ?? 0;
                    final firstApp = shieldNotifier?.shieldedApps.isNotEmpty == true
                        ? shieldNotifier!.shieldedApps.first.appName
                        : null;
                    final summaryText = AppStrings.blockedAppsSummary(
                      activeCount,
                      firstAppName: firstApp,
                    );

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        MainScaffold.switchTab(context, 1);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              activeCount > 0
                                  ? Icons.shield_outlined
                                  : Icons.shield_moon_outlined,
                              size: 14,
                              color: isRunningOrPaused
                                  ? tokens.ink
                                  : tokens.inkMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              summaryText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: InstrumentTokens.fontUi,
                                fontSize: 13,
                                color: isRunningOrPaused
                                    ? tokens.ink
                                    : tokens.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );

                final goalSelectorWidget = Selector<TimerNotifier,
                    ({String goal, List<SessionTargetAllocation> targets})>(
                  selector: (_, notifier) => (
                    goal: notifier.currentTaskGoal,
                    targets: notifier.currentTargets,
                  ),
                  builder: (context, anchorState, _) {
                    return GoalAnchorPill(
                      goal: anchorState.goal,
                      targets: anchorState.targets,
                      isIdle: isIdle,
                      onTap: () => _handleEditGoal(timerNotifier),
                    );
                  },
                );

                final togglesRowWidget = isRunningOrPaused
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Consumer3<AudioNotifier?, ShieldNotifier?, TimerNotifier>(
                          builder: (context, audioNotifier, shieldNotifier, tNotifier, _) {
                            final soundOn = audioNotifier?.isPlaying ?? false;
                            final strictOn = shieldNotifier?.isMaximumFocusEnabled ?? false;
                            final singleOn = tNotifier.isSingleSessionMode;

                            return Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 4,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => SoundscapeBottomSheet.show(context),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        soundOn
                                            ? Icons.volume_up_outlined
                                            : Icons.volume_off_outlined,
                                        size: 13,
                                        color: soundOn ? tokens.accent : tokens.inkMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppStrings.soundToggle(soundOn),
                                        style: TextStyle(
                                          fontFamily: InstrumentTokens.fontMono,
                                          fontSize: 12,
                                          color: soundOn ? tokens.accent : tokens.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text('·', style: TextStyle(color: tokens.inkFaint)),
                                GestureDetector(
                                  key: const Key('timer_maximum_focus_pill'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    if (shieldNotifier == null) return;
                                    unawaited(HapticFeedback.selectionClick());
                                    final next = !strictOn;
                                    await shieldNotifier.setMaximumFocusEnabled(next);
                                    if (next && !shieldNotifier.permissionStatus.hasOverlayPermission) {
                                      await shieldNotifier.requestPermission(ShieldPermissionType.overlay);
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        strictOn
                                            ? Icons.lock_outlined
                                            : Icons.lock_open_outlined,
                                        size: 13,
                                        color: strictOn ? tokens.accent : tokens.inkMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppStrings.strictToggle(strictOn),
                                        style: TextStyle(
                                          fontFamily: InstrumentTokens.fontMono,
                                          fontSize: 12,
                                          color: strictOn ? tokens.accent : tokens.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text('·', style: TextStyle(color: tokens.inkFaint)),
                                GestureDetector(
                                  key: const Key('timer_single_session_mode_pill'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    unawaited(HapticFeedback.selectionClick());
                                    await timerNotifier.toggleSingleSessionMode();
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.repeat_one_outlined,
                                        size: 13,
                                        color: singleOn ? tokens.accent : tokens.inkMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Single: ${singleOn ? "On" : "Off"}',
                                        style: TextStyle(
                                          fontFamily: InstrumentTokens.fontMono,
                                          fontSize: 12,
                                          color: singleOn ? tokens.accent : tokens.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );

                final controlActionsWidget = Selector<TimerNotifier, int>(
                  selector: (_, notifier) => notifier.focusDurationMinutes,
                  builder: (context, _, __) {
                    return TimerControlActions(
                      timerNotifier: timerNotifier,
                      onStartLockIn: () => _handleStartLockIn(timerNotifier),
                      onTriggerCheckIn: () => _triggerCheckIn(timerNotifier),
                    );
                  },
                );

                if (isExpanded) {
                  return Column(
                    children: [
                      topReadoutRow,
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Center(child: dialWidget),
                            ),
                            Container(width: 1, color: tokens.rule),
                            Expanded(
                              flex: 5,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isRunningOrPaused) ...[
                                      ActiveLockInBanner(
                                        isPaused: status == TimerStatus.paused,
                                        targets: timerNotifier.currentTargets,
                                      ),
                                      const SizedBox(height: 8),
                                      InSessionQuickCapturePill(
                                        onTap: () => _handleInSessionQuickCapture(context),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    goalSelectorWidget,
                                    if (isIdle) ...[
                                      const SizedBox(height: 12),
                                      RecentGoalChips(
                                        recentGoals: timerNotifier.recentGoals,
                                        currentGoal: timerNotifier.currentTaskGoal,
                                        onSelectGoal: timerNotifier.setTaskGoal,
                                        onStartLockIn: () => unawaited(_handleStartLockIn(timerNotifier)),
                                      ),
                                      const SizedBox(height: 16),
                                      DurationPresetsWidget(
                                        selectedSeconds: timerNotifier.targetDurationSeconds,
                                        onPresetSelected: timerNotifier.setDurationPreset,
                                        onCustomTapped: () => _promptCustomDuration(timerNotifier),
                                      ),
                                    ],
                                    if (isRestMode) ...[
                                      const SizedBox(height: 16),
                                      const BreakInfoCard(),
                                    ],
                                    if (isRunningOrPaused) ...[
                                      Consumer<AudioNotifier?>(
                                        builder: (context, audioNotifier, _) {
                                          if (audioNotifier == null ||
                                              audioNotifier.activeSoundscape.isNone) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 12),
                                            child: ActiveAudioMiniPlayer(
                                              audioNotifier: audioNotifier,
                                              onOpenSheet: () =>
                                                  SoundscapeBottomSheet.show(context),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    blockedSummaryWidget,
                                    const SizedBox(height: 16),
                                    controlActionsWidget,
                                    const SizedBox(height: 12),
                                    togglesRowWidget,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    topReadoutRow,
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Column(
                          children: [
                            if (isRunningOrPaused) ...[
                              ActiveLockInBanner(
                                isPaused: status == TimerStatus.paused,
                                targets: timerNotifier.currentTargets,
                              ),
                              const SizedBox(height: 6),
                              InSessionQuickCapturePill(
                                onTap: () => _handleInSessionQuickCapture(context),
                              ),
                              const SizedBox(height: 6),
                            ],
                            const SizedBox(height: 4),
                            dialWidget,
                            const SizedBox(height: 8),
                            goalSelectorWidget,
                            if (isIdle) ...[
                              const SizedBox(height: 8),
                              RecentGoalChips(
                                recentGoals: timerNotifier.recentGoals,
                                currentGoal: timerNotifier.currentTaskGoal,
                                onSelectGoal: timerNotifier.setTaskGoal,
                                onStartLockIn: () =>
                                    unawaited(_handleStartLockIn(timerNotifier)),
                              ),
                              const SizedBox(height: 8),
                              DurationPresetsWidget(
                                selectedSeconds: timerNotifier.targetDurationSeconds,
                                onPresetSelected: timerNotifier.setDurationPreset,
                                onCustomTapped: () =>
                                    _promptCustomDuration(timerNotifier),
                              ),
                            ],
                            if (isRestMode) ...[
                              const SizedBox(height: 8),
                              const BreakInfoCard(),
                            ],
                            if (isRunningOrPaused) ...[
                              Consumer<AudioNotifier?>(
                                builder: (context, audioNotifier, _) {
                                  if (audioNotifier == null ||
                                      audioNotifier.activeSoundscape.isNone) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: ActiveAudioMiniPlayer(
                                      audioNotifier: audioNotifier,
                                      onOpenSheet: () =>
                                          SoundscapeBottomSheet.show(context),
                                    ),
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: 8),
                            blockedSummaryWidget,
                            const SizedBox(height: 10),
                            controlActionsWidget,
                            const SizedBox(height: 8),
                            togglesRowWidget,
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
