import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/data_refresh_listener.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/coach/application/rule_based_coach_service.dart';
import 'package:evoly/features/coach/domain/coach_insight.dart';
import 'package:evoly/features/desktop_window/application/desktop_window_controller.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/reminders/application/reminder_inbox.dart';
import 'package:evoly/features/reminders/application/task_reminder_service.dart';
import 'package:evoly/features/sync/presentation/sync_refresh_indicator.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_card.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_edit_sheet.dart';
import 'package:evoly/shared/ui/bottom_sheets/adaptive_form_modal.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_focus.dart';
import 'package:evoly/shared/ui/bottom_sheets/bottom_sheet_form_layout.dart';
import 'package:evoly/shared/ui/components/animated_progress_bar.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';
import 'package:evoly/shared/widgets/empty_state.dart';
import 'package:evoly/shared/widgets/evoly_navigation_bar.dart';
import 'package:uuid/uuid.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({
    this.showBottomNavigationBar = true,
    this.onTopLevelDestinationSelected,
    super.key,
  });

  final bool showBottomNavigationBar;
  final ValueChanged<int>? onTopLevelDestinationSelected;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage>
    with DataRefreshListener<TodayPage> {
  final _desktopTaskScrollController = ScrollController();
  final _desktopOverviewScrollController = ScrollController();
  final List<TaskItem> _tasks = [];
  final List<Goal> _goals = [];
  DesktopWindowController? _desktopWindowController;
  var _loading = true;
  var _coachExpanded = true;
  var _pendingTaskOpenScheduled = false;
  String? _errorMessage;
  CoachInsight? _coachInsight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTasks();
      await _showDueReminders();
    });
  }

  @override
  Future<void> reloadDataForRefresh() => _loadTasks();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final DesktopWindowController controller;
    try {
      controller = context.read<DesktopWindowController>();
    } on ProviderNotFoundException {
      return;
    }

    if (_desktopWindowController == controller) {
      return;
    }

    _desktopWindowController?.removeListener(_handleDesktopWindowChanged);
    _desktopWindowController = controller;
    controller.addListener(_handleDesktopWindowChanged);
    _handleDesktopWindowChanged();
  }

  @override
  void dispose() {
    _desktopWindowController?.removeListener(_handleDesktopWindowChanged);
    _desktopTaskScrollController.dispose();
    _desktopOverviewScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _tasks.where((task) => task.isCompleted).length;
    final progress = _tasks.isEmpty ? 0.0 : completedCount / _tasks.length;
    final useDesktopLayout = MediaQuery.sizeOf(context).width >= 900;

    return AppPageScaffold(
      title: '计划',
      actions: [
        IconButton(
          tooltip: '新建项目',
          onPressed: _showCreateProjectSheet,
          icon: const Icon(Icons.add_rounded),
        ),
        if (!useDesktopLayout)
          IconButton(
            tooltip: '设置',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
      ],
      body: _buildBody(progress),
      bottomNavigationBar: widget.showBottomNavigationBar
          ? const EvolyNavigationBar(selectedIndex: 0)
          : null,
    );
  }

  Widget _buildBody(double progress) {
    if (_loading) {
      return const AppLoadingState(label: '正在整理计划');
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        message: errorMessage,
      );
    }

    final taskGroups = _taskGroups;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return _buildDesktopBody(progress, taskGroups, constraints.maxWidth);
        }

        return _buildMobileBody(progress, taskGroups);
      },
    );
  }

  Widget _buildMobileBody(
    double progress,
    List<_TaskGroup> taskGroups,
  ) {
    return SyncRefreshIndicator(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        scrollCacheExtent: const ScrollCacheExtent.pixels(720),
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          _buildTodayOverview(progress),
          _buildTaskSectionHeader(),
          if (_tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: EmptyState(
                icon: Icons.task_alt_outlined,
                title: '暂时没有待推进任务',
                message: '去项目页创建项目或子任务。',
              ),
            )
          else
            ..._buildTaskGroupWidgets(taskGroups),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(
    double progress,
    List<_TaskGroup> taskGroups,
    double maxWidth,
  ) {
    final sideWidth = maxWidth >= 1180 ? 392.0 : 348.0;

    return SyncRefreshIndicator(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDesktopTaskPane(taskGroups)),
            const SizedBox(width: AppSpacing.lg),
            SizedBox(
              width: sideWidth,
              child: Scrollbar(
                controller: _desktopOverviewScrollController,
                child: ListView(
                  controller: _desktopOverviewScrollController,
                  padding: EdgeInsets.zero,
                  children: [_buildTodayOverview(progress)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTaskPane(List<_TaskGroup> taskGroups) {
    return Scrollbar(
      controller: _desktopTaskScrollController,
      child: ListView(
        controller: _desktopTaskScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        scrollCacheExtent: const ScrollCacheExtent.pixels(720),
        padding: EdgeInsets.zero,
        children: [
          _buildTaskSectionHeader(compact: true),
          const SizedBox(height: AppSpacing.xs),
          if (_tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: EmptyState(
                icon: Icons.task_alt_outlined,
                title: '暂时没有待推进任务',
                message: '去项目页创建项目或子任务。',
                compact: true,
              ),
            )
          else
            ..._buildTaskGroupWidgets(taskGroups),
        ],
      ),
    );
  }

  Widget _buildTaskSectionHeader({bool compact = false}) {
    final completedCount = _tasks.where((task) => task.isCompleted).length;
    final pendingCount = _tasks.length - completedCount;

    return AppSectionHeader(
      title: '计划任务',
      subtitle: _tasks.isEmpty
          ? '没有待推进任务'
          : completedCount == 0
              ? '$pendingCount 待推进'
              : '$pendingCount 待推进 · $completedCount 已完成',
      trailing: _tasks.isEmpty
          ? null
          : AppMetaPill(
              label: '${_tasks.length} 项',
              icon: Icons.task_alt_outlined,
            ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        compact ? AppSpacing.xs : AppSpacing.sm,
        AppSpacing.md,
        compact ? AppSpacing.xs : AppSpacing.sm,
      ),
    );
  }

  Widget _buildTodayOverview(double progress) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = EvolyDesignTokens.of(context);
    final completedCount = _tasks.where((task) => task.isCompleted).length;
    final pendingTasks = _tasks.where((task) => !task.isCompleted).toList();
    final pendingCount = pendingTasks.length;
    final pendingMinutes = pendingTasks.fold<int>(
      0,
      (sum, task) => sum + task.estimatedMinutes,
    );
    final progressPercent = (progress * 100).round();
    final dueCount = pendingTasks.where((task) {
      return _belongsToDueSection(task, DateTime.now());
    }).length;
    final unscheduledCount =
        pendingTasks.where((task) => task.dueDateTime == null).length;

    return AppSection(
      title: '计划概览',
      subtitle: _tasks.isEmpty ? '还没有需要推进的任务' : '$pendingCount 项待推进',
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurface(
            variant: AppSurfaceVariant.raised,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        completedCount == 0 ? '待推进' : '完成率',
                        style: textTheme.labelLarge?.copyWith(
                          color: tokens.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      completedCount == 0
                          ? '${pendingTasks.length}'
                          : '$progressPercent%',
                      style: textTheme.titleSmall?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedProgressBar(value: progress),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppMetaPill(
                      label: '$dueCount 今日到期',
                      icon: Icons.event_available_outlined,
                      color: tokens.statusWarning,
                      selected: dueCount > 0,
                    ),
                    AppMetaPill(
                      label: '$unscheduledCount 待安排',
                      icon: Icons.radio_button_unchecked_rounded,
                      color: tokens.statusInfo,
                      selected: unscheduledCount > 0,
                    ),
                    if (completedCount > 0)
                      AppMetaPill(
                        label: '$completedCount 已完成',
                        icon: Icons.check_circle_outline_rounded,
                        color: tokens.statusSuccess,
                        selected: true,
                      ),
                    if (pendingMinutes > 0)
                      AppMetaPill(
                        label: '预计 $pendingMinutes 分钟',
                        icon: Icons.timer_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _CoachInsightCard(
            insight: _coachInsight,
            expanded: _coachExpanded,
            onToggleExpanded: () {
              setState(() => _coachExpanded = !_coachExpanded);
            },
            onCreateFirstAction: () {
              _openTopLevelDestination(1, AppRoutes.goals);
            },
            onOpenFirstTopTask: _openFirstCoachTask,
            onKeepOnlyTopTasks: _confirmKeepOnlyTopTasks,
            onOpenFirstDelayedGoal: _openFirstDelayedGoal,
            onReviewCompletedDay: () {
              _openTopLevelDestination(3, AppRoutes.stats);
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTaskGroupWidgets(List<_TaskGroup> groups) {
    return [
      for (final group in groups) ...[
        Padding(
          key: ValueKey('task-group-header-${group.id}'),
          padding: EdgeInsets.zero,
          child: group.section
              ? AppSectionHeader(
                  title: group.title,
                  subtitle: group.subtitle,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                )
              : _PriorityGroupHeader(
                  title: group.title,
                  priority: group.priority,
                ),
        ),
        if (group.reorderable && group.priority != null)
          _AnimatedTaskReorderGroup(
            key: ValueKey('task-group-${group.id}'),
            tasks: group.tasks,
            onReorder: (oldIndex, newIndex) {
              _reorderTaskGroup(
                group.tasks,
                group.priority!,
                oldIndex,
                newIndex,
              );
            },
            rowBuilder: (task, callbacks, dragging) => _buildTaskRow(
              task,
              key: ValueKey('task-row-${group.id}-${task.id}'),
              reorderable: group.tasks.length > 1,
              reorderDragCallbacks: callbacks,
              reorderDragging: dragging,
            ),
          )
        else
          for (final task in group.tasks) _buildTaskRow(task),
      ],
    ];
  }

  Widget _buildTaskRow(
    TaskItem task, {
    Key? key,
    bool reorderable = false,
    _ReorderDragCallbacks? reorderDragCallbacks,
    bool reorderDragging = false,
  }) {
    return _TodayTaskRow(
      key: key ?? ValueKey('task-row-${task.id}'),
      task: task,
      reorderable: reorderable,
      reorderDragCallbacks: reorderDragCallbacks,
      reorderDragging: reorderDragging,
      contextLabel: _projectLabelFor(task),
      onEdit: () => _showEditTaskSheet(task),
      onComplete: task.isCompleted ? null : () => _complete(task),
      onPostpone: task.isCompleted ? null : () => _postpone(task),
      onDelete: () => _delete(task),
    );
  }

  List<_TaskGroup> get _taskGroups {
    final now = DateTime.now();
    final pending = _sortedTasks.where((task) => !task.isCompleted).toList();
    final completedTodayTasks = _sortedCompletedTodayTasks(now);
    final dueTasks =
        pending.where((task) => _belongsToDueSection(task, now)).toList();
    final unscheduledTasks =
        pending.where((task) => task.dueDateTime == null).toList();

    return [
      if (dueTasks.isNotEmpty) ...[
        const _TaskGroup(
          id: 'due',
          title: '今日到期',
          subtitle: '按优先级推进',
          tasks: [],
          section: true,
        ),
        ..._priorityGroups(dueTasks, sectionId: 'due'),
      ],
      if (unscheduledTasks.isNotEmpty)
        const _TaskGroup(
          id: 'unscheduled',
          title: '待安排',
          subtitle: '无截止时间，先放在计划视野里',
          tasks: [],
          section: true,
        ),
      if (unscheduledTasks.isNotEmpty)
        ..._priorityGroups(unscheduledTasks, sectionId: 'unscheduled'),
      if (completedTodayTasks.isNotEmpty)
        _TaskGroup(
          id: 'completed-today',
          title: '今天已完成',
          subtitle: '完成项会在今天保留，明天自动离开计划视野',
          tasks: completedTodayTasks,
          section: true,
        ),
    ];
  }

  List<_TaskGroup> _priorityGroups(
    List<TaskItem> tasks, {
    required String sectionId,
  }) {
    return [
      _priorityGroup('高优先级', Priority.high, tasks, sectionId),
      _priorityGroup('中优先级', Priority.medium, tasks, sectionId),
      _priorityGroup('低优先级', Priority.low, tasks, sectionId),
    ].where((group) => group.tasks.isNotEmpty).toList();
  }

  _TaskGroup _priorityGroup(
    String title,
    Priority priority,
    List<TaskItem> tasks,
    String sectionId,
  ) {
    return _TaskGroup(
      id: '$sectionId-${priority.name}',
      title: title,
      priority: priority,
      tasks: tasks.where((task) => task.priority == priority).toList(),
      reorderable: true,
    );
  }

  List<TaskItem> get _sortedTasks {
    final tasks = [..._tasks];
    tasks.sort((left, right) {
      final priorityCompare =
          right.priority.weight.compareTo(left.priority.weight);
      if (priorityCompare != 0) {
        return priorityCompare;
      }

      final sortOrderCompare = left.sortOrder.compareTo(right.sortOrder);
      if (sortOrderCompare != 0) {
        return sortOrderCompare;
      }

      final dateCompare = _compareNullableDate(
        left.dueDateTime,
        right.dueDateTime,
      );
      if (dateCompare != 0) {
        return dateCompare;
      }

      return left.createdAt.compareTo(right.createdAt);
    });

    return tasks;
  }

  List<TaskItem> _sortedCompletedTodayTasks(DateTime now) {
    final tasks = _tasks.where((task) => _isCompletedToday(task, now)).toList();
    tasks.sort((left, right) {
      final completedCompare = _compareNullableDate(
        right.completedAt,
        left.completedAt,
      );
      if (completedCompare != 0) {
        return completedCompare;
      }

      final priorityCompare =
          right.priority.weight.compareTo(left.priority.weight);
      if (priorityCompare != 0) {
        return priorityCompare;
      }

      return left.createdAt.compareTo(right.createdAt);
    });

    return tasks;
  }

  String _projectLabelFor(TaskItem task) {
    final title = _goals
        .where((goal) => goal.id == task.goalId)
        .firstOrNull
        ?.title
        .trim();
    if (title == null || title.isEmpty) {
      return '项目：未同步';
    }

    return '项目：$title';
  }

  bool _belongsToDueSection(TaskItem task, DateTime now) {
    final dueDate = task.dueDateTime;
    if (dueDate == null) {
      return false;
    }

    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return dueDate.isBefore(end);
  }

  bool _belongsToPlan(TaskItem task, DateTime now) {
    if (task.status == TaskStatus.cancelled) {
      return false;
    }

    if (task.status == TaskStatus.completed) {
      return _isCompletedToday(task, now);
    }

    return task.dueDateTime == null || _belongsToDueSection(task, now);
  }

  bool _isCompletedToday(TaskItem task, DateTime now) {
    final completedAt = task.completedAt;
    if (task.status != TaskStatus.completed || completedAt == null) {
      return false;
    }

    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return !completedAt.isBefore(start) && completedAt.isBefore(end);
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

  Future<void> _showCreateProjectSheet() async {
    String? createdProjectId;
    final created = await showAdaptiveFormModal<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _ProjectCreateSheet(
          onCreate: (title, description, priority) async {
            createdProjectId = await _createProject(
              title: title,
              description: description,
              priority: priority,
            );
          },
        );
      },
    );

    if (created != true || !mounted) {
      return;
    }

    await _loadTasks();
    if (!mounted) {
      return;
    }

    final projectId = createdProjectId;
    if (projectId != null) {
      await Navigator.pushNamed(
        context,
        AppRoutes.goalDetail,
        arguments: projectId,
      );
      await _loadTasks();
    }
  }

  Future<String> _createProject({
    required String title,
    required String description,
    required Priority priority,
  }) async {
    final now = DateTime.now();
    final project = Goal(
      id: const Uuid().v4(),
      title: title,
      description: description,
      type: GoalType.longTerm,
      priority: priority,
      status: GoalStatus.inProgress,
      startDate: now,
      createdAt: now,
      updatedAt: now,
    );

    await context.read<GoalRepository>().save(project);
    if (mounted) {
      notifyDataChanged();
    }

    return project.id;
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<TaskRepository>();
      final goalRepository = context.read<GoalRepository>();
      final coachService = context.read<RuleBasedCoachService>();
      final now = DateTime.now();
      final results = await Future.wait([
        repository.findPlanningCandidates(now),
        repository.findCompletedToday(now),
        goalRepository.findAll(),
        coachService.generateTodayInsight(now),
      ]);
      if (!mounted) {
        return;
      }

      setState(() {
        final planningTasks = results[0] as List<TaskItem>;
        final completedTodayTasks = results[1] as List<TaskItem>;
        final goals = results[2] as List<Goal>;
        _tasks
          ..clear()
          ..addAll(planningTasks)
          ..addAll(completedTodayTasks);
        _goals
          ..clear()
          ..addAll(goals);
        _coachInsight = results[3] as CoachInsight;
        _loading = false;
      });
      _schedulePendingTaskOpen();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _coachInsight = null;
        _loading = false;
      });
    }
  }

  void _handleDesktopWindowChanged() {
    _schedulePendingTaskOpen();
  }

  void _schedulePendingTaskOpen() {
    if (!mounted ||
        _loading ||
        _pendingTaskOpenScheduled ||
        _desktopWindowController?.pendingTaskId == null) {
      return;
    }

    _pendingTaskOpenScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingTaskOpenScheduled = false;
      if (!mounted) {
        return;
      }

      unawaited(_openPendingDesktopTask());
    });
  }

  Future<void> _openPendingDesktopTask() async {
    final controller = _desktopWindowController;
    if (controller == null || _loading) {
      return;
    }

    final taskId = controller.consumePendingTaskId();
    if (taskId == null) {
      return;
    }

    final task = _tasks.where((task) => task.id == taskId).firstOrNull;
    if (task == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这项任务已经不在计划列表里了')),
      );
      return;
    }

    await _showEditTaskSheet(task);
  }

  Future<void> _showDueReminders() async {
    try {
      final inbox = context.read<ReminderInbox>();
      final messages = await inbox.collectDueMessages(DateTime.now());
      if (!mounted || messages.isEmpty) {
        return;
      }

      for (final message in messages) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.systemNotificationShown
                  ? '系统通知已发送：${message.title}'
                  : '提醒：${message.title}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      // Reminder checks should never block the main task list.
    }
  }

  void _openTopLevelDestination(int index, String fallbackRoute) {
    final destinationSelected = widget.onTopLevelDestinationSelected;
    if (destinationSelected != null) {
      destinationSelected(index);
      return;
    }

    Navigator.pushReplacementNamed(context, fallbackRoute);
  }

  Future<void> _complete(TaskItem task) async {
    final reminderService = context.read<TaskReminderService>();
    final now = DateTime.now();
    await _updateTask(
      task,
      task.copyWith(
        status: TaskStatus.completed,
        completedAt: now,
        updatedAt: now,
      ),
    );
    await reminderService.saveForTask(
      taskId: task.id,
      remindAt: null,
    );
  }

  Future<void> _postpone(TaskItem task) async {
    final now = DateTime.now();
    final currentDueDate = task.dueDateTime ?? now;
    final nextDay = currentDueDate.add(const Duration(days: 1));

    await _updateTask(
      task,
      task.copyWith(
        status: TaskStatus.postponed,
        dueDateTime: DateTime(
          nextDay.year,
          nextDay.month,
          nextDay.day,
          currentDueDate.hour,
          currentDueDate.minute,
        ),
        updatedAt: now,
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已延期到明天')),
    );
  }

  Future<void> _reorderTaskGroup(
    List<TaskItem> groupTasks,
    Priority priority,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < 0 ||
        oldIndex >= groupTasks.length ||
        newIndex < 0 ||
        newIndex >= groupTasks.length) {
      return;
    }

    if (oldIndex == newIndex) {
      return;
    }

    final reordered = [...groupTasks];
    final movedTask = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, movedTask);
    final now = DateTime.now();
    final updatedTasks = <TaskItem>[
      for (var index = 0; index < reordered.length; index += 1)
        reordered[index].copyWith(
          sortOrder: (index + 1) * 1000,
          updatedAt: now,
        ),
    ];
    final previousTasks = [..._tasks];

    setState(() {
      for (final updatedTask in updatedTasks) {
        final taskIndex =
            _tasks.indexWhere((task) => task.id == updatedTask.id);
        if (taskIndex != -1) {
          _tasks[taskIndex] = updatedTask;
        }
      }
    });

    try {
      await context.read<TaskRepository>().reorderWithinPriority(
            priority: priority,
            orderedTaskIds: updatedTasks.map((task) => task.id).toList(),
          );
      if (!mounted) {
        return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _tasks
          ..clear()
          ..addAll(previousTasks);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reorder failed: $error')),
      );
    }
  }

  Future<void> _openFirstCoachTask() async {
    final firstTopTaskId = _coachInsight?.topTasks.firstOrNull?.id;
    if (firstTopTaskId == null) {
      return;
    }

    final task = _tasks.where((task) => task.id == firstTopTaskId).firstOrNull;
    if (task == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这项任务已经不在计划列表里了')),
      );
      return;
    }

    await _showEditTaskSheet(task);
  }

  void _openFirstDelayedGoal() {
    final goalId = _coachInsight?.delayedGoals.firstOrNull?.id;
    if (goalId == null) {
      return;
    }

    Navigator.pushNamed(context, AppRoutes.goalDetail, arguments: goalId);
  }

  Future<void> _confirmKeepOnlyTopTasks() async {
    final insight = _coachInsight;
    if (insight == null || insight.topTasks.isEmpty) {
      return;
    }

    final topTaskIds = insight.topTasks.map((task) => task.id).toSet();
    final now = DateTime.now();
    final tasksToPostpone = _tasks.where((task) {
      return !task.isCompleted &&
          _belongsToDueSection(task, now) &&
          !topTaskIds.contains(task.id);
    }).toList();

    if (tasksToPostpone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今天已经只剩 Top 3 任务了')),
      );
      return;
    }

    final topTasks = insight.topTasks
        .map((topTask) {
          return _tasks.where((task) => task.id == topTask.id).firstOrNull;
        })
        .whereType<TaskItem>()
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _CoachAdjustmentDraftDialog(
          keptTasks: topTasks,
          postponedTasks: tasksToPostpone,
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _postponeTasksToTomorrow(tasksToPostpone);
  }

  Future<void> _postponeTasksToTomorrow(List<TaskItem> tasks) async {
    final repository = context.read<TaskRepository>();
    final now = DateTime.now();
    final updatedTasks = <TaskItem>[];

    for (final task in tasks) {
      final currentDueDate = task.dueDateTime ?? now;
      final nextDay = currentDueDate.add(const Duration(days: 1));
      updatedTasks.add(
        task.copyWith(
          status: TaskStatus.postponed,
          dueDateTime: DateTime(
            nextDay.year,
            nextDay.month,
            nextDay.day,
            currentDueDate.hour,
            currentDueDate.minute,
          ),
          updatedAt: now,
        ),
      );
    }

    setState(() {
      for (final updatedTask in updatedTasks) {
        final index = _tasks.indexWhere((task) => task.id == updatedTask.id);
        if (index != -1) {
          _tasks[index] = updatedTask;
        }
      }
    });

    try {
      await Future.wait(updatedTasks.map(repository.save));
      await _loadTasks();
      if (!mounted) {
        return;
      }

      notifyDataChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已延期 ${updatedTasks.length} 个任务，今天保留 Top 3')),
      );
    } catch (error) {
      await _loadTasks();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量延期失败：$error')),
      );
    }
  }

  Future<void> _delete(TaskItem task) async {
    final repository = context.read<TaskRepository>();
    final reminderService = context.read<TaskReminderService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除任务？'),
          content: Text('「${task.title}」会从计划中移除。'),
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

    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      return;
    }

    setState(() {
      _tasks.removeAt(index);
    });

    try {
      await repository.delete(task.id);
      await reminderService.saveForTask(
        taskId: task.id,
        remindAt: null,
      );
      if (!mounted) {
        return;
      }

      notifyDataChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务已删除')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _tasks.insert(index, task);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$error')),
      );
    }
  }

  Future<void> _showEditTaskSheet(TaskItem task) async {
    final reminderService = context.read<TaskReminderService>();
    final reminder = await reminderService.findForTask(task.id);
    if (!mounted) {
      return;
    }

    final updated = await showAdaptiveFormModal<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return TaskEditSheet(
          title: '编辑任务',
          task: task,
          reminder: reminder,
          availableGoals: _goals,
          onSave: (updatedTask, reminder) async {
            await _updateTask(task, updatedTask);
            await reminderService.saveForTask(
              taskId: task.id,
              remindAt: reminder.remindAt,
              repeatRule: reminder.repeatRule,
              notificationBody: updatedTask.title,
            );
          },
        );
      },
    );

    if (updated == true) {
      await _loadTasks();
    }
  }

  Future<void> _updateTask(TaskItem oldTask, TaskItem newTask) async {
    final taskRepository = context.read<TaskRepository>();
    final coachService = context.read<RuleBasedCoachService>();
    final index = _tasks.indexWhere((task) => task.id == oldTask.id);
    if (index == -1) {
      return;
    }

    final now = DateTime.now();
    setState(() {
      if (_belongsToPlan(newTask, now)) {
        _tasks[index] = newTask;
      } else {
        _tasks.removeAt(index);
      }
    });

    try {
      await taskRepository.save(newTask);
      final coachInsight = await coachService.generateTodayInsight(
        now,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _coachInsight = coachInsight;
      });
      notifyDataChanged();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        final currentIndex = _tasks.indexWhere((task) => task.id == oldTask.id);
        if (currentIndex == -1) {
          final restoreIndex = index.clamp(0, _tasks.length).toInt();
          _tasks.insert(restoreIndex, oldTask);
        } else {
          _tasks[currentIndex] = oldTask;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }
}

