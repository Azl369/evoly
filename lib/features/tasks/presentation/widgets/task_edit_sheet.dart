import 'dart:async';

import 'package:flutter/material.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:evoly/features/reminders/presentation/task_reminder_picker.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_due_picker.dart';
import 'package:evoly/shared/ui/bottom_sheets/adaptive_form_modal.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_form_layout.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

class TaskEditSheet extends StatefulWidget {
  const TaskEditSheet({
    required this.title,
    required this.task,
    required this.reminder,
    required this.onSave,
    this.availableGoals = const [],
    this.customDueDateTimePicker = showTaskDueDateTimePicker,
    super.key,
  });

  final String title;
  final TaskItem task;
  final Reminder? reminder;
  final List<Goal> availableGoals;
  final TaskDueDateTimePicker customDueDateTimePicker;
  final Future<void> Function(
    TaskItem updatedTask,
    TaskReminderSelection reminder,
  ) onSave;

  @override
  State<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<TaskEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TaskItem _task;

  late Priority _selectedPriority;
  late TaskStatus _selectedStatus;
  late String _selectedGoalId;
  DateTime? _selectedDueDateTime;
  late TaskReminderSelection _selectedReminder;
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
    _selectedGoalId = _task.goalId;
    _selectedPriority = _task.priority;
    _selectedStatus = _task.effectiveStatus(DateTime.now());
    _selectedDueDateTime = _task.dueDateTime;
    _selectedReminder = TaskReminderSelection.fromReminder(widget.reminder);
    _lastSavedSignature = _signatureFor(_task, _selectedReminder);
    _titleController.addListener(_scheduleSave);
    _descriptionController.addListener(_scheduleSave);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleController.removeListener(_scheduleSave);
    _descriptionController.removeListener(_scheduleSave);
    _titleController.dispose();
    _descriptionController.dispose();
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
      child: BottomSheetFormLayout(
        minHeight: 320,
        headerSpacing: AppSpacing.compact,
        title: widget.title,
        trailing: _AutoSaveStatus(
          saving: _saving,
          errorMessage: _saveError,
          hasSavedChanges: _hasSavedChanges,
        ),
        footer: FilledButton.icon(
          onPressed: _close,
          icon: const Icon(Icons.check_rounded),
          label: const Text('完成'),
        ),
        children: [
          AppField(
            label: '任务名称',
            isRequired: true,
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(),
            ),
          ),
          AppField(
            label: '任务说明',
            child: TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(),
            ),
          ),
          if (_projectOptions.length > 1)
            AppField(
              label: '所属项目',
              child: _ProjectPickerField(
                option: _selectedProjectOption,
                onTap: _showProjectPicker,
              ),
            ),
          _TaskOptionGroup<Priority>(
            label: '优先级',
            values: const [Priority.high, Priority.medium, Priority.low],
            value: _selectedPriority,
            labelBuilder: (priority) => priority.label,
            iconBuilder: (_) => Icons.flag_rounded,
            colorBuilder: _priorityColor,
            onChanged: _changePriority,
          ),
          _TaskOptionGroup<TaskStatus>(
            label: '状态',
            values: TaskStatus.values,
            value: _selectedStatus,
            labelBuilder: (status) => status.label,
            iconBuilder: _statusIcon,
            colorBuilder: _statusColor,
            onChanged: _changeStatus,
          ),
          AppField(
            label: '截止时间',
            child: TaskDuePicker(
              dueDateTime: _selectedDueDateTime,
              customPicker: widget.customDueDateTimePicker,
              onChanged: (value) {
                setState(() => _selectedDueDateTime = value);
                _scheduleSave();
              },
            ),
          ),
          AppField(
            label: '提醒',
            child: TaskReminderPicker(
              selection: _selectedReminder,
              onChanged: (value) {
                setState(() => _selectedReminder = value);
                _scheduleSave();
              },
            ),
          ),
        ],
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

  Future<void> _showProjectPicker() async {
    FocusScope.of(context).unfocus();
    final selectedGoalId = await showAdaptiveFormModal<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      requestFocus: false,
      builder: (context) {
        return _ProjectSelectorSheet(
          options: _projectOptions,
          selectedGoalId: _selectedGoalId,
        );
      },
    );

    if (!mounted || selectedGoalId == null) {
      return;
    }

    _changeGoal(selectedGoalId);
  }

  void _changeGoal(String? goalId) {
    if (goalId == null || goalId == _selectedGoalId) {
      return;
    }

    setState(() => _selectedGoalId = goalId);
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
    final signature = _signatureFor(updatedTask, _selectedReminder);
    if (signature == _lastSavedSignature) {
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(updatedTask, _selectedReminder);
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
    final now = DateTime.now();
    return _task.copyWith(
      goalId: _selectedGoalId,
      title: title,
      description: _descriptionController.text.trim(),
      priority: _selectedPriority,
      status: _selectedStatus,
      estimatedMinutes: _task.estimatedMinutes,
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

  String _signatureFor(TaskItem task, TaskReminderSelection reminder) {
    return [
      task.title,
      task.goalId,
      task.description,
      task.priority.name,
      task.status.name,
      task.estimatedMinutes,
      task.dueDateTime?.millisecondsSinceEpoch,
      task.completedAt?.millisecondsSinceEpoch,
      reminder.remindAt?.millisecondsSinceEpoch,
      reminder.repeatRule.name,
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

  IconData _statusIcon(TaskStatus status) {
    return switch (status) {
      TaskStatus.pending => Icons.radio_button_unchecked_rounded,
      TaskStatus.completed => Icons.check_circle_rounded,
      TaskStatus.postponed => Icons.event_repeat_rounded,
      TaskStatus.cancelled => Icons.cancel_rounded,
    };
  }

  List<_ProjectOption> get _projectOptions {
    final options = <_ProjectOption>[
      for (final goal in widget.availableGoals)
        if (goal.title.trim().isNotEmpty)
          _ProjectOption(id: goal.id, title: goal.title.trim()),
    ];

    if (!options.any((option) => option.id == _selectedGoalId)) {
      options.insert(
        0,
        _ProjectOption(id: _selectedGoalId, title: '未同步项目'),
      );
    }

    return options;
  }

  _ProjectOption get _selectedProjectOption {
    return _projectOptions.firstWhere(
      (option) => option.id == _selectedGoalId,
      orElse: () => _ProjectOption(
        id: _selectedGoalId,
        title: '未同步项目',
      ),
    );
  }
}

class _ProjectOption {
  const _ProjectOption({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;
}

class _ProjectPickerField extends StatelessWidget {
  const _ProjectPickerField({
    required this.option,
    required this.onTap,
  });

  final _ProjectOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return AppSurface(
      variant: AppSurfaceVariant.muted,
      radius: AppRadii.element,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.workspaces_outline,
            size: 20,
            color: tokens.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              option.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyLarge?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.keyboard_arrow_right_rounded,
            color: tokens.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _ProjectSelectorSheet extends StatefulWidget {
  const _ProjectSelectorSheet({
    required this.options,
    required this.selectedGoalId,
  });

  final List<_ProjectOption> options;
  final String selectedGoalId;

  @override
  State<_ProjectSelectorSheet> createState() => _ProjectSelectorSheetState();
}

class _ProjectSelectorSheetState extends State<_ProjectSelectorSheet> {
  late final TextEditingController _queryController;
  var _query = '';

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _queryController.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_handleQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredOptions = _filteredOptions;

    return BottomSheetFormLayout(
      title: '选择所属项目',
      minHeight: 420,
      footer: TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      children: [
        TextField(
          controller: _queryController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: '搜索项目',
          ),
        ),
        if (filteredOptions.isEmpty)
          const AppSurface(
            variant: AppSurfaceVariant.muted,
            child: Text('没有匹配的项目'),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in filteredOptions) ...[
                _ProjectSelectorRow(
                  option: option,
                  selected: option.id == widget.selectedGoalId,
                  onTap: () => Navigator.pop(context, option.id),
                ),
                if (option != filteredOptions.last)
                  const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ),
      ],
    );
  }

  void _handleQueryChanged() {
    setState(() => _query = _queryController.text.trim());
  }

  List<_ProjectOption> get _filteredOptions {
    final query = _query.toLowerCase();
    if (query.isEmpty) {
      return widget.options;
    }

    return widget.options.where((option) {
      return option.title.toLowerCase().contains(query);
    }).toList();
  }
}

class _ProjectSelectorRow extends StatelessWidget {
  const _ProjectSelectorRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ProjectOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return AppSurface(
      variant: selected ? AppSurfaceVariant.selected : AppSurfaceVariant.plain,
      radius: AppRadii.element,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.workspaces_outline,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              option.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyLarge?.copyWith(
                color: tokens.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            child: Icon(
              Icons.check_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskOptionGroup<T> extends StatelessWidget {
  const _TaskOptionGroup({
    required this.label,
    required this.values,
    required this.value,
    required this.labelBuilder,
    required this.iconBuilder,
    required this.colorBuilder,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T value;
  final String Function(T value) labelBuilder;
  final IconData Function(T value) iconBuilder;
  final Color Function(BuildContext context, T value) colorBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: AppField(
        label: label,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final option in values)
              _TaskOptionChip<T>(
                label: labelBuilder(option),
                icon: iconBuilder(option),
                color: colorBuilder(context, option),
                selected: option == value,
                onSelected: () => onChanged(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskOptionChip<T> extends StatelessWidget {
  const _TaskOptionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = EvolyDesignTokens.of(context);
    final selectedAlpha =
        colorScheme.brightness == Brightness.dark ? 0.18 : 0.12;
    final backgroundColor = selected
        ? Color.alphaBlend(
            color.withValues(alpha: selectedAlpha),
            tokens.cardSurface,
          )
        : tokens.surfaceMuted;
    final foregroundColor = selected ? color : colorScheme.onSurface;
    final borderColor =
        selected ? color.withValues(alpha: 0.44) : tokens.borderSubtle;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72, minHeight: 36),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        mouseCursor: SystemMouseCursors.click,
        avatar: Icon(
          icon,
          size: 16,
          color: foregroundColor,
        ),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foregroundColor,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
        backgroundColor: backgroundColor,
        selectedColor: backgroundColor,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (_) => onSelected(),
      ),
    );
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
