import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/backlog_modal_sheet.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/in_session_quick_capture_sheet.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/shield/presentation/widgets/permission_guidance_sheet.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/active_audio_mini_player.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/active_lock_in_banner.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/break_info_card.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/celebration_spark_sheet.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/duration_presets_widget.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/goal_anchor_pill.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/goal_input_dialog.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/in_session_quick_capture_pill.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/maximum_focus_pill.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/recent_goal_chips.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/session_checkin_dialog.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/shield_pre_flight_dialog.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/single_session_mode_pill.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/soundscape_pill.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/timer_control_actions.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/timer_dial_widget.dart';
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
      final result = await SessionCheckInDialog.showWithOutcome(
        context,
        durationSeconds: durationSeconds,
        taskGoal: goal,
      );

      if (!mounted) return;
      await notifier.checkInSession(
        lockedIn: result?.lockedIn ?? false,
        endAllSessions: result?.endAllSessions ?? false,
      );

      if (result?.lockedIn == true &&
          !(result?.endAllSessions ?? false) &&
          mounted) {
        final audioNotifier = context.read<AudioNotifier?>();
        if (audioNotifier != null) {
          unawaited(audioNotifier.playChime());
        }
        final celebration = await CelebrationSparkSheet.show(
          context,
          durationMinutes: (durationSeconds / 60).round(),
          taskGoal: goal,
        );
        if (mounted && celebration?.rollIntoNext == true) {
          unawaited(notifier.startNextFocusFromBreak(goal));
        }
      }
    } finally {
      _isCheckingIn = false;
    }
  }

  Future<void> _handleEditGoal(TimerNotifier timerNotifier) async {
    final durationMinutes = (timerNotifier.targetDurationSeconds / 60).round();
    final result = await GoalInputDialog.showWithAction(
      context,
      durationMinutes: durationMinutes,
      initialGoal: timerNotifier.currentTaskGoal,
    );
    if (!mounted || result == null) return;
    if (result.goal.trim().isNotEmpty) {
      timerNotifier.setTaskGoal(result.goal.trim());
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
                content: Text('Saved "$task" to Backlog 📥'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timerNotifier = context.read<TimerNotifier>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'FOCUSMAXXING',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          Builder(
            builder: (context) {
              final backlogNotifier = context.watch<BacklogNotifier?>();
              final pendingCount = backlogNotifier?.pendingTasks.length ?? 0;
              final icon = Icon(
                Icons.inbox_outlined,
                color: colorScheme.onSurfaceVariant,
              );
              return IconButton(
                icon: pendingCount > 0
                    ? Badge.count(
                        count: pendingCount,
                        backgroundColor: colorScheme.primary,
                        child: icon,
                      )
                    : icon,
                tooltip:
                    'Focus Scratchpad / Backlog (${pendingCount > 0 ? "$pendingCount pending" : "Empty"})',
                onPressed: () => _openBacklog(context, timerNotifier),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Selector<TimerNotifier, TimerStatus>(
            selector: (_, notifier) => notifier.status,
            builder: (context, status, _) {
              final isIdle = status == TimerStatus.idle;
              final isRunningOrPaused =
                  status == TimerStatus.running || status == TimerStatus.paused;
              final isRestMode = status == TimerStatus.breakRunning ||
                  status == TimerStatus.breakCompleted;

              return Column(
                children: [
                  if (isRunningOrPaused) ...[
                    ActiveLockInBanner(
                      isPaused: status == TimerStatus.paused,
                    ),
                    const SizedBox(height: 8),
                    InSessionQuickCapturePill(
                      onTap: () => _handleInSessionQuickCapture(context),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Selector<TimerNotifier, String>(
                    selector: (_, notifier) => notifier.currentTaskGoal,
                    builder: (context, currentTaskGoal, _) {
                      return GoalAnchorPill(
                        goal: currentTaskGoal,
                        isIdle: isIdle,
                        onTap: () => _handleEditGoal(timerNotifier),
                      );
                    },
                  ),
                  if (isIdle)
                    Selector<TimerNotifier,
                        ({List<String> recentGoals, String currentGoal})>(
                      selector: (_, notifier) => (
                        recentGoals: notifier.recentGoals,
                        currentGoal: notifier.currentTaskGoal,
                      ),
                      builder: (context, state, _) {
                        return RecentGoalChips(
                          recentGoals: state.recentGoals,
                          currentGoal: state.currentGoal,
                          onSelectGoal: timerNotifier.setTaskGoal,
                          onStartLockIn: () =>
                              unawaited(_handleStartLockIn(timerNotifier)),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  Selector<
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
                        onDurationChanged:
                            isIdle ? timerNotifier.setDurationPreset : null,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      SoundscapePill(
                        onTap: () => SoundscapeBottomSheet.show(context),
                      ),
                      const MaximumFocusPill(),
                      const SingleSessionModePill(),
                    ],
                  ),
                  if (isRunningOrPaused) ...[
                    Consumer<AudioNotifier?>(
                      builder: (context, audioNotifier, _) {
                        if (audioNotifier == null ||
                            audioNotifier.activeSoundscape.isNone) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: ActiveAudioMiniPlayer(
                            audioNotifier: audioNotifier,
                            onOpenSheet: () =>
                                SoundscapeBottomSheet.show(context),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (isIdle) ...[
                    Selector<TimerNotifier, int>(
                      selector: (_, notifier) => notifier.targetDurationSeconds,
                      builder: (context, targetDurationSeconds, _) {
                        return DurationPresetsWidget(
                          selectedSeconds: targetDurationSeconds,
                          onPresetSelected: timerNotifier.setDurationPreset,
                          onCustomTapped: () =>
                              _promptCustomDuration(timerNotifier),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (isRestMode) ...[
                    const BreakInfoCard(),
                    const SizedBox(height: 24),
                  ],
                  Selector<TimerNotifier, int>(
                    selector: (_, notifier) => notifier.focusDurationMinutes,
                    builder: (context, _, __) {
                      return TimerControlActions(
                        timerNotifier: timerNotifier,
                        onStartLockIn: () => _handleStartLockIn(timerNotifier),
                        onTriggerCheckIn: () => _triggerCheckIn(timerNotifier),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