class _ProjectCreateSheet extends StatefulWidget {
  const _ProjectCreateSheet({required this.onCreate});

  final Future<void> Function(
    String title,
    String description,
    Priority priority,
  ) onCreate;

  @override
  State<_ProjectCreateSheet> createState() => _ProjectCreateSheetState();
}

class _ProjectCreateSheetState extends State<_ProjectCreateSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final FocusNode _titleFocusNode;
  var _selectedPriority = Priority.medium;
  var _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _titleFocusNode = FocusNode();
    requestFocusAfterBottomSheetEntrance(this, _titleFocusNode);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetFormLayout(
      minHeight: 300,
      title: '新建项目',
      footer: FilledButton.icon(
        onPressed: _saving ? null : _create,
        icon: const Icon(Icons.add_rounded),
        label: Text(_saving ? '创建中…' : '创建'),
      ),
      children: [
        AppField(
          label: '项目名称',
          isRequired: true,
          child: TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: '例如：准备 V0.5 发布',
            ),
          ),
        ),
        AppField(
          label: '项目描述（可选）',
          child: TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(),
          ),
        ),
        AppField(
          label: '优先级',
          child: SegmentedButton<Priority>(
            segments: const [
              ButtonSegment(value: Priority.high, label: Text('高')),
              ButtonSegment(value: Priority.medium, label: Text('中')),
              ButtonSegment(value: Priority.low, label: Text('低')),
            ],
            selected: {_selectedPriority},
            onSelectionChanged: (values) {
              setState(() => _selectedPriority = values.first);
            },
          ),
        ),
        if (_errorMessage != null)
          Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
      ],
    );
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = '项目名称不能为空');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await widget.onCreate(
        title,
        _descriptionController.text.trim(),
        _selectedPriority,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _errorMessage = '创建失败';
      });
    }
  }
}

