import 'package:flutter/material.dart';
import 'package:focusmaxxing/features/backlog/domain/entities/backlog_task_entity.dart';

class BacklogTaskItem extends StatelessWidget {
  final BacklogTaskEntity task;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const BacklogTaskItem({
    super.key,
    required this.task,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: 'Lock in on task: ${task.title}',
      hint: 'Double tap to set as active session goal, swipe left to delete',
      child: Dismissible(
        key: ValueKey('backlog_task_${task.id ?? task.title}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
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
              leading: Icon(
                Icons.rocket_launch_outlined,
                color: colorScheme.primary,
                size: 20,
              ),
              title: Text(
                task.title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
