import 'package:flutter/material.dart';
import 'package:evoly/features/reminders/presentation/task_reminder_picker.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_form_layout.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_focus.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_due_picker.dart';

class TaskCreateSheet extends StatefulWidget {
  const TaskCreateSheet({
    required this.onCreate,
    super.key,
    this.customDueDateTimePicker = showTaskDueDateTimePicker,
  });

  final Future<void> Function(
    String title,
    int estimatedMinutes,
    DateTime? dueDateTime,
    TaskReminderSelection reminder,
  ) onCreate;
  final TaskDueDateTimePicker customDueDateTimePicker;

  @override
  State<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends State<TaskCreateSheet> {
  static const _defaultEstimatedMinutes = 30;

  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  late DateTime? _selectedDueDateTime;
  var _selectedReminder = TaskReminderSelection.none;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _titleFocusNode = FocusNode();
    _selectedDueDateTime = endOfToday(DateTime.now());
    requestFocusAfterBottomSheetEntrance(this, _titleFocusNode);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetFormLayout(
      title: '新增子任务',
      footer: FilledButton.icon(
        onPressed: _saving ? null : _create,
        icon: const Icon(Icons.add_rounded),
        label: Text(_saving ? '添加中...' : '添加'),
      ),
      children: [
        AppField(
          label: '任务名称',
          isRequired: true,
          child: TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            decoration: const InputDecoration(
              hintText: '例如：完成第一章练习',
            ),
          ),
        ),
        AppField(
          label: '截止时间',
          child: TaskDuePicker(
            dueDateTime: _selectedDueDateTime,
            customPicker: widget.customDueDateTimePicker,
            onChanged: (value) {
              setState(() => _selectedDueDateTime = value);
            },
          ),
        ),
        AppField(
          label: '提醒',
          child: TaskReminderPicker(
            selection: _selectedReminder,
            onChanged: (value) {
              setState(() => _selectedReminder = value);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    setState(() => _saving = true);
    await widget.onCreate(
      title,
      _defaultEstimatedMinutes,
      _selectedDueDateTime,
      _selectedReminder,
    );
    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