class _CoachAdjustmentDraftDialog extends StatelessWidget {
  const _CoachAdjustmentDraftDialog({
    required this.keptTasks,
    required this.postponedTasks,
  });

  final List<TaskItem> keptTasks;
  final List<TaskItem> postponedTasks;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Coach 调整草案'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今天任务偏多。确认后保留 Top 3，其余延期到明天。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _CoachDraftSection(
                title: '保留今天推进',
                icon: Icons.check_circle_outline,
                tasks: keptTasks,
                reasonBuilder: _keepReasonFor,
              ),
              const SizedBox(height: AppSpacing.md),
              _CoachDraftSection(
                title: '延期到明天',
                icon: Icons.schedule_outlined,
                tasks: postponedTasks,
                reasonBuilder: _postponeReasonFor,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('我再想想'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('确认执行'),
        ),
      ],
    );
  }

  String _keepReasonFor(TaskItem task) {
    final dueDate = task.dueDateTime;
    if (task.priority == Priority.high) {
      return '高优先级';
    }
    if (dueDate != null && dueDate.isBefore(DateTime.now())) {
      return '已过计划时间';
    }
    if (dueDate != null) {
      return '截止时间靠前';
    }

    return '今日 Top 3';
  }

  String _postponeReasonFor(TaskItem task) {
    if (task.priority == Priority.low) {
      return '低优先级';
    }
    if (task.estimatedMinutes >= 60) {
      return '预计耗时较长';
    }

    return '不在今日 Top 3';
  }
}

