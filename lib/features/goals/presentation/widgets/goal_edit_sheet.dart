import 'dart:async';

import 'package:flutter/material.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_focus.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';
import 'package:evoly/shared/ui/components/slide_select_field.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';

class GoalEditSheet extends StatefulWidget {
  const GoalEditSheet({
    required this.goal,
    required this.onSave,
    super.key,
  });

  final Goal goal;
  final Future<void> Function(Goal updatedGoal) onSave;

  @override
  State<GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<GoalEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final FocusNode _titleFocusNode;
  late Goal _goal;

  late Priority _selectedPriority;
  late GoalStatus _selectedStatus;
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
    _goal = widget.goal;
    _titleController = TextEditingController(text: _goal.title);
    _descriptionController = TextEditingController(
      text: _goal.description,
    );
    _titleFocusNode = FocusNode();
    _selectedPriority = _goal.priority;
    _selectedStatus = _goal.status;
    _lastSavedSignature = _signatureFor(_goal);
    _titleController.addListener(_scheduleSave);
    _descriptionController.addListener(_scheduleSave);
    requestFocusAfterBottomSheetEntrance(this, _titleFocusNode);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleController.removeListener(_scheduleSave);
    _descriptionController.removeListener(_scheduleSave);
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
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
        minHeight: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '编辑目标',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _AutoSaveStatus(
                  saving: _saving,
                  errorMessage: _saveError,
                  hasSavedChanges: _hasSavedChanges,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              maxLines: 1,
              textInputAction: TextInputAction.next,
              decoration: _compactInputDecoration('目标名称'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descriptionController,
              minLines: 1,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: _compactInputDecoration('目标描述（可选）'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildMetaSelectors(context),
            const SizedBox(height: AppSpacing.compact),
            SizedBox(
              height: AppSpacing.minTouchTarget + AppSpacing.xs,
              child: FilledButton.icon(
                onPressed: _close,
                icon: const Icon(Icons.check_rounded),
                label: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaSelectors(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            children: [
              _buildPrioritySelector(),
              const SizedBox(height: AppSpacing.sm),
              _buildStatusSelector(),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _buildPrioritySelector()),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildStatusSelector()),
          ],
        );
      },
    );
  }

  InputDecoration _compactInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.compact,
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return SlideSelectField<Priority>(
      label: '优先级',
      values: const [Priority.high, Priority.medium, Priority.low],
      value: _selectedPriority,
      labelBuilder: (priority) => priority.label,
      icon: Icons.flag_rounded,
      colorBuilder: _priorityColor,
      onChanged: _changePriority,
      compact: true,
      semanticHint: '长按后上下滑动选择目标优先级',
    );
  }

  Widget _buildStatusSelector() {
    return SlideSelectField<GoalStatus>(
      label: '目标状态',
      values: GoalStatus.values,
      value: _selectedStatus,
      labelBuilder: (status) => status.label,
      icon: Icons.track_changes_rounded,
      colorBuilder: _statusColor,
      onChanged: _changeStatus,
      compact: true,
      semanticHint: '长按后上下滑动选择目标状态',
    );
  }

  void _changePriority(Priority priority) {
    if (priority == _selectedPriority) {
      return;
    }

    setState(() => _selectedPriority = priority);
    _scheduleSave();
  }

  void _changeStatus(GoalStatus status) {
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
        setState(() => _saveError = '目标名称不能为空');
      }
      return;
    }

    final updatedGoal = _buildUpdatedGoal(title);
    final signature = _signatureFor(updatedGoal);
    if (signature == _lastSavedSignature) {
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(updatedGoal);
      if (!mounted) {
        return;
      }

      setState(() {
        _goal = updatedGoal;
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

  Goal _buildUpdatedGoal(String title) {
    return _goal.copyWith(
      title: title,
      description: _descriptionController.text.trim(),
      priority: _selectedPriority,
      status: _selectedStatus,
      updatedAt: DateTime.now(),
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

  String _signatureFor(Goal goal) {
    return [
      goal.title,
      goal.description,
      goal.priority.name,
      goal.status.name,
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

  Color _statusColor(BuildContext context, GoalStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = EvolyDesignTokens.of(context);

    return switch (status) {
      GoalStatus.notStarted => tokens.statusNeutral,
      GoalStatus.inProgress => tokens.statusInfo,
      GoalStatus.completed => tokens.statusSuccess,
      GoalStatus.paused => tokens.statusWarning,
      GoalStatus.abandoned => colorScheme.error,
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
