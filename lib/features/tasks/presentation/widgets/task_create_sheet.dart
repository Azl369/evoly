import 'package:flutter/material.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_focus.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';

class TaskCreateSheet extends StatefulWidget {
  const TaskCreateSheet({
    required this.onCreate,
    super.key,
  });

  final Future<void> Function(String title, int estimatedMinutes) onCreate;

  @override
  State<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends State<TaskCreateSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _minutesController;
  late final FocusNode _titleFocusNode;
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
    return ResponsiveBottomSheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('新增子任务', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            decoration: const InputDecoration(
              labelText: '任务名称',
              hintText: '例如：完成第一章练习',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '预计耗时（分钟）',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _saving ? null : _create,
            icon: const Icon(Icons.add_rounded),
            label: Text(_saving ? '添加中...' : '添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    setState(() => _saving = true);
    final estimatedMinutes = int.tryParse(_minutesController.text.trim()) ?? 30;
    await widget.onCreate(title, estimatedMinutes.clamp(1, 1440));
    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
