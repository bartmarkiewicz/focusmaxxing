import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:provider/provider.dart';

@immutable
class GoalInputResult {
  final String goal;
  final bool startImmediately;

  const GoalInputResult({
    required this.goal,
    this.startImmediately = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalInputResult &&
          runtimeType == other.runtimeType &&
          goal == other.goal &&
          startImmediately == other.startImmediately;

  @override
  int get hashCode => Object.hash(goal, startImmediately);
}

class GoalInputDialog extends StatefulWidget {
  const GoalInputDialog({
    super.key,
    required this.durationMinutes,
    this.initialGoal = '',
  });

  final int durationMinutes;
  final String initialGoal;

  static Future<String?> show(
    BuildContext context, {
    required int durationMinutes,
    String initialGoal = '',
  }) async {
    final result = await showWithAction(
      context,
      durationMinutes: durationMinutes,
      initialGoal: initialGoal,
    );
    return result?.goal;
  }

  static Future<GoalInputResult?> showWithAction(
    BuildContext context, {
    required int durationMinutes,
    String initialGoal = '',
  }) {
    return showModalBottomSheet<GoalInputResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GoalInputDialog(
        durationMinutes: durationMinutes,
        initialGoal: initialGoal,
      ),
    );
  }

  @override
  State<GoalInputDialog> createState() => _GoalInputDialogState();
}

class _GoalInputDialogState extends State<GoalInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialGoal);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit({bool startImmediately = true}) {
    final text = _controller.text.trim();
    Navigator.of(context).pop(
      GoalInputResult(
        goal: text.isNotEmpty ? text : 'Deep Work',
        startImmediately: startImmediately,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final recentGoals = context.read<TimerNotifier>().recentGoals;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: viewInsetsBottom + 20,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
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
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Text(
                  'What ONE thing are you locking in on?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: 60,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Finish slides 3 and 4',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    counterStyle: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Quick Anchors:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        label: const Text('⚡ Deep Work'),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        side: BorderSide(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        labelStyle: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        onPressed: () {
                          _controller.text = 'Deep Work';
                          _submit();
                        },
                      ),
                      for (final goal in recentGoals) ...[
                        const SizedBox(width: 8),
                        ActionChip(
                          label: Text(goal),
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          side: BorderSide(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                          labelStyle: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          onPressed: () {
                            _controller.text = goal;
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: goal.length),
                            );
                            setState(() {});
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'START FOCUS (${widget.durationMinutes}m)',
                      style: theme.textTheme.labelLarge?.copyWith(
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
  }
}