class _CoachDraftSection extends StatelessWidget {
  const _CoachDraftSection({
    required this.title,
    required this.icon,
    required this.tasks,
    required this.reasonBuilder,
  });

  final String title;
  final IconData icon;
  final List<TaskItem> tasks;
  final String Function(TaskItem task) reasonBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$title（${tasks.length}）',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final task in tasks)
          _CoachDraftTaskTile(
            task: task,
            reason: reasonBuilder(task),
          ),
      ],
    );
  }
}

class _CoachDraftTaskTile extends StatelessWidget {
  const _CoachDraftTaskTile({
    required this.task,
    required this.reason,
  });

  final TaskItem task;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PriorityDot(priority: task.priority),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.priority.label}优先级 · 预计 ${task.estimatedMinutes} 分钟',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      reason,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      Priority.high => Theme.of(context).colorScheme.error,
      Priority.medium => Theme.of(context).colorScheme.primary,
      Priority.low => Theme.of(context).colorScheme.secondary,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Icon(Icons.circle, size: 10, color: color),
    );
  }
}

class _PriorityGroupHeader extends StatelessWidget {
  const _PriorityGroupHeader({
    required this.title,
    required this.priority,
  });

  final String title;
  final Priority? priority;

  @override
  Widget build(BuildContext context) {
    final priority = this.priority;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (priority != null) ...[
            _PriorityDot(priority: priority),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTaskReorderGroup extends StatefulWidget {
  const _AnimatedTaskReorderGroup({
    required super.key,
    required this.tasks,
    required this.onReorder,
    required this.rowBuilder,
  });

  final List<TaskItem> tasks;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Widget Function(
    TaskItem task,
    _ReorderDragCallbacks callbacks,
    bool dragging,
  ) rowBuilder;

  @override
  State<_AnimatedTaskReorderGroup> createState() =>
      _AnimatedTaskReorderGroupState();
}

class _AnimatedTaskReorderGroupState extends State<_AnimatedTaskReorderGroup> {
  static const _fallbackRowExtent = 88.0;
  static const _minimumRowExtent = 72.0;

  int? _dragIndex;
  int? _targetIndex;
  String? _dragTaskId;
  var _dragOffset = 0.0;
  final Map<String, double> _rowExtents = {};

  @override
  void didUpdateWidget(covariant _AnimatedTaskReorderGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dragTaskId = _dragTaskId;
    if (_dragIndex != null &&
        (widget.tasks.length != oldWidget.tasks.length ||
            dragTaskId == null ||
            !widget.tasks.any((task) => task.id == dragTaskId))) {
      _resetDrag();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final dragIndex = _dragIndex;
    final targetIndex = _targetIndex ?? dragIndex;
    final rowTops = _rowTops(tasks);
    final groupHeight = _groupHeight(tasks);

    return SizedBox(
      height: groupHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < tasks.length; index += 1)
            if (index != dragIndex)
              _buildPositionedTask(
                index,
                _visualTopFor(index, dragIndex, targetIndex, rowTops),
              ),
          if (dragIndex != null)
            _buildPositionedTask(
              dragIndex,
              rowTops[dragIndex],
            ),
        ],
      ),
    );
  }

  Widget _buildPositionedTask(int index, double top) {
    final task = widget.tasks[index];
    final isDragging = _dragIndex == index;
    final callbacks = _ReorderDragCallbacks(
      onStart: () => _startDrag(index),
      onUpdate: _updateDrag,
      onEnd: _finishDrag,
      onCancel: _resetDrag,
    );
    final child = _MeasuredReorderItem(
      taskId: task.id,
      onExtentChanged: _handleRowExtentChanged,
      child: widget.rowBuilder(task, callbacks, isDragging),
    );
    final presentedChild = _ReorderTaskPresentation(
      dragging: isDragging,
      child: child,
    );

    return AnimatedPositioned(
      key: ValueKey('reorder-position-${task.id}'),
      duration: isDragging ? Duration.zero : MotionTokens.normal,
      curve: MotionTokens.standard,
      top: isDragging ? top + _dragOffset : top,
      left: 0,
      right: 0,
      child: presentedChild,
    );
  }

  double _visualTopFor(
    int index,
    int? dragIndex,
    int? targetIndex,
    List<double> rowTops,
  ) {
    if (dragIndex == null || targetIndex == null || index == dragIndex) {
      return rowTops[index];
    }

    final draggedExtent = _extentFor(widget.tasks[dragIndex]);
    if (dragIndex < targetIndex && index > dragIndex && index <= targetIndex) {
      return rowTops[index] - draggedExtent;
    }

    if (dragIndex > targetIndex && index >= targetIndex && index < dragIndex) {
      return rowTops[index] + draggedExtent;
    }

    return rowTops[index];
  }

  void _startDrag(int index) {
    if (index < 0 || index >= widget.tasks.length) {
      return;
    }

    setState(() {
      _dragIndex = index;
      _targetIndex = index;
      _dragTaskId = widget.tasks[index].id;
      _dragOffset = 0;
    });
  }

  void _updateDrag(double delta) {
    final dragIndex = _dragIndex;
    if (dragIndex == null) {
      return;
    }

    setState(() {
      final rowTops = _rowTops(widget.tasks);
      final draggedExtent = _extentFor(widget.tasks[dragIndex]);
      final minOffset = -rowTops[dragIndex];
      final maxOffset =
          _groupHeight(widget.tasks) - rowTops[dragIndex] - draggedExtent;
      _dragOffset = (_dragOffset + delta).clamp(minOffset, maxOffset);
      _targetIndex = _targetIndexForDrag(dragIndex, _dragOffset, rowTops);
    });
  }

  void _finishDrag() {
    final dragIndex = _dragIndex;
    final targetIndex = _targetIndex;
    _resetDrag();
    if (dragIndex == null || targetIndex == null || dragIndex == targetIndex) {
      return;
    }

    widget.onReorder(dragIndex, targetIndex);
  }

  void _resetDrag() {
    if (_dragIndex == null && _dragOffset == 0) {
      return;
    }

    setState(() {
      _dragIndex = null;
      _targetIndex = null;
      _dragTaskId = null;
      _dragOffset = 0;
    });
  }

  void _handleRowExtentChanged(String taskId, double extent) {
    final normalizedExtent =
        extent < _minimumRowExtent ? _minimumRowExtent : extent;
    final previousExtent = _rowExtents[taskId];
    if (previousExtent != null &&
        (previousExtent - normalizedExtent).abs() < 0.5) {
      return;
    }

    setState(() {
      _rowExtents[taskId] = normalizedExtent;
    });
  }

  double _extentFor(TaskItem task) {
    return _rowExtents[task.id] ?? _fallbackRowExtent;
  }

  List<double> _rowTops(List<TaskItem> tasks) {
    var top = 0.0;
    final rowTops = <double>[];
    for (final task in tasks) {
      rowTops.add(top);
      top += _extentFor(task);
    }
    return rowTops;
  }

  double _groupHeight(List<TaskItem> tasks) {
    var height = 0.0;
    for (final task in tasks) {
      height += _extentFor(task);
    }
    return height;
  }

  int _targetIndexForDrag(
    int dragIndex,
    double dragOffset,
    List<double> rowTops,
  ) {
    final draggedTask = widget.tasks[dragIndex];
    final draggedCenter =
        rowTops[dragIndex] + dragOffset + _extentFor(draggedTask) / 2;
    var targetIndex = 0;

    for (var index = 0; index < widget.tasks.length; index += 1) {
      final task = widget.tasks[index];
      final center = rowTops[index] + _extentFor(task) / 2;
      if (draggedCenter >= center) {
        targetIndex = index;
      } else {
        break;
      }
    }

    return targetIndex.clamp(0, widget.tasks.length - 1);
  }
}

class _MeasuredReorderItem extends StatefulWidget {
  const _MeasuredReorderItem({
    required this.taskId,
    required this.onExtentChanged,
    required this.child,
  });

