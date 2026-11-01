import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/core/theme/instrument_tokens.dart';
import 'package:focusmaxxing/core/ui/instrument_button.dart';
import 'package:focusmaxxing/core/ui/sheet.dart';
import 'package:focusmaxxing/core/ui/tag.dart';
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

    if (_selectedTargets
        .any((t) => t.name.toLowerCase() == trimmed.toLowerCase())) {
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
      final colorHex =
          MultiTargetPickerSheet.targetPalette[_selectedTargets.length];
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
        final defaultPercentages =
            TargetAllocationBalancer.defaultSplit(newCount);
        for (var i = 0; i < newCount; i++) {
          _selectedTargets[i].percentage = defaultPercentages[i];
          _selectedTargets[i].colorHex =
              MultiTargetPickerSheet.targetPalette[i];
        }
      }
      _warningMessage = null;
    });
  }

  void _onSliderChanged(int index, int newPercentage) {
    final currentPercentages =
        _selectedTargets.map((t) => t.percentage).toList();
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
    final defaultPercentages =
        TargetAllocationBalancer.defaultSplit(_selectedTargets.length);
    setState(() {
      for (var i = 0; i < _selectedTargets.length; i++) {
        _selectedTargets[i].percentage = defaultPercentages[i];
      }
    });
  }

  void _submit({bool startImmediately = true}) {
    // Automatically capture any non-empty text currently typed in the field
    final pendingText = _inputController.text.trim();
    if (pendingText.isNotEmpty &&
        _selectedTargets.length < TargetAllocationBalancer.maxTargets &&
        !_selectedTargets
            .any((t) => t.name.toLowerCase() == pendingText.toLowerCase())) {
      _addTarget(pendingText);
    }

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
    final tokens = context.tokens;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    final timerNotifier = context.watch<TimerNotifier?>();
    final recentGoals = timerNotifier?.recentGoals ?? const [];

    final backlogNotifier = context.watch<BacklogNotifier?>();
    final pendingBacklogTasks = backlogNotifier?.pendingTasks ?? const [];

    final targetCount = _selectedTargets.length;
    final isMulti = targetCount > 1;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(InstrumentTokens.r3),
              ),
              border: Border(
                top: BorderSide(color: tokens.rule, width: 1),
                left: BorderSide(color: tokens.rule, width: 1),
                right: BorderSide(color: tokens.rule, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pinned Header
                const SizedBox(height: InstrumentTokens.s12),
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.ruleStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'What are you working on?',
                          style: TextStyle(
                            fontFamily: InstrumentTokens.fontUi,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tokens.surfaceSunken,
                          borderRadius:
                              BorderRadius.circular(InstrumentTokens.r1),
                          border: Border.all(color: tokens.rule, width: 1),
                        ),
                        child: Text(
                          'Max 3',
                          style: TextStyle(
                            fontFamily: InstrumentTokens.fontMono,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: tokens.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(Icons.close_rounded, color: tokens.inkMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: tokens.rule),

                // Scrollable Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_warningMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: InstrumentTokens.s12,
                              vertical: InstrumentTokens.s8,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.surfaceSunken,
                              borderRadius:
                                  BorderRadius.circular(InstrumentTokens.r1),
                              border: Border.all(color: tokens.danger, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: tokens.danger),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _warningMessage!,
                                    style: TextStyle(
                                      fontFamily: InstrumentTokens.fontUi,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: tokens.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Freeform Input Box
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: tokens.surfaceSunken,
                                  borderRadius:
                                      BorderRadius.circular(InstrumentTokens.r1),
                                  border: Border.all(
                                      color: tokens.ruleStrong, width: 1),
                                ),
                                child: TextField(
                                  controller: _inputController,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: _addTarget,
                                  style: TextStyle(
                                    fontFamily: InstrumentTokens.fontUi,
                                    fontSize: 14,
                                    color: tokens.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: targetCount >= 3
                                        ? 'Max 3 targets selected'
                                        : 'Add focus target (e.g. Mobile UI)...',
                                    hintStyle: TextStyle(
                                      fontFamily: InstrumentTokens.fontUi,
                                      fontSize: 14,
                                      color: tokens.inkMuted,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _addTarget(_inputController.text),
                              borderRadius:
                                  BorderRadius.circular(InstrumentTokens.r1),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: tokens.accent,
                                  borderRadius:
                                      BorderRadius.circular(InstrumentTokens.r1),
                                ),
                                child: Tooltip(
                                  message: 'Add Target',
                                  child: Icon(
                                    Icons.add_rounded,
                                    color: tokens.accentInk,
                                    size: 20,
                                  ),
                                ),
                              ),
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
                                    backgroundColor: ColorUtils.fromHex(
                                        _selectedTargets[i].colorHex),
                                    radius: 5,
                                  ),
                                  label: Text(
                                    _selectedTargets[i].name,
                                    style: TextStyle(
                                      fontFamily: InstrumentTokens.fontUi,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: tokens.ink,
                                    ),
                                  ),
                                  deleteIcon: Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: tokens.inkMuted,
                                  ),
                                  onDeleted: () => _removeTarget(i),
                                  backgroundColor: tokens.surfaceSunken,
                                  side: BorderSide(
                                    color: ColorUtils.fromHex(
                                            _selectedTargets[i].colorHex)
                                        .withValues(alpha: 0.6),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        InstrumentTokens.r1),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Time Allocation Card (when 2+ targets selected)
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
                            onTaskSelected: (task) => _addTarget(
                              task.title,
                              backlogTaskId: task.id,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),

                // Pinned Bottom Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    border: Border(top: BorderSide(color: tokens.rule, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InstrumentButton.secondary(
                          label: 'Save targets',
                          icon: const Icon(Icons.check_rounded, size: 18),
                          onPressed: () => _submit(startImmediately: false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InstrumentButton.primary(
                          label: 'Start session',
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          onPressed: () => _submit(startImmediately: true),
                        ),
                      ),
                    ],
                  ),
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
    final tokens = context.tokens;
    final maxPercentage = 100 - (targets.length - 1);

    return Container(
      padding: const EdgeInsets.all(InstrumentTokens.s12),
      decoration: BoxDecoration(
        color: tokens.surfaceSunken,
        borderRadius: BorderRadius.circular(InstrumentTokens.r1),
        border: Border.all(color: tokens.rule, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TIME ALLOCATION',
                style: TextStyle(
                  fontFamily: InstrumentTokens.fontMono,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: tokens.inkMuted,
                ),
              ),
              InkWell(
                onTap: onResetToEqual,
                borderRadius: BorderRadius.circular(InstrumentTokens.r1),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync_rounded, size: 13, color: tokens.inkMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Equalize Split',
                        style: TextStyle(
                          fontFamily: InstrumentTokens.fontUi,
                          fontSize: 12,
                          color: tokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
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
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent & Quick Anchors:',
          style: TextStyle(
            fontFamily: InstrumentTokens.fontUi,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: tokens.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Tag(
                label: 'Deep Work',
                icon: const Icon(Icons.adjust_outlined, size: 13),
                onTap: () => onGoalSelected('Deep Work'),
              ),
              for (final goal in recentGoals) ...[
                const SizedBox(width: 8),
                Tag(
                  label: goal,
                  onTap: () => onGoalSelected(goal),
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
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 15,
              color: tokens.inkMuted,
            ),
            const SizedBox(width: 6),
            Text(
              'Link from Backlog (auto-completes):',
              style: TextStyle(
                fontFamily: InstrumentTokens.fontUi,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tokens.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 130),
          decoration: BoxDecoration(
            color: tokens.surfaceSunken,
            borderRadius: BorderRadius.circular(InstrumentTokens.r1),
            border: Border.all(color: tokens.rule, width: 1),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: tasks.length,
            separatorBuilder: (_, __) =>
                Container(height: 1, color: tokens.rule),
            itemBuilder: (context, idx) {
              final task = tasks[idx];
              final isAlreadyAdded =
                  selectedTargets.any((t) => t.backlogTaskId == task.id);

              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                leading: Icon(
                  isAlreadyAdded
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isAlreadyAdded ? tokens.accent : tokens.inkMuted,
                ),
                title: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: InstrumentTokens.fontUi,
                    fontSize: 13,
                    color: isAlreadyAdded ? tokens.accent : tokens.ink,
                    fontWeight: isAlreadyAdded
                        ? FontWeight.w600
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
