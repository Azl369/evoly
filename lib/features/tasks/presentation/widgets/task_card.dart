import 'package:flutter/material.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    super.key,
    this.onComplete,
    this.contextLabel,
    this.trailing,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
  });

  final TaskItem task;
  final VoidCallback? onComplete;
  final String? contextLabel;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = EvolyDesignTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleMedium?.copyWith(
      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
      decorationColor: task.isCompleted ? colors.onSurfaceVariant : null,
      decorationThickness: task.isCompleted ? 2 : null,
      color: task.isCompleted ? colors.onSurfaceVariant : null,
    );
    final subtitleStyle = textTheme.bodyMedium?.copyWith(
      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
      decorationColor: task.isCompleted ? colors.onSurfaceVariant : null,
      decorationThickness: task.isCompleted ? 1.5 : null,
      color: colors.onSurfaceVariant,
    );
    final priorityColor = _priorityColor(tokens, task.priority);
    final statusColor = _statusColor(tokens, colors, task.status);

    return AppListCard(
      selected: task.isCompleted,
      compact: true,
      margin: margin,
      leading: AnimatedSwitcher(
        duration: MotionTokens.fast,
        child: task.isCompleted
            ? Icon(
                Icons.check_circle_rounded,
                key: const ValueKey('done'),
                color: tokens.statusSuccess,
              )
            : IconButton(
                key: const ValueKey('todo'),
                tooltip: '完成任务',
                onPressed: onComplete,
                icon: const Icon(Icons.radio_button_unchecked_rounded),
              ),
      ),
      title: Text(
        task.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      ),
      subtitle: task.description.trim().isEmpty
          ? null
          : Text(
              task.description.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ),
      meta: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          AppMetaPill(
            label: '${task.priority.label}优先级',
            icon: Icons.flag_rounded,
            color: priorityColor,
            selected: true,
          ),
          AppMetaPill(
            label: '${task.estimatedMinutes} 分钟',
            icon: Icons.timer_outlined,
          ),
          AppMetaPill(
            label: task.status.label,
            color: statusColor,
            selected: task.status != TaskStatus.pending,
          ),
          if (contextLabel?.trim().isNotEmpty == true)
            AppMetaPill(
              label: contextLabel!.trim(),
              icon: Icons.workspaces_outline,
            ),
          if (task.dueDateTime != null)
            AppMetaPill(
              label: '截止 ${_formatTime(task.dueDateTime!)}',
              icon: Icons.schedule_outlined,
            ),
          if (task.completedAt != null)
            AppMetaPill(
              label: '完成 ${_formatTime(task.completedAt!)}',
              icon: Icons.check_circle_outline_rounded,
              color: tokens.statusSuccess,
              selected: true,
            ),
        ],
      ),
      trailing: trailing,
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _priorityColor(EvolyDesignTokens tokens, Priority priority) {
    return switch (priority) {
      Priority.high => tokens.priorityHigh,
      Priority.medium => tokens.priorityMedium,
      Priority.low => tokens.priorityLow,
    };
  }

  Color _statusColor(
    EvolyDesignTokens tokens,
    ColorScheme colorScheme,
    TaskStatus status,
  ) {
    return switch (status) {
      TaskStatus.pending => tokens.statusNeutral,
      TaskStatus.completed => tokens.statusSuccess,
      TaskStatus.postponed => tokens.statusInfo,
      TaskStatus.cancelled => colorScheme.error,
    };
  }
}
