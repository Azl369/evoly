import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/data_refresh_listener.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/goals/presentation/widgets/goal_edit_sheet.dart';
import 'package:evoly/features/sync/presentation/sync_refresh_indicator.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_focus.dart';
import 'package:evoly/shared/ui/bottom_sheets/responsive_bottom_sheet_body.dart';
import 'package:evoly/shared/ui/components/animated_progress_bar.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';
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

class _GoalListPageState extends State<GoalListPage>
    with DataRefreshListener<GoalListPage> {
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
  Future<void> reloadDataForRefresh() => _loadGoals();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目标'),
        actions: [
          IconButton(
            tooltip: '排序',
            onPressed: _showSortPickerSheet,
            icon: const Icon(Icons.tune_rounded),
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
      return const AppLoadingState(label: '正在整理目标');
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
        message: '点击右上角新建目标。',
      );
    }

    if (visibleGoals.isEmpty) {
      return Column(
        children: [
          _GoalFilterBar(
            selected: _statusFilter,
            goals: _goals,
            onChanged: (filter) => setState(() => _statusFilter = filter),
          ),
          const Expanded(
            child: EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: '没有符合条件的目标',
              message: '请调整筛选条件。',
            ),
          ),
        ],
      );
    }

    return SyncRefreshIndicator(
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        scrollCacheExtent: const ScrollCacheExtent.pixels(720),
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        itemCount: visibleGoals.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GoalFilterBar(
              selected: _statusFilter,
              goals: _goals,
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
      ),
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

  Future<void> _showSortPickerSheet() async {
    final selectedSortMode = await showGeneralDialog<_GoalSortMode>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.04),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: MotionTokens.fast,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _GoalSortWheelPopover(selected: _sortMode);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: MotionTokens.standard,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curvedAnimation),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );

    if (selectedSortMode == null || selectedSortMode == _sortMode || !mounted) {
      return;
    }

    setState(() => _sortMode = selectedSortMode);
  }

  Future<void> _showEditGoalSheet(Goal goal) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      requestFocus: false,
      showDragHandle: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: MotionTokens.slow,
        reverseDuration: MotionTokens.fast,
      ),
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
      if (mounted) {
        notifyDataChanged();
      }
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

      notifyDataChanged();

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
    if (mounted) {
      notifyDataChanged();
    }
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

class _GoalSortWheelPopover extends StatefulWidget {
  const _GoalSortWheelPopover({required this.selected});

  final _GoalSortMode selected;

  @override
  State<_GoalSortWheelPopover> createState() => _GoalSortWheelPopoverState();
}