  final String taskId;
  final void Function(String taskId, double extent) onExtentChanged;
  final Widget child;

  @override
  State<_MeasuredReorderItem> createState() => _MeasuredReorderItemState();
}

class _MeasuredReorderItemState extends State<_MeasuredReorderItem> {
  Size? _lastSize;
  var _measureScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _MeasuredReorderItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleMeasure();
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }

  void _scheduleMeasure() {
    if (_measureScheduled) {
      return;
    }

    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) {
        return;
      }

      final size = context.size;
      if (size == null || size == _lastSize) {
        return;
      }

      _lastSize = size;
      widget.onExtentChanged(widget.taskId, size.height);
    });
  }
}

class _ReorderTaskPresentation extends StatelessWidget {
  const _ReorderTaskPresentation({
    required this.dragging,
    required this.child,
  });

  final bool dragging;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: dragging ? 1 : 0),
      duration: MotionTokens.fast,
      curve: MotionTokens.standard,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 1 + value * 0.006,
          child: child,
        );
      },
      child: child,
    );
  }
}

class _ReorderDragCallbacks {
  const _ReorderDragCallbacks({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final VoidCallback onStart;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}

class _TodayTaskRow extends StatelessWidget {
  const _TodayTaskRow({
    required super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    required this.contextLabel,
    this.reorderable = false,
    this.reorderDragCallbacks,
    this.reorderDragging = false,
    this.onComplete,
    this.onPostpone,
  });

  final TaskItem task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String contextLabel;
  final bool reorderable;
  final _ReorderDragCallbacks? reorderDragCallbacks;
  final bool reorderDragging;
  final VoidCallback? onComplete;
  final VoidCallback? onPostpone;

  @override
  Widget build(BuildContext context) {
    final taskContent = InkWell(
      onTap: reorderDragging ? null : onEdit,
      child: TaskCard(
        task: task,
        onComplete: onComplete,
        contextLabel: contextLabel,
        trailing: _TaskRowTrailing(
          reorderable: reorderable,
          reorderDragCallbacks: reorderDragCallbacks,
          dragging: reorderDragging,
          canPostpone: onPostpone != null,
          onActionSelected: (action) {
            switch (action) {
              case _TodayTaskAction.edit:
                onEdit();
              case _TodayTaskAction.postpone:
                onPostpone?.call();
              case _TodayTaskAction.delete:
                onDelete();
            }
          },
        ),
      ),
    );

    if (reorderable) {
      return taskContent;
    }

    return Dismissible(
      key: ValueKey('today-${task.id}'),
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
      child: taskContent,
    );
  }
}

class _TaskRowTrailing extends StatelessWidget {
  const _TaskRowTrailing({
    required this.reorderable,
    required this.reorderDragCallbacks,
    required this.dragging,
    required this.canPostpone,
    required this.onActionSelected,
  });

  final bool reorderable;
  final _ReorderDragCallbacks? reorderDragCallbacks;
  final bool dragging;
  final bool canPostpone;
  final ValueChanged<_TodayTaskAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final menu = PopupMenuButton<_TodayTaskAction>(
      tooltip: 'More',
      onSelected: onActionSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _TodayTaskAction.edit,
          child: Text('Edit'),
        ),
        PopupMenuItem(
          value: _TodayTaskAction.postpone,
          enabled: canPostpone,
          child: const Text('Postpone'),
        ),
        const PopupMenuItem(
          value: _TodayTaskAction.delete,
          child: Text('Delete'),
        ),
      ],
    );

