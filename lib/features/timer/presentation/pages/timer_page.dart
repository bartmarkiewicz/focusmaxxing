import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/features/audio/domain/entities/soundscape_entity.dart';
import 'package:focusmaxxing/features/audio/presentation/notifiers/audio_notifier.dart';
import 'package:focusmaxxing/features/audio/presentation/widgets/soundscape_config_tile.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/backlog_modal_sheet.dart';
import 'package:focusmaxxing/features/shield/domain/entities/shield_permission_status.dart';
import 'package:focusmaxxing/features/shield/presentation/notifiers/shield_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/goal_input_dialog.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/hold_to_cancel_button.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/session_checkin_dialog.dart';
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
      _isCheckingIn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && notifier.status == TimerStatus.completed) {
          unawaited(_triggerCheckIn(notifier));
        } else {
          _isCheckingIn = false;
        }
      });
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
      _isCheckingIn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _timerNotifier?.status == TimerStatus.completed) {
          unawaited(_triggerCheckIn(notifier));
        } else {
          _isCheckingIn = false;
        }
      });
    }
  }

  Future<void> _triggerCheckIn(TimerNotifier notifier) async {
    final durationSeconds = notifier.targetDurationSeconds;
    final goal = notifier.currentTaskGoal;

    try {
      final result = await SessionCheckInDialog.show(
        context,
        durationSeconds: durationSeconds,
        taskGoal: goal,
      );

      if (!mounted) return;
      await notifier.checkInSession(lockedIn: result ?? false);
    } finally {
      if (mounted) {
        _isCheckingIn = false;
      }
    }
  }

  Future<void> _handleEditGoal(TimerNotifier timerNotifier) async {
    final durationMinutes = (timerNotifier.targetDurationSeconds / 60).round();
    final selectedGoal = await GoalInputDialog.show(
      context,
      durationMinutes: durationMinutes,
      initialGoal: timerNotifier.currentTaskGoal,
    );
    if (!mounted) return;
    if (selectedGoal != null && selectedGoal.trim().isNotEmpty) {
      timerNotifier.setTaskGoal(selectedGoal);
    }
  }

  Future<void> _handleStartLockIn(TimerNotifier timerNotifier) async {
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

  Future<void> _openBacklog(
      BuildContext context, TimerNotifier timerNotifier) async {
    final task = await BacklogModalSheet.show(context);
    if (!mounted) return;
    if (task != null) {
      timerNotifier.setTaskGoal(task.title, backlogTaskId: task.id);
    }
  }

  Future<void> _promptCustomDuration(TimerNotifier timerNotifier) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    int currentMinutes =
        (timerNotifier.targetDurationSeconds / 60).round().clamp(5, 120);

    final selectedMinutes = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Set Custom Duration',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$currentMinutes min',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Slider(
                  value: currentMinutes.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: '$currentMinutes min',
                  activeColor: colorScheme.primary,
                  onChanged: (val) {
                    final rounded = val.round();
                    if (rounded != currentMinutes) {
                      try {
                        unawaited(HapticFeedback.selectionClick());
                      } catch (_) {}
                      setModalState(() {
                        currentMinutes = rounded;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final delta in [-15, -5, 5, 15, 30])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: const Size(48, 36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              final newVal =
                                  (currentMinutes + delta).clamp(5, 120);
                              if (newVal != currentMinutes) {
                                try {
                                  unawaited(HapticFeedback.selectionClick());
                                } catch (_) {}
                                setModalState(() {
                                  currentMinutes = newVal;
                                });
                              }
                            },
                            child: Text(
                              delta > 0 ? '+$delta' : '$delta',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(currentMinutes),
                    child: Text(
                      'APPLY DURATION',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || selectedMinutes == null) return;
    timerNotifier.setDurationPreset(selectedMinutes * 60);
  }

  Future<void> _showSoundscapeBottomSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🎧 Ambient Soundscapes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const SoundscapeConfigTile(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                onPressed: () =>
                    _openBacklog(context, context.read<TimerNotifier>()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Consumer<TimerNotifier>(
            builder: (context, timerNotifier, _) {
              final isIdle = timerNotifier.status == TimerStatus.idle;
              final isRunningOrPaused =
                  timerNotifier.status == TimerStatus.running ||
                      timerNotifier.status == TimerStatus.paused;
              final isRestMode =
                  timerNotifier.status == TimerStatus.breakRunning ||
                      timerNotifier.status == TimerStatus.breakCompleted;

              return Column(
                children: [
                  if (isRunningOrPaused) ...[
                    _ActiveLockInBanner(
                      isPaused: timerNotifier.status == TimerStatus.paused,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _GoalAnchorPill(
                    goal: timerNotifier.currentTaskGoal,
                    isIdle: isIdle,
                    onTap: () => _handleEditGoal(timerNotifier),
                  ),
                  if (isIdle) _buildRecentGoalChips(context, timerNotifier),
                  const SizedBox(height: 20),
                  TimerDialWidget(
                    remainingSeconds: timerNotifier.remainingSeconds,
                    totalSeconds: timerNotifier.targetDurationSeconds,
                    taskGoal: timerNotifier.currentTaskGoal,
                    isPaused: timerNotifier.status == TimerStatus.paused,
                    isRestMode: isRestMode,
                    onDurationChanged:
                        isIdle ? timerNotifier.setDurationPreset : null,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _SoundscapePill(
                        onTap: () => _showSoundscapeBottomSheet(context),
                      ),
                      const _MaximumFocusPill(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (isIdle) ...[
                    _DurationPresets(
                      selectedSeconds: timerNotifier.targetDurationSeconds,
                      onPresetSelected: timerNotifier.setDurationPreset,
                      onCustomTapped: () =>
                          _promptCustomDuration(timerNotifier),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (isRestMode) ...[
                    const _BreakInfoCard(),
                    const SizedBox(height: 24),
                  ],
                  _buildControlActions(context, timerNotifier),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecentGoalChips(
    BuildContext context,
    TimerNotifier timerNotifier,
  ) {
    final recentGoals = timerNotifier.recentGoals;
    if (recentGoals.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentGoal = timerNotifier.currentTaskGoal.trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final goal in recentGoals)
            ActionChip(
              avatar: const Icon(Icons.bolt_rounded, size: 14),
              label: Text(
                goal,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: goal.toLowerCase() == currentGoal
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              backgroundColor: goal.toLowerCase() == currentGoal
                  ? colorScheme.primary.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              side: BorderSide(
                color: goal.toLowerCase() == currentGoal
                    ? colorScheme.primary.withValues(alpha: 0.5)
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () {
                try {
                  unawaited(HapticFeedback.selectionClick());
                } catch (_) {}
                timerNotifier.setTaskGoal(goal);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildControlActions(
      BuildContext context, TimerNotifier timerNotifier) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (timerNotifier.status) {
      case TimerStatus.idle:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _handleStartLockIn(timerNotifier),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              '🚀 LOCK IN',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );

      case TimerStatus.running:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: timerNotifier.pause,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pause_rounded, size: 22),
                const SizedBox(width: 8),
                Text(
                  'PAUSE FOCUS',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );

      case TimerStatus.paused:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: timerNotifier.resume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'RESUME FOCUS',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            HoldToCancelButton(
              progress: timerNotifier.cancelHoldProgress,
              progressListenable: timerNotifier.cancelHoldProgressNotifier,
              onHoldStart: timerNotifier.startHoldToCancel,
              onHoldEnd: timerNotifier.releaseHoldToCancel,
              onCancelImmediate: timerNotifier.cancelSession,
            ),
          ],
        );

      case TimerStatus.completed:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _triggerCheckIn(timerNotifier),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'COMPLETE CHECK-IN 🎉',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );

      case TimerStatus.breakRunning:
      case TimerStatus.breakCompleted:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => timerNotifier.readyToFocusFromBreak(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'I\'M READY TO FOCUS',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
    }
  }
}

class _GoalAnchorPill extends StatelessWidget {
  const _GoalAnchorPill({
    required this.goal,
    required this.isIdle,
    required this.onTap,
  });

  final String goal;
  final bool isIdle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trimmed = goal.trim();

    return Semantics(
      button: isIdle,
      label: trimmed.isNotEmpty
          ? 'Active anchor: $trimmed'
          : 'No anchor set. Tap to set anchor.',
      child: InkWell(
        onTap: isIdle ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.anchor_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  trimmed.isNotEmpty ? trimmed : 'Set Single Focus Anchor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: trimmed.isNotEmpty
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isIdle) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SoundscapePill extends StatelessWidget {
  const _SoundscapePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final audioNotifier = context.watch<AudioNotifier?>();
    final active = audioNotifier?.activeSoundscape ?? SoundscapeEntity.none;
    final isNone = active.id == 'none';
    final isPlaying = audioNotifier?.isPlaying ?? false;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final label = isNone
        ? 'Ambient Audio: Off'
        : '${active.title} ${isPlaying ? "🔊" : ""}';

    return Semantics(
      button: true,
      label: 'Ambient Soundscape: $label. Tap to change.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isPlaying
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPlaying
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPlaying
                    ? Icons.music_note_rounded
                    : Icons.headphones_outlined,
                size: 15,
                color: isPlaying
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isPlaying
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: isPlaying
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationPresets extends StatelessWidget {
  const _DurationPresets({
    required this.selectedSeconds,
    required this.onPresetSelected,
    required this.onCustomTapped,
  });

  final int selectedSeconds;
  final ValueChanged<int> onPresetSelected;
  final VoidCallback onCustomTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const presets = [
      (label: '15m', seconds: 15 * 60),
      (label: '25m', seconds: 25 * 60),
      (label: '45m', seconds: 45 * 60),
      (label: '60m', seconds: 60 * 60),
    ];

    final isCustom = !presets.any((p) => p.seconds == selectedSeconds);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final preset in presets) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(preset.label),
                selected: selectedSeconds == preset.seconds,
                onSelected: (selected) {
                  if (selected) {
                    onPresetSelected(preset.seconds);
                  }
                },
                selectedColor: colorScheme.primary.withValues(alpha: 0.25),
                backgroundColor: colorScheme.surfaceContainerHighest,
                side: BorderSide(
                  color: selectedSeconds == preset.seconds
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: selectedSeconds == preset.seconds
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                isCustom ? '${(selectedSeconds / 60).round()}m' : 'Custom',
              ),
              selected: isCustom,
              onSelected: (_) => onCustomTapped(),
              selectedColor: colorScheme.primary.withValues(alpha: 0.25),
              backgroundColor: colorScheme.surfaceContainerHighest,
              side: BorderSide(
                color: isCustom
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: isCustom
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakInfoCard extends StatelessWidget {
  const _BreakInfoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Step away from your desk. Drink water or stretch. Social feeds remain locked. 🛡️',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveLockInBanner extends StatelessWidget {
  const _ActiveLockInBanner({required this.isPaused});

  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shieldNotifier = context.watch<ShieldNotifier?>();
    final activeShieldCount = shieldNotifier?.activeAppCount ?? 0;
    final isMaxFocus = shieldNotifier?.isMaximumFocusEnabled ?? false;

    final accentColor = isPaused
        ? colorScheme.tertiary
        : (isMaxFocus ? colorScheme.error : colorScheme.primary);
    final statusTitle = isPaused
        ? '⏸ FOCUS SESSION PAUSED'
        : (isMaxFocus
            ? '🔥 MAXIMUM FOCUS · PHONE LOCKED'
            : '🔒 LOCKED IN · ACTIVE FOCUS');
    final statusSubtitle = isPaused
        ? 'Countdown paused · Resume below to keep your streak'
        : isMaxFocus
            ? 'Full-screen phone lock enforced until session completes'
            : activeShieldCount > 0
                ? 'Brainrot Shield active ($activeShieldCount ${activeShieldCount == 1 ? "app" : "apps"} blocked) · Ongoing timer in notification bar'
                : 'Focus countdown active in notification bar';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPaused
                ? Icons.pause_circle_filled_rounded
                : (isMaxFocus ? Icons.gpp_maybe_rounded : Icons.shield_rounded),
            color: accentColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaximumFocusPill extends StatelessWidget {
  const _MaximumFocusPill();

  @override
  Widget build(BuildContext context) {
    final shieldNotifier = context.watch<ShieldNotifier?>();
    if (shieldNotifier == null) return const SizedBox.shrink();

    final isEnabled = shieldNotifier.isMaximumFocusEnabled;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeColor = colorScheme.error;

    return Semantics(
      button: true,
      toggled: isEnabled,
      label: isEnabled
          ? 'Maximum Focus enabled (full phone lock). Tap to disable.'
          : 'Maximum Focus disabled. Tap to enable full phone lock.',
      child: InkWell(
        key: const Key('timer_maximum_focus_pill'),
        onTap: () async {
          try {
            unawaited(HapticFeedback.selectionClick());
          } catch (_) {}
          final next = !isEnabled;
          await shieldNotifier.setMaximumFocusEnabled(next);
          if (next && !shieldNotifier.permissionStatus.hasOverlayPermission) {
            await shieldNotifier
                .requestPermission(ShieldPermissionType.overlay);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isEnabled
                ? activeColor.withValues(alpha: 0.14)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isEnabled
                  ? activeColor.withValues(alpha: 0.55)
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnabled
                    ? Icons.gpp_maybe_rounded
                    : Icons.lock_outline_rounded,
                size: 16,
                color: isEnabled ? activeColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                isEnabled ? 'Max Focus: ON' : 'Max Focus: OFF',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isEnabled ? activeColor : colorScheme.onSurfaceVariant,
                  fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
