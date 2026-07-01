import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/goals/presentation/widgets/goal_edit_sheet.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_focus.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';
import 'package:evoly/shared/ui/components/animated_progress_bar.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/widgets/empty_state.dart';
import 'package:evoly/shared/widgets/evoly_navigation_bar.dart';
import 'package:uuid/uuid.dart';

class GoalListPage extends StatefulWidget {
  const GoalListPage({
    this.showBottomNavigationBar = true,
    super.key,
  });

  final bool showBottomNavigationBar;

  @override
  State<GoalListPage> createState() => _GoalListPageState();
}

class _GoalListPageState extends State<GoalListPage> {
  final List<Goal> _goals = [];
  var _loading = true;
  var _statusFilter = _GoalStatusFilter.active;
  var _sortMode = _GoalSortMode.updatedDesc;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGoals());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目标'),
        actions: [
          PopupMenuButton<_GoalSortMode>(
            tooltip: '排序',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sortMode,
            onSelected: (sortMode) {
              setState(() => _sortMode = sortMode);
            },
            itemBuilder: (context) => _GoalSortMode.values.map((sortMode) {
              return PopupMenuItem(
                value: sortMode,
                child: Text(sortMode.label),
              );
            }).toList(),
          ),
          IconButton(
            onPressed: _showCreateGoalSheet,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: widget.showBottomNavigationBar
          ? const EvolyNavigationBar(selectedIndex: 1)
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        message: errorMessage,
      );
    }

    final visibleGoals = _visibleGoals;

    if (_goals.isEmpty) {
      return const EmptyState(
        icon: Icons.flag_outlined,
        title: '还没有目标',
        message: '点右上角的加号，给今天埋下一颗小种子。',
      );
    }

    if (visibleGoals.isEmpty) {
      return Column(
        children: [
          _GoalFilterBar(
            selected: _statusFilter,
            onChanged: (filter) => setState(() => _statusFilter = filter),
          ),
          const Expanded(
            child: EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: '没有符合条件的目标',
              message: '换个筛选条件看看，目标可能只是躲起来了。',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      itemCount: visibleGoals.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _GoalFilterBar(
            selected: _statusFilter,
            onChanged: (filter) => setState(() => _statusFilter = filter),
          );
        }

        final goal = visibleGoals[index - 1];

        return _GoalCard(
          goal: goal,
          onOpen: () async {
            await Navigator.pushNamed(
              context,
              AppRoutes.goalDetail,
              arguments: goal.id,
            );
            await _loadGoals();
          },
          onEdit: () => _showEditGoalSheet(goal),
          onDelete: () => _deleteGoal(goal),
        );
      },
    );
  }

  List<Goal> get _visibleGoals {
    final filtered = _goals.where((goal) {
      return switch (_statusFilter) {
        _GoalStatusFilter.all => true,
        _GoalStatusFilter.active => goal.isActive,
        _GoalStatusFilter.completed => goal.status == GoalStatus.completed,
        _GoalStatusFilter.paused => goal.status == GoalStatus.paused,
        _GoalStatusFilter.abandoned => goal.status == GoalStatus.abandoned,
      };
    }).toList();

    filtered.sort((left, right) {
      return switch (_sortMode) {
        _GoalSortMode.updatedDesc => right.updatedAt.compareTo(left.updatedAt),
        _GoalSortMode.dueDateAsc => _compareNullableDate(
            left.dueDate,
            right.dueDate,
          ),
        _GoalSortMode.priorityDesc =>
          right.priority.weight.compareTo(left.priority.weight),
        _GoalSortMode.progressAsc =>
          left.normalizedProgress.compareTo(right.normalizedProgress),
        _GoalSortMode.titleAsc => left.title.compareTo(right.title),
      };
    });

    return filtered;
  }

  int _compareNullableDate(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }

    return left.compareTo(right);
  }

  Future<void> _showEditGoalSheet(Goal goal) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return GoalEditSheet(
          goal: goal,
          onSave: _saveGoal,
        );
      },
    );

    if (updated == true) {
      await _loadGoals();
    }
  }

  Future<void> _saveGoal(Goal goal) async {
    try {
      await context.read<GoalRepository>().save(goal);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
      rethrow;
    }
  }

  Future<void> _deleteGoal(Goal goal) async {
    final repository = context.read<GoalRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除目标？'),
          content: Text('「${goal.title}」和它的子任务都会被删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final index = _goals.indexWhere((item) => item.id == goal.id);
    if (index == -1) {
      return;
    }

    setState(() {
      _goals.removeAt(index);
    });

    try {
      await repository.delete(goal.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目标已删除')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _goals.insert(index, goal);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$error')),
      );
    }
  }

  Future<void> _loadGoals() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<GoalRepository>();
      final goals = await repository.findAll();
      if (!mounted) {
        return;
      }

      setState(() {
        _goals
          ..clear()
          ..addAll(goals);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showCreateGoalSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) =>
          _CreateGoalSheet(onSubmit: _createGoalWithFirstTask),
    );

    if (created == true) {
      await _loadGoals();
    }
  }

  Future<void> _createGoalWithFirstTask(String title, String taskTitle) async {
    const uuid = Uuid();
    final goalRepository = context.read<GoalRepository>();
    final taskRepository = context.read<TaskRepository>();
    final now = DateTime.now();
    final goalId = uuid.v4();

    final goal = Goal(
      id: goalId,
      title: title,
      type: GoalType.longTerm,
      priority: Priority.medium,
      status: GoalStatus.inProgress,
      startDate: now,
      dueDate: now.add(const Duration(days: 30)),
      createdAt: now,
      updatedAt: now,
    );

    final task = TaskItem(
      id: uuid.v4(),
      goalId: goalId,
      title: taskTitle,
      priority: Priority.high,
      status: TaskStatus.pending,
      estimatedMinutes: 30,
      dueDateTime: DateTime(now.year, now.month, now.day, 23, 59),
      createdAt: now,
      updatedAt: now,
    );

    await goalRepository.save(goal);
    await taskRepository.save(task);
  }
}

