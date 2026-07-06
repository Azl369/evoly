import 'package:flutter/material.dart';
import 'package:evoly/features/reminders/presentation/task_reminder_picker.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_form_layout.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_focus.dart';
import 'package:evoly/shared/ui/components/app_components.dart';

class TaskCreateSheet extends StatefulWidget {
  const TaskCreateSheet({
    required this.onCreate,
    super.key,
  });

  final Future<void> Function(
    String title,
    int estimatedMinutes,
    TaskReminderSelection reminder,
  ) onCreate;

  @override
  State<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends State<TaskCreateSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _minutesController;
  late final FocusNode _titleFocusNode;
  var _selectedReminder = TaskReminderSelection.none;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _minutesController = TextEditingController(text: '30');
    _titleFocusNode = FocusNode();
    requestFocusAfterBottomSheetEntrance(this, _titleFocusNode);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _minutesController.dispose();
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
          label: '预计耗时（分钟）',
          child: TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(),
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
    final estimatedMinutes = int.tryParse(_minutesController.text.trim()) ?? 30;
    await widget.onCreate(
      title,
      estimatedMinutes.clamp(1, 1440),
      _selectedReminder,
    );
    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
