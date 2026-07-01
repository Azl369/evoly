import 'dart:async';

import 'package:flutter/material.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_focus.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';

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
        minHeight: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '编辑目标',
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
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              decoration: const InputDecoration(labelText: '目标名称'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '目标描述'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<Priority>(
              initialValue: _selectedPriority,
              decoration: const InputDecoration(labelText: '优先级'),
              items: Priority.values.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Text(priority.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedPriority = value);
                _scheduleSave();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<GoalStatus>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(labelText: '目标状态'),
              items: GoalStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.label),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedStatus = value);
                _scheduleSave();
              },
            ),
            const SizedBox(height: AppSpacing.md),
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
