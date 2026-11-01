import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/sheet.dart';
import 'package:focusmaxxing/core/utils/color_utils.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/timer/domain/entities/session_target_allocation.dart';
import 'package:focusmaxxing/features/timer/domain/utils/target_allocation_balancer.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:focusmaxxing/features/timer/presentation/widgets/target_percentage_slider.dart';
import 'package:provider/provider.dart';

@immutable
class MultiTargetPickerResult {
  const MultiTargetPickerResult({
    required this.targets,
    this.startImmediately = true,
  });

  final List<SessionTargetAllocation> targets;
  final bool startImmediately;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiTargetPickerResult &&
          runtimeType == other.runtimeType &&
          startImmediately == other.startImmediately &&
          _listEquals(targets, other.targets);

  @override
  int get hashCode => Object.hash(startImmediately, Object.hashAll(targets));

  static bool _listEquals(
      List<SessionTargetAllocation> a, List<SessionTargetAllocation> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class MultiTargetPickerSheet extends StatefulWidget {
  const MultiTargetPickerSheet({
    super.key,
    required this.durationMinutes,
    this.initialTargets = const [],
  });

  final int durationMinutes;
  final List<SessionTargetAllocation> initialTargets;

  static const List<String> targetPalette = [
    '#E5A93C', // Brass
    '#2BB872', // Signal
    '#4E8B71', // Moss
  ];

  static Future<MultiTargetPickerResult?> show(
    BuildContext context, {
    required int durationMinutes,
    List<SessionTargetAllocation> initialTargets = const [],
  }) {
    return Sheet.show<MultiTargetPickerResult>(
      context: context,
      builder: (ctx) => MultiTargetPickerSheet(
        durationMinutes: durationMinutes,
        initialTargets: initialTargets,
      ),
    );
  }

  @override
  State<MultiTargetPickerSheet> createState() => _MultiTargetPickerSheetState();
}

class _MultiTargetPickerSheetState extends State<MultiTargetPickerSheet> {
  final TextEditingController _inputController = TextEditingController();
  final List<_TargetDraft> _selectedTargets = [];
  String? _warningMessage;
  Timer? _warningTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialTargets.isNotEmpty) {
      for (var i = 0; i < widget.initialTargets.length; i++) {
        final t = widget.initialTargets[i];
        final colorHex = i < MultiTargetPickerSheet.targetPalette.length
            ? MultiTargetPickerSheet.targetPalette[i]
            : t.colorHex;
        _selectedTargets.add(
          _TargetDraft(
            name: t.targetName,
            percentage: t.percentage,
            colorHex: colorHex,
            backlogTaskId: t.backlogTaskId,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _warningTimer?.cancel();
    super.dispose();
  }

  void _showWarning(String msg) {
    unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
    _warningTimer?.cancel();
    setState(() {
      _warningMessage = msg;
    });
    _warningTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _warningMessage = null;
        });
      }
    });
  }

  void _addTarget(String name, {int? backlogTaskId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    if (_selectedTargets.any((t) => t.name.toLowerCase() == trimmed.toLowerCase())) {
      _showWarning('Target already selected');
      return;
    }

    if (_selectedTargets.length >= TargetAllocationBalancer.maxTargets) {
      _showWarning('Max 3 anchors to protect focus depth');
      return;
    }

    final newCount = _selectedTargets.length + 1;
    final defaultPercentages = TargetAllocationBalancer.defaultSplit(newCount);

    setState(() {
      final colorHex = MultiTargetPickerSheet.targetPalette[_selectedTargets.length];
      _selectedTargets.add(
        _TargetDraft(
          name: trimmed,
          percentage: defaultPercentages.last,
          colorHex: colorHex,
          backlogTaskId: backlogTaskId,
        ),
      );

      for (var i = 0; i < _selectedTargets.length; i++) {
        _selectedTargets[i].percentage = defaultPercentages[i];
      }
      _warningMessage = null;
    });

    _inputController.clear();
  }

  void _removeTarget(int index) {
    if (index < 0 || index >= _selectedTargets.length) return;
    setState(() {
      _selectedTargets.removeAt(index);
      final newCount = _selectedTargets.length;
      if (newCount > 0) {
        final defaultPercentages = TargetAllocationBalancer.defaultSplit(newCount);
        for (var i = 0; i < newCount; i++) {
          _selectedTargets[i].percentage = defaultPercentages[i];
          _selectedTargets[i].colorHex = MultiTargetPickerSheet.targetPalette[i];
        }
      }
      _warningMessage = null;
    });
  }

  void _onSliderChanged(int index, int newPercentage) {
    final currentPercentages = _selectedTargets.map((t) => t.percentage).toList();
    final balanced = TargetAllocationBalancer.rebalancePercentages(
      currentPercentages: currentPercentages,
      changedIndex: index,
      newPercentage: newPercentage,
    );
    setState(() {
      for (var i = 0; i < _selectedTargets.length; i++) {
        _selectedTargets[i].percentage = balanced[i];
      }
    });
  }

  void _resetToEqual() {
    final defaultPercentages = TargetAllocationBalancer.defaultSplit(_selectedTargets.length);
    setState(() {
      for (var i = 0; i < _selectedTargets.length; i++) {
        _selectedTargets[i].percentage = defaultPercentages[i];
      }
    });
  }

  void _submit({bool startImmediately = true}) {
    List<SessionTargetAllocation> finalTargets;
    if (_selectedTargets.isEmpty) {
      final input = _inputController.text.trim();
      final name = input.isNotEmpty ? input : 'Deep Work';
      finalTargets = [
        SessionTargetAllocation(
          targetName: name,
          percentage: 100,
          colorHex: MultiTargetPickerSheet.targetPalette[0],
        ),
      ];
    } else {
      finalTargets = [];
      for (var i = 0; i < _selectedTargets.length; i++) {
        final draft = _selectedTargets[i];
        finalTargets.add(
          SessionTargetAllocation(
            targetName: draft.name,
            percentage: draft.percentage,
            displayOrder: i + 1,
            colorHex: draft.colorHex,
            backlogTaskId: draft.backlogTaskId,
          ),
        );
      }
    }

    Navigator.of(context).pop(
      MultiTargetPickerResult(
        targets: finalTargets,
        startImmediately: startImmediately,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final colorScheme = theme.colorScheme;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    final timerNotifier = context.watch<TimerNotifier?>();
    final recentGoals = timerNotifier?.recentGoals ?? const [];

    final backlogNotifier = context.watch<BacklogNotifier?>();
    final pendingBacklogTasks = backlogNotifier?.pendingTasks ?? const [];

    final targetCount = _selectedTargets.length;
    final isMulti = targetCount > 1;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: viewInsetsBottom + 16,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(InstrumentTokens.r3),
            ),
            border: Border(
              top: BorderSide(
                color: tokens.rule,
              ),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ExcludeSemantics(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'What are you working on?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Max 3',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_warningMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _warningMessage!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Rapid Freeform Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _addTarget,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: targetCount >= 3
                              ? 'Max 3 targets selected'
                              : 'Add focus target (e.g. Mobile UI)...',
                          hintStyle: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _addTarget(_inputController.text),
                      tooltip: 'Add Target',
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Selected Target Chips
                if (targetCount > 0) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < targetCount; i++) ...[
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: ColorUtils.fromHex(_selectedTargets[i].colorHex),
                            radius: 6,
                          ),
                          label: Text(_selectedTargets[i].name),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          onDeleted: () => _removeTarget(i),
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          side: BorderSide(
                            color: ColorUtils.fromHex(_selectedTargets[i].colorHex)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Proportional Sliders Distribution Card (when 2 or 3 targets are selected)
                if (isMulti) ...[
                  _TimeAllocationCard(
                    targets: _selectedTargets,
                    totalMinutes: widget.durationMinutes,
                    onSliderChanged: _onSliderChanged,
                    onResetToEqual: _resetToEqual,
                  ),
                  const SizedBox(height: 14),
                ],

                // Recent Targets Rack
                if (recentGoals.isNotEmpty) ...[
                  _RecentTargetsRack(
                    recentGoals: recentGoals,
                    onGoalSelected: _addTarget,
                  ),
                  const SizedBox(height: 14),
                ],

                // Backlog Task Picker
                if (pendingBacklogTasks.isNotEmpty) ...[
                  _BacklogPickerSection(
                    tasks: pendingBacklogTasks,
                    selectedTargets: _selectedTargets,
                    onTaskSelected: (task) => _addTarget(task.title, backlogTaskId: task.id),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Launch Button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _submit(startImmediately: false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('SAVE TARGETS'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _submit(startImmediately: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          targetCount > 0
                              ? 'LOCK IN · ${widget.durationMinutes}m [$targetCount Target${targetCount > 1 ? "s" : ""}]'
                              : 'START FOCUS · ${widget.durationMinutes}m',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetDraft {
  _TargetDraft({
    required this.name,
    required this.percentage,
    required this.colorHex,
    this.backlogTaskId,
  });

  final String name;
  int percentage;
  String colorHex;
  final int? backlogTaskId;
}

class _TimeAllocationCard extends StatelessWidget {
  const _TimeAllocationCard({
    required this.targets,
    required this.totalMinutes,
    required this.onSliderChanged,
    required this.onResetToEqual,
  });

  final List<_TargetDraft> targets;
  final int totalMinutes;
  final void Function(int index, int newPercentage) onSliderChanged;
  final VoidCallback onResetToEqual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxPercentage = 100 - (targets.length - 1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TIME ALLOCATION',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              TextButton.icon(
                onPressed: onResetToEqual,
                icon: const Icon(Icons.sync_rounded, size: 14),
                label: const Text('Equalize Split'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < targets.length; i++) ...[
            TargetPercentageSlider(
              targetName: targets[i].name,
              percentage: targets[i].percentage,
              totalMinutes: totalMinutes,
              maxPercentage: maxPercentage,
              color: ColorUtils.fromHex(targets[i].colorHex),
              onChanged: (newVal) => onSliderChanged(i, newVal),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentTargetsRack extends StatelessWidget {
  const _RecentTargetsRack({
    required this.recentGoals,
    required this.onGoalSelected,
  });

  final List<String> recentGoals;
  final ValueChanged<String> onGoalSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent & Quick Anchors:',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.bolt, size: 14),
                label: const Text('Deep Work'),
                onPressed: () => onGoalSelected('Deep Work'),
              ),
              for (final goal in recentGoals) ...[
                const SizedBox(width: 8),
                ActionChip(
                  label: Text(goal),
                  onPressed: () => onGoalSelected(goal),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BacklogPickerSection extends StatelessWidget {
  const _BacklogPickerSection({
    required this.tasks,
    required this.selectedTargets,
    required this.onTaskSelected,
  });

  final List<BacklogTaskEntity> tasks;
  final List<_TargetDraft> selectedTargets;
  final ValueChanged<BacklogTaskEntity> onTaskSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Link from Backlog (Auto-completes upon Lock-In):',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 140),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, idx) {
              final task = tasks[idx];
              final isAlreadyAdded = selectedTargets
                  .any((t) => t.backlogTaskId == task.id);

              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(
                  isAlreadyAdded
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: isAlreadyAdded
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: isAlreadyAdded
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                onTap: isAlreadyAdded ? null : () => onTaskSelected(task),
              );
            },
          ),
        ),
      ],
    );
  }
}