    if (!reorderable) {
      return menu;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragMoveHandle(
          callbacks: reorderDragCallbacks,
          dragging: dragging,
        ),
        menu,
      ],
    );
  }
}

class _DragMoveHandle extends StatefulWidget {
  const _DragMoveHandle({
    required this.callbacks,
    required this.dragging,
  });

  final _ReorderDragCallbacks? callbacks;
  final bool dragging;

  @override
  State<_DragMoveHandle> createState() => _DragMoveHandleState();
}

class _DragMoveHandleState extends State<_DragMoveHandle> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = EvolyDesignTokens.of(context);
    final color =
        widget.dragging ? tokens.hudAccent : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: 'Drag to reorder',
      child: MouseRegion(
        cursor: widget.dragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: Listener(
          onPointerDown: (_) {
            widget.callbacks?.onStart();
          },
          onPointerMove: (event) {
            widget.callbacks?.onUpdate(event.delta.dy);
          },
          onPointerUp: (_) {
            widget.callbacks?.onEnd();
          },
          onPointerCancel: (_) {
            widget.callbacks?.onCancel();
          },
          child: AnimatedContainer(
            duration: MotionTokens.fast,
            curve: MotionTokens.standard,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.dragging
                  ? tokens.hudAccent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.element),
            ),
            child: Icon(
              Icons.drag_indicator_rounded,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachInsightCard extends StatelessWidget {
  const _CoachInsightCard({
    required this.insight,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onCreateFirstAction,
    required this.onOpenFirstTopTask,
    required this.onKeepOnlyTopTasks,
    required this.onOpenFirstDelayedGoal,
    required this.onReviewCompletedDay,
  });

  final CoachInsight? insight;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onCreateFirstAction;
  final VoidCallback onOpenFirstTopTask;
  final VoidCallback onKeepOnlyTopTasks;
  final VoidCallback onOpenFirstDelayedGoal;
  final VoidCallback onReviewCompletedDay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = EvolyDesignTokens.of(context);
    final insight = this.insight;
    final isDark = colorScheme.brightness == Brightness.dark;
    final accentColor = tokens.coachAccent;

    return AppSurface(
      variant: AppSurfaceVariant.raised,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.52 : 0.42),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: onToggleExpanded,
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: isDark ? 0.18 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(
                            Icons.psychology_alt_outlined,
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Evoly Coach 今日建议',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: MotionTokens.fast,
                        curve: MotionTokens.standard,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: MotionTokens.normal,
                  curve: MotionTokens.standard,
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: insight == null
                              ? const _CoachLoadingContent()
                              : _CoachInsightContent(
                                  insight: insight,
                                  onCreateFirstAction: onCreateFirstAction,
                                  onOpenFirstTopTask: onOpenFirstTopTask,
                                  onKeepOnlyTopTasks: onKeepOnlyTopTasks,
                                  onOpenFirstDelayedGoal:
                                      onOpenFirstDelayedGoal,
                                  onReviewCompletedDay: onReviewCompletedDay,
                                ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachSoftIcon extends StatelessWidget {
  const _CoachSoftIcon({
    required this.icon,
    required this.color,
    this.size = 18,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(
          icon,
          size: size,
          color: color,
        ),
      ),
    );
  }
}

class _CoachLoadingContent extends StatelessWidget {
  const _CoachLoadingContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '正在校准今天的节奏…',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _CoachInsightContent extends StatelessWidget {
  const _CoachInsightContent({
    required this.insight,
    required this.onCreateFirstAction,
    required this.onOpenFirstTopTask,
    required this.onKeepOnlyTopTasks,
    required this.onOpenFirstDelayedGoal,
    required this.onReviewCompletedDay,
  });

  final CoachInsight insight;
  final VoidCallback onCreateFirstAction;
  final VoidCallback onOpenFirstTopTask;
  final VoidCallback onKeepOnlyTopTasks;
  final VoidCallback onOpenFirstDelayedGoal;
  final VoidCallback onReviewCompletedDay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          insight.summary,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _CoachMetricChip(
              icon: Icons.pending_actions_outlined,
              label: '${insight.pendingTaskCount} 个待完成',
            ),
            _CoachMetricChip(
              icon: Icons.timer_outlined,
              label: '预计 ${insight.totalEstimatedMinutes} 分钟',
            ),
            if (insight.completedTaskCount > 0)
              _CoachMetricChip(
                icon: Icons.check_circle_outline,
                label: '已完成 ${insight.completedTaskCount}',
              ),
          ],
        ),
        if (insight.topTasks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('先做这 3 件', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final task in insight.topTasks) _CoachTopTaskTile(task: task),
        ],
        if (insight.delayedGoals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('延期信号', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final goal in insight.delayedGoals)
            _CoachDelayedGoalTile(goal: goal),
        ],
        if (insight.suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('建议', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final suggestion in insight.suggestions)
            _CoachSuggestionTile(suggestion: suggestion),
        ],
        const SizedBox(height: AppSpacing.md),
        _CoachActionBar(
          insight: insight,
          onCreateFirstAction: onCreateFirstAction,
          onOpenFirstTopTask: onOpenFirstTopTask,
          onKeepOnlyTopTasks: onKeepOnlyTopTasks,
          onOpenFirstDelayedGoal: onOpenFirstDelayedGoal,
          onReviewCompletedDay: onReviewCompletedDay,
        ),
      ],
    );
  }
}

