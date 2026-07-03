import 'dart:async';

import 'package:flutter/material.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/reminders/presentation/task_reminder_picker.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';
import 'package:evoly/shared/ui/components/slide_select_field.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

class TaskEditSheet extends StatefulWidget {
  const TaskEditSheet({
    required this.title,
    required this.task,
    required this.reminder,
    required this.onSave,
    super.key,
  });

  final String title;
  final TaskItem task;
  final Reminder? reminder;
  final Future<void> Function(TaskItem updatedTask, DateTime? remindAt) onSave;

  @override
  State<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<TaskEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _minutesController;
  late TaskItem _task;

  late Priority _selectedPriority;
  late TaskStatus _selectedStatus;
  DateTime? _selectedDueDateTime;
  DateTime? _selectedRemindAt;
  Timer? _saveDebounce;
  var _saving = false;
  var _hasSavedChanges = false;
  var _allowClose = false;
  var _saveAgainAfterCurrent = false;
  String? _lastSavedSignature;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _titleController = TextEditingController(text: _task.title);
    _descriptionController = TextEditingController(
      text: _task.description,
    );
    _minutesController = TextEditingController(
      text: _task.estimatedMinutes.toString(),
    );
    _selectedPriority = _task.priority;
    _selectedStatus = _task.status;
    _selectedDueDateTime = _task.dueDateTime;
    _selectedRemindAt = widget.reminder?.remindAt;
    _lastSavedSignature = _signatureFor(_task, _selectedRemindAt);
    _titleController.addListener(_scheduleSave);
    _descriptionController.addListener(_scheduleSave);
    _minutesController.addListener(_scheduleSave);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleController.removeListener(_scheduleSave);
    _descriptionController.removeListener(_scheduleSave);
    _minutesController.removeListener(_scheduleSave);
    _titleController.dispose();
    _descriptionController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowClose,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _close();
      },
      child: ResponsiveBottomSheetBody(
        minHeight: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _AutoSaveStatus(
                  saving: _saving,
                  errorMessage: _saveError,
                  hasSavedChanges: _hasSavedChanges,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.compact),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '任务名称'),
            ),
            const SizedBox(height: AppSpacing.compact),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '任务说明'),
            ),
            const SizedBox(height: AppSpacing.compact),
            SlideSelectField<Priority>(
              label: '优先级',
              values: const [Priority.high, Priority.medium, Priority.low],
              value: _selectedPriority,
              labelBuilder: (priority) => priority.label,
              icon: Icons.flag_rounded,
              colorBuilder: _priorityColor,
              onChanged: _changePriority,
            ),
            const SizedBox(height: AppSpacing.compact),
            SlideSelectField<TaskStatus>(
              label: '状态',
              values: TaskStatus.values,
              value: _selectedStatus,
              labelBuilder: (status) => status.label,
              icon: Icons.check_circle_rounded,
              colorBuilder: _statusColor,
              onChanged: _changeStatus,
            ),
            const SizedBox(height: AppSpacing.compact),
            TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '预计耗时（分钟）'),
            ),
            const SizedBox(height: AppSpacing.compact),
            SegmentedButton<_DueOption>(
              segments: const [
                ButtonSegment(value: _DueOption.today, label: Text('今天')),
                ButtonSegment(
                  value: _DueOption.tomorrow,
                  label: Text('明天'),
                ),
                ButtonSegment(value: _DueOption.none, label: Text('不设')),
              ],
              selected: {_dueOptionFor(_selectedDueDateTime)},
              onSelectionChanged: (values) {
                final option = values.first;
                final now = DateTime.now();
                setState(() {
                  _selectedDueDateTime = switch (option) {
                    _DueOption.today => DateTime(
                        now.year,
                        now.month,
                        now.day,
                        23,
                        59,
                      ),
                    _DueOption.tomorrow => DateTime(
                        now.year,
                        now.month,
                        now.day,
                        23,
                        59,
                      ).add(const Duration(days: 1)),
                    _DueOption.none => null,
                  };
                });
                _scheduleSave();
              },
            ),
            const SizedBox(height: AppSpacing.compact),
            Text('提醒', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            TaskReminderPicker(
              selectedRemindAt: _selectedRemindAt,
              onChanged: (value) {
                setState(() => _selectedRemindAt = value);
                _scheduleSave();
              },
            ),
            const SizedBox(height: AppSpacing.compact),
            FilledButton.icon(
              onPressed: _close,
              icon: const Icon(Icons.check_rounded),
              label: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }

  void _changePriority(Priority priority) {
    if (priority == _selectedPriority) {
      return;
    }

    setState(() => _selectedPriority = priority);
    _scheduleSave();
  }

  void _changeStatus(TaskStatus status) {
    if (status == _selectedStatus) {
      return;
    }

    setState(() => _selectedStatus = status);
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    if (_saveError != null) {
      setState(() => _saveError = null);
    }
    _saveDebounce = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  Future<void> _saveNow() async {
    if (_saving) {
      _saveAgainAfterCurrent = true;
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      if (mounted) {
        setState(() => _saveError = '任务名称不能为空');
      }
      return;
    }

    final updatedTask = _buildUpdatedTask(title);
    final signature = _signatureFor(updatedTask, _selectedRemindAt);
    if (signature == _lastSavedSignature) {
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(updatedTask, _selectedRemindAt);
      if (!mounted) {
        return;
      }

      setState(() {
        _task = updatedTask;
        _lastSavedSignature = signature;
        _hasSavedChanges = true;
        _saving = false;
        _saveError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _saveError = '保存失败';
      });
    } finally {
      if (_saveAgainAfterCurrent) {
        _saveAgainAfterCurrent = false;
        _scheduleSave();
      }
    }
  }

  TaskItem _buildUpdatedTask(String title) {
    final estimatedMinutes = int.tryParse(_minutesController.text.trim()) ?? 30;
    final now = DateTime.now();
    return _task.copyWith(
      title: title,
      description: _descriptionController.text.trim(),
      priority: _selectedPriority,
      status: _selectedStatus,
      estimatedMinutes: estimatedMinutes.clamp(1, 1440),
      dueDateTime: _selectedDueDateTime,
      completedAt: _selectedStatus == TaskStatus.completed
          ? _task.completedAt ?? now
          : null,
      clearDueDateTime: _selectedDueDateTime == null,
      clearCompletedAt: _selectedStatus != TaskStatus.completed,
      updatedAt: now,
    );
  }

  Future<void> _close() async {
    _saveDebounce?.cancel();
    await _saveNow();
    if (!mounted || _saveError != null) {
      return;
    }

    setState(() => _allowClose = true);
    Navigator.pop(context, _hasSavedChanges);
  }

  String _signatureFor(TaskItem task, DateTime? remindAt) {
    return [
      task.title,
      task.description,
      task.priority.name,
      task.status.name,
      task.estimatedMinutes,
      task.dueDateTime?.millisecondsSinceEpoch,
      task.completedAt?.millisecondsSinceEpoch,
      remindAt?.millisecondsSinceEpoch,
    ].join('|');
  }

  Color _priorityColor(BuildContext context, Priority priority) {
    final tokens = EvolyDesignTokens.of(context);

    return switch (priority) {
      Priority.high => tokens.priorityHigh,
      Priority.medium => tokens.priorityMedium,
      Priority.low => tokens.priorityLow,
    };
  }

  Color _statusColor(BuildContext context, TaskStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = EvolyDesignTokens.of(context);

    return switch (status) {
      TaskStatus.pending => tokens.statusNeutral,
      TaskStatus.completed => tokens.statusSuccess,
      TaskStatus.postponed => tokens.statusInfo,
      TaskStatus.cancelled => colorScheme.error,
    };
  }
}

class _AutoSaveStatus extends StatelessWidget {
  const _AutoSaveStatus({
    required this.saving,
    required this.errorMessage,
    required this.hasSavedChanges,
  });

  final bool saving;
  final String? errorMessage;
  final bool hasSavedChanges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorMessage = this.errorMessage;

    if (saving) {
      return Text(
        '保存中…',
        style: theme.textTheme.bodySmall,
      );
    }

    if (errorMessage != null) {
      return Text(
        errorMessage,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }

    return Text(
      hasSavedChanges ? '已自动保存' : '自动保存',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

enum _DueOption {
  today,
  tomorrow,
  none,
}

_DueOption _dueOptionFor(DateTime? dueDateTime) {
  if (dueDateTime == null) {
    return _DueOption.none;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDate = DateTime(
    dueDateTime.year,
    dueDateTime.month,
    dueDateTime.day,
  );

  if (dueDate == today) {
    return _DueOption.today;
  }

  return _DueOption.tomorrow;
}