class _CreateGoalSheet extends StatefulWidget {
  const _CreateGoalSheet({required this.onSubmit});

  final Future<void> Function(String title, String taskTitle) onSubmit;

  @override
  State<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<_CreateGoalSheet> {
  final _titleController = TextEditingController();
  final _taskController = TextEditingController();
  final _titleFocusNode = FocusNode();
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    requestFocusAfterBottomSheetEntrance(this, _titleFocusNode);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final taskTitle = _taskController.text.trim();
    if (title.isEmpty || taskTitle.isEmpty || _submitting) {
      return;
    }

    setState(() => _submitting = true);
    await widget.onSubmit(title, taskTitle);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _taskController.dispose();
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
          Text('新建目标', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            decoration: const InputDecoration(
              labelText: '目标名称',
              hintText: '例如：30 天完成 Flutter 基础',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _taskController,
            decoration: const InputDecoration(
              labelText: '今天第一步',
              hintText: '例如：学习布局 30 分钟',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.add_rounded),
            label: Text(_submitting ? '创建中…' : '创建'),
          ),
        ],
      ),
    );
  }
}

class _GoalFilterBar extends StatelessWidget {
  const _GoalFilterBar({
    required this.selected,
    required this.onChanged,
  });

  final _GoalStatusFilter selected;
  final ValueChanged<_GoalStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_GoalStatusFilter>(
        selected: {selected},
        onSelectionChanged: (values) => onChanged(values.first),
        segments: _GoalStatusFilter.values.map((filter) {
          return ButtonSegment(
            value: filter,
            label: Text(filter.label),
          );
        }).toList(),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Goal goal;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final isCompleted = goal.status == GoalStatus.completed;
    final titleStyle = textTheme.titleMedium?.copyWith(
      decoration: isCompleted ? TextDecoration.lineThrough : null,
      color: isCompleted ? colors.onSurfaceVariant : null,
    );

    return Dismissible(
      key: ValueKey(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(goal.title, style: titleStyle),
                    ),
                    PopupMenuButton<_GoalCardAction>(
                      onSelected: (action) {
                        switch (action) {
                          case _GoalCardAction.edit:
                            onEdit();
                          case _GoalCardAction.delete:
                            onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _GoalCardAction.edit,
                          child: Text('编辑'),
                        ),
                        PopupMenuItem(
                          value: _GoalCardAction.delete,
                          child: Text('删除'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedProgressBar(value: goal.normalizedProgress),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _GoalChip(label: '优先级：${goal.priority.label}'),
                    _GoalChip(label: goal.status.label),
                    if (goal.dueDate != null)
                      _GoalChip(label: '截止：${_formatDate(goal.dueDate!)}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      backgroundColor: colors.surfaceContainerHighest,
      side: BorderSide.none,
    );
  }
}

enum _GoalStatusFilter {
  all,
  active,
  completed,
  paused,
  abandoned,
}

extension _GoalStatusFilterLabel on _GoalStatusFilter {
  String get label {
    return switch (this) {
      _GoalStatusFilter.all => '全部',
      _GoalStatusFilter.active => '进行中',
      _GoalStatusFilter.completed => '已完成',
      _GoalStatusFilter.paused => '已暂停',
      _GoalStatusFilter.abandoned => '已放弃',
    };
  }
}

enum _GoalSortMode {
  updatedDesc,
  dueDateAsc,
  priorityDesc,
  progressAsc,
  titleAsc,
}

extension _GoalSortModeLabel on _GoalSortMode {
  String get label {
    return switch (this) {
      _GoalSortMode.updatedDesc => '最近更新',
      _GoalSortMode.dueDateAsc => '截止时间',
      _GoalSortMode.priorityDesc => '优先级高到低',
      _GoalSortMode.progressAsc => '进度少到多',
      _GoalSortMode.titleAsc => '名称 A-Z',
    };
  }
}

enum _GoalCardAction {
  edit,
  delete,
}