class _CoachActionBar extends StatelessWidget {
  const _CoachActionBar({
    required this.insight,
    required this.onCreateFirstAction,
    required this.onOpenFirstTopTask,
    required this.onKeepOnlyTopTasks,
    required this.onOpenFirstDelayedGoal,
    required this.onReviewCompletedDay,
  });

  final CoachInsight insight;
  final VoidCallback onCreateFirstAction;
  final VoidCallback onOpenFirstTopTask;
  final VoidCallback onKeepOnlyTopTasks;
  final VoidCallback onOpenFirstDelayedGoal;
  final VoidCallback onReviewCompletedDay;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (insight.status == CoachInsightStatus.empty)
          FilledButton.icon(
            onPressed: onCreateFirstAction,
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('添加今日行动'),
          ),
        if (insight.topTasks.isNotEmpty)
          FilledButton.icon(
            onPressed: onOpenFirstTopTask,
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('开始第一项'),
          ),
        if (insight.status == CoachInsightStatus.overloaded &&
            insight.topTasks.isNotEmpty)
          OutlinedButton.icon(
            onPressed: onKeepOnlyTopTasks,
            icon: const Icon(Icons.filter_3_outlined),
            label: const Text('只保留 Top 3'),
          ),
        if (insight.delayedGoals.isNotEmpty)
          OutlinedButton.icon(
            onPressed: onOpenFirstDelayedGoal,
            icon: const Icon(Icons.flag_outlined),
            label: const Text('查看延期项目'),
          ),
        if (insight.status == CoachInsightStatus.completed)
          FilledButton.icon(
            onPressed: onReviewCompletedDay,
            icon: const Icon(Icons.insights_outlined),
            label: const Text('去统计页复盘'),
          ),
      ],
    );
  }
}

