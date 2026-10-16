import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/backlog_modal_sheet.dart';
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && notifier.status == TimerStatus.completed && !_isCheckingIn) {
          unawaited(_triggerCheckIn(notifier));
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
    if (notifier != null && notifier.status == TimerStatus.completed && !_isCheckingIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _timerNotifier?.status == TimerStatus.completed && !_isCheckingIn) {
          unawaited(_triggerCheckIn(notifier));
        }
      });
    }
  }

  Future<void> _triggerCheckIn(TimerNotifier notifier) async {
    _isCheckingIn = true;
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
    final isBreak = timerNotifier.status == TimerStatus.breakCompleted ||
        timerNotifier.status == TimerStatus.breakRunning;
    final durationSeconds = isBreak
        ? timerNotifier.focusDurationSeconds
        : timerNotifier.targetDurationSeconds;
    final durationMinutes = (durationSeconds / 60).round();

    if (goal.isEmpty || isBreak) {
      final selectedGoal = await GoalInputDialog.show(
        context,
        durationMinutes: durationMinutes,
        initialGoal: goal,
      );
      if (selectedGoal == null || selectedGoal.trim().isEmpty) return;
      goal = selectedGoal;
    }

    if (!mounted) return;
    await timerNotifier.startFocusSession(
      goal,
      backlogTaskId: timerNotifier.linkedBacklogTaskId,
    );
  }

  Future<void> _openBacklog(BuildContext context, TimerNotifier timerNotifier) async {
    final task = await BacklogModalSheet.show(context);
    if (!mounted) return;
    if (task != null) {
      timerNotifier.setTaskGoal(task.title, backlogTaskId: task.id);
    }
  }

  Future<void> _promptCustomDuration(TimerNotifier timerNotifier) async {
    final minutes = (timerNotifier.targetDurationSeconds / 60).round();
    final controller = TextEditingController(text: '$minutes');
    String? validationError;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Custom Duration (Minutes)'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. 30',
              suffixText: 'min',
              errorText: validationError,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed != null && parsed > 0 && parsed <= 180) {
                  Navigator.of(ctx).pop(parsed);
                } else {
                  setDialogState(() {
                    validationError = 'Enter 1 to 180 minutes';
                  });
                }
              },
              child: const Text('SET'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (!mounted) return;

    if (result != null && result > 0) {
      timerNotifier.setDurationPreset(result * 60);
    }
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
          IconButton(
            icon: Icon(
              Icons.inbox_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Focus Scratchpad / Backlog',
            onPressed: () => _openBacklog(context, context.read<TimerNotifier>()),
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
              final isRestMode = timerNotifier.status == TimerStatus.breakRunning ||
                  timerNotifier.status == TimerStatus.breakCompleted;

              return Column(
                children: [
                  _buildGoalAnchorPill(context, timerNotifier),
                  const SizedBox(height: 24),
                  TimerDialWidget(
                    remainingSeconds: timerNotifier.remainingSeconds,
                    totalSeconds: timerNotifier.targetDurationSeconds,
                    taskGoal: timerNotifier.currentTaskGoal,
                    isPaused: timerNotifier.status == TimerStatus.paused,
                    isRestMode: isRestMode,
                  ),
                  const SizedBox(height: 32),
                  if (isIdle) ...[
                    _DurationPresets(
                      selectedSeconds: timerNotifier.targetDurationSeconds,
                      onPresetSelected: timerNotifier.setDurationPreset,
                      onCustomTapped: () => _promptCustomDuration(timerNotifier),
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

  Widget _buildGoalAnchorPill(BuildContext context, TimerNotifier timerNotifier) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIdle = timerNotifier.status == TimerStatus.idle;
    final goal = timerNotifier.currentTaskGoal.trim();

    return Semantics(
      button: isIdle,
      label: goal.isNotEmpty ? 'Active anchor: $goal' : 'No anchor set. Tap to set anchor.',
      child: InkWell(
        onTap: isIdle ? () => _handleEditGoal(timerNotifier) : null,
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
                  goal.isNotEmpty ? goal : 'Set Single Focus Anchor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: goal.isNotEmpty
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

  Widget _buildControlActions(BuildContext context, TimerNotifier timerNotifier) {
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
            onPressed: () => _handleStartLockIn(timerNotifier),
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
                isCustom
                    ? '${(selectedSeconds / 60).round()}m'
                    : 'Custom',
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
                color: isCustom ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
