import 'package:flutter/material.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    super.key,
    this.onComplete,
    this.trailing,
  });

  final TaskItem task;
  final VoidCallback? onComplete;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleMedium?.copyWith(
      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
      color: task.isCompleted ? colors.onPrimaryContainer : null,
    );
    final subtitleStyle = textTheme.bodyMedium?.copyWith(
      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
      color: task.isCompleted ? colors.onPrimaryContainer : null,
    );

    return AnimatedContainer(
      duration: MotionTokens.normal,
      curve: MotionTokens.standard,
      child: Card(
        color: task.isCompleted ? colors.primaryContainer : null,
        child: ListTile(
          leading: AnimatedSwitcher(
            duration: MotionTokens.fast,
            child: task.isCompleted
                ? Icon(
                    Icons.check_circle_rounded,
                    key: const ValueKey('done'),
                    color: colors.primary,
                  )
                : IconButton(
                    key: const ValueKey('todo'),
                    onPressed: onComplete,
                    icon: const Icon(Icons.radio_button_unchecked_rounded),
                  ),
          ),
          title: Text(task.title, style: titleStyle),
          subtitle: Text(_subtitle, style: subtitleStyle),
          trailing: trailing,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    final parts = [
      '${task.priority.label}优先级',
      '${task.estimatedMinutes} 分钟',
      task.status.label,
      if (task.dueDateTime != null) '截止 ${_formatTime(task.dueDateTime!)}',
    ];

    return parts.join(' · ');
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