class _GoalSortWheelPopoverState extends State<_GoalSortWheelPopover> {
  late _GoalSortMode _selected;
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _controller = FixedExtentScrollController(
      initialItem: _GoalSortMode.values.indexOf(widget.selected),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned(
          top: topPadding + kToolbarHeight + AppSpacing.xs,
          right: AppSpacing.sm,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 196,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '排序方式',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          tooltip: '完成',
                          onPressed: () => Navigator.pop(context, _selected),
                          icon: const Icon(Icons.check_rounded, size: 18),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 224,
                      child: CupertinoPicker(
                        scrollController: _controller,
                        itemExtent: 42,
                        magnification: 1.04,
                        squeeze: 1.1,
                        useMagnifier: true,
                        selectionOverlay: const _GoalSortSelectionOverlay(),
                        onSelectedItemChanged: (index) {
                          setState(
                            () => _selected = _GoalSortMode.values[index],
                          );
                        },
                        children: [
                          for (final sortMode in _GoalSortMode.values)
                            Center(
                              child: AnimatedDefaultTextStyle(
                                duration: MotionTokens.fast,
                                curve: MotionTokens.standard,
                                style: (sortMode == _selected
                                            ? theme.textTheme.titleSmall
                                            : theme.textTheme.bodyMedium)
                                        ?.copyWith(
                                      color: sortMode == _selected
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: sortMode == _selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ) ??
                                    const TextStyle(),
                                child: Text(sortMode.label),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalSortSelectionOverlay extends StatelessWidget {
  const _GoalSortSelectionOverlay();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: IgnorePointer(
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.22),
                colorScheme.secondaryContainer.withValues(alpha: 0.22),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.16),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalFilterBar extends StatelessWidget {
  const _GoalFilterBar({
    required this.selected,
    required this.goals,
    required this.onChanged,
  });

  final _GoalStatusFilter selected;
  final List<Goal> goals;
  final ValueChanged<_GoalStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _GoalStatusFilter.values) ...[
            _GoalFilterChip(
              filter: filter,
              count: _countFor(filter),
              selected: selected == filter,
              onTap: () => onChanged(filter),
            ),
            if (filter != _GoalStatusFilter.values.last)
              const SizedBox(width: AppSpacing.sm),
          ],
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.swipe_rounded,
            size: 16,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  int _countFor(_GoalStatusFilter filter) {
    return goals.where((goal) {
      return switch (filter) {
        _GoalStatusFilter.all => true,
        _GoalStatusFilter.active => goal.isActive,
        _GoalStatusFilter.completed => goal.status == GoalStatus.completed,
        _GoalStatusFilter.paused => goal.status == GoalStatus.paused,
        _GoalStatusFilter.abandoned => goal.status == GoalStatus.abandoned,
      };
    }).length;
  }
}

class _GoalFilterChip extends StatelessWidget {
  const _GoalFilterChip({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _GoalStatusFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foregroundColor = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: '${filter.label}，$count 个目标',
      child: AnimatedContainer(
        duration: MotionTokens.fast,
        curve: MotionTokens.standard,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.18)
                : colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: selected ? null : onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: selected ? AppSpacing.md : AppSpacing.sm + 2,
                vertical: AppSpacing.xs + 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: MotionTokens.fast,
                    curve: MotionTokens.standard,
                    child: Icon(
                      Icons.check_rounded,
                      size: selected ? 16 : 0,
                      color: foregroundColor,
                    ),
                  ),
                  if (selected) const SizedBox(width: AppSpacing.xs),
                  Text(
                    filter.label,
                    style: textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedContainer(
                    duration: MotionTokens.fast,
                    curve: MotionTokens.standard,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.surface.withValues(alpha: 0.58)
                          : colorScheme.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: textTheme.labelSmall?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    final tokens = EvolyDesignTokens.of(context);
    final isCompleted = goal.status == GoalStatus.completed;
    final titleStyle = textTheme.titleSmall?.copyWith(
      decoration: isCompleted ? TextDecoration.lineThrough : null,
      color: isCompleted ? colors.onSurfaceVariant : null,
    );
    final progressPercent = (goal.normalizedProgress * 100).round();

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
      child: AppSurfaceCard(
        onTap: onOpen,
        elevated: !isCompleted,
        backgroundColor: isCompleted
            ? colors.surfaceContainerHighest.withValues(alpha: 0.60)
            : tokens.surfaceRaised,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.compact,
          AppSpacing.sm,
          AppSpacing.compact,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _priorityColor(tokens, goal.priority)
                        .withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: Icon(
                        Icons.flag_rounded,
                        size: 12,
                        color: _priorityColor(tokens, goal.priority),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    goal.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                IconButton(
                  tooltip: '编辑目标',
                  onPressed: onEdit,
                  icon: const Icon(Icons.more_horiz_rounded),
                  iconSize: 22,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AnimatedProgressBar(value: goal.normalizedProgress),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$progressPercent%',
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                AppMetaPill(
                  label: '优先级：${goal.priority.label}',
                  icon: Icons.flag_rounded,
                  color: _priorityColor(tokens, goal.priority),
                  selected: true,
                ),
                AppStatusBadge(
                  label: goal.status.label,
                  color: _statusColor(tokens, colors, goal.status),
                ),
                if (goal.dueDate != null)
                  AppMetaPill(
                    label: '截止：${_formatDate(goal.dueDate!)}',
                    icon: Icons.schedule_outlined,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
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
    GoalStatus status,
  ) {
    return switch (status) {
      GoalStatus.notStarted => tokens.statusNeutral,
      GoalStatus.inProgress => tokens.statusInfo,
      GoalStatus.completed => tokens.statusSuccess,
      GoalStatus.paused => tokens.statusWarning,
      GoalStatus.abandoned => colorScheme.error,
    };
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