class _CoachMetricChip extends StatelessWidget {
  const _CoachMetricChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final accentColor = colorScheme.primary;
    final backgroundColor = Color.alphaBlend(
      accentColor.withValues(alpha: isDark ? 0.10 : 0.045),
      isDark
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerLowest,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.24 : 0.55,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: accentColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachTopTaskTile extends StatelessWidget {
  const _CoachTopTaskTile({required this.task});

  final CoachTopTask task;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoachSoftIcon(
            icon: Icons.radio_button_checked,
            color: colorScheme.primary,
            size: 15,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${task.priority.label}优先级 · ${task.goalTitle} · ${task.reason}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachDelayedGoalTile extends StatelessWidget {
  const _CoachDelayedGoalTile({required this.goal});

  final CoachDelayedGoal goal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = colorScheme.error.withValues(
      alpha: colorScheme.brightness == Brightness.dark ? 0.86 : 0.78,
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoachSoftIcon(
            icon: Icons.flag_circle_outlined,
            color: warningColor,
            size: 15,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${goal.title}：近 14 天延期 ${goal.postponedTaskCount} 次',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachSuggestionTile extends StatelessWidget {
  const _CoachSuggestionTile({required this.suggestion});

  final CoachSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (suggestion.severity) {
      CoachSuggestionSeverity.success => colorScheme.tertiary,
      CoachSuggestionSeverity.warning => colorScheme.error,
      CoachSuggestionSeverity.info => colorScheme.secondary,
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoachSoftIcon(
            icon: Icons.auto_awesome_outlined,
            color: color,
            size: 15,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  suggestion.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskGroup {
  const _TaskGroup({
    required this.id,
    required this.title,
    required this.tasks,
    this.subtitle,
    this.priority,
    this.section = false,
    this.reorderable = false,
  });

  final String id;
  final String title;
  final List<TaskItem> tasks;
  final String? subtitle;
  final Priority? priority;
  final bool section;
  final bool reorderable;
}

enum _TodayTaskAction {
  edit,
  postpone,
  delete,
}
