import 'dart:async';
import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';
import 'package:focusmaxxing/features/backlog/presentation/notifiers/backlog_notifier.dart';
import 'package:focusmaxxing/features/backlog/presentation/widgets/backlog_task_item.dart';
import 'package:focusmaxxing/features/timer/presentation/notifiers/timer_notifier.dart';
import 'package:provider/provider.dart';

class BacklogModalSheet extends StatefulWidget {
  final ValueChanged<BacklogTaskEntity>? onTaskSelected;

  const BacklogModalSheet({super.key, this.onTaskSelected});

  static Future<BacklogTaskEntity?> show(
    BuildContext context, {
    ValueChanged<BacklogTaskEntity>? onTaskSelected,
  }) {
    return showModalBottomSheet<BacklogTaskEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BacklogModalSheet(onTaskSelected: onTaskSelected),
    );
  }

  @override
  State<BacklogModalSheet> createState() => _BacklogModalSheetState();
}

class _BacklogModalSheetState extends State<BacklogModalSheet> {
  final TextEditingController _textController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<BacklogNotifier>().loadPendingTasks());
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleAddTask() async {
    if (_isSubmitting) return;
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _isSubmitting = true;
    try {
      final notifier = context.read<BacklogNotifier>();
      final success = await notifier.addTask(text);
      if (!mounted) return;
      if (success) {
        _textController.clear();
      }
    } finally {
      _isSubmitting = false;
    }
  }

  void _handleTaskDelete(
      BuildContext context, BacklogNotifier notifier, BacklogTaskEntity task) {
    final taskId = task.id;
    if (taskId == null) return;

    final timerNotifier = context.read<TimerNotifier?>();
    timerNotifier?.clearLinkedBacklogTaskIfMatches(taskId);

    unawaited(notifier.deleteTask(taskId));

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed "${task.title}"'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            unawaited(notifier.addTask(task.title));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: viewInsetsBottom + 16,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: CustomScrollView(
            shrinkWrap: true,
            slivers: [
              SliverToBoxAdapter(
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
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Backlog (Focus Scratchpad)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close,
                              color: colorScheme.onSurfaceVariant),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textController,
                      maxLength: 60,
                      buildCounter: (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) =>
                          null,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleAddTask(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add next task...',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _handleAddTask,
                          icon: Icon(
                            Icons.add_circle,
                            color: colorScheme.primary,
                          ),
                          tooltip: 'Add task',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'TAP TO LOCK IN · SWIPE TO REMOVE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Consumer<BacklogNotifier>(
                builder: (context, notifier, _) {
                  if (notifier.isLoading) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  }

                  if (notifier.errorMessage != null) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            notifier.errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (notifier.pendingTasks.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'Scratchpad is clear.\nAdd tasks above to stay locked in.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = notifier.pendingTasks[index];
                        return BacklogTaskItem(
                          task: task,
                          onSelect: () {
                            notifier.selectTaskAsGoal(task);
                            widget.onTaskSelected?.call(task);
                            Navigator.of(context).pop(task);
                          },
                          onDelete: () =>
                              _handleTaskDelete(context, notifier, task),
                        );
                      },
                      childCount: notifier.pendingTasks.length,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
