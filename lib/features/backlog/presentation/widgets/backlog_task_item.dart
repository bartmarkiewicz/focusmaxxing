import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';

class BacklogTaskItem extends StatelessWidget {
  const BacklogTaskItem({
    super.key,
    required this.task,
    required this.onSelect,
    required this.onDelete,
    this.onToggleComplete,
  });

  final BacklogTaskEntity task;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback? onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: 'Task: ${task.title}. ${task.isCompleted ? "Completed" : "Pending"}',
      hint:
          'Tap to set as active session goal, tap checkbox to mark complete, or swipe to delete',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Delete task'): onDelete,
        if (onToggleComplete != null)
          const CustomSemanticsAction(label: 'Toggle complete'):
              onToggleComplete!,
      },
      child: Dismissible(
        key: ValueKey('backlog_task_${task.id ?? task.hashCode}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: colorScheme.error.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.delete_outline,
            color: colorScheme.onError,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: ListTile(
              onTap: onSelect,
              leading: InkResponse(
                key: ValueKey('backlog_task_checkbox_${task.id ?? task.hashCode}'),
                onTap: () {
                  unawaited(
                    HapticFeedback.mediumImpact().catchError((Object _) {}),
                  );
                  onToggleComplete?.call();
                },
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    task.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: task.isCompleted
                        ? colorScheme.primary
                        : colorScheme.outline,
                    size: 22,
                  ),
                ),
              ),
              title: Text(
                task.title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: task.isCompleted
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              trailing: Icon(
                Icons.rocket_launch_outlined,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
