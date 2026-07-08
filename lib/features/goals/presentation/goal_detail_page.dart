import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/data_refresh_listener.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/documents/application/project_summary_template.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/documents/presentation/document_edit_page.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/goals/presentation/widgets/goal_edit_sheet.dart';
import 'package:evoly/features/reminders/application/task_reminder_service.dart';
import 'package:evoly/features/reminders/presentation/task_reminder_picker.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_card.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_create_sheet.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_edit_sheet.dart';
import 'package:evoly/shared/ui/bottom_sheets/adaptive_form_modal.dart';
import 'package:evoly/shared/ui/components/animated_progress_bar.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';
import 'package:evoly/shared/widgets/empty_state.dart';
import 'package:uuid/uuid.dart';

class GoalDetailPage extends StatefulWidget {
  const GoalDetailPage({
    required this.goalId,
    super.key,
    this.initialTaskId,
  });

  final String goalId;
  final String? initialTaskId;

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage>
    with DataRefreshListener<GoalDetailPage> {
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _taskKeys = {};
  Goal? _goal;
  final List<TaskItem> _tasks = [];
  final List<Goal> _goals = [];
  final List<EvolyDocument> _documents = [];
  var _loading = true;
  var _initialTaskRevealConsumed = false;
  String? _errorMessage;
  String? _highlightedTaskId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _highlightedTaskId = widget.initialTaskId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Future<void> reloadDataForRefresh() => _loadDetail();

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '项目详情',
      actions: [
        IconButton(
          tooltip: '编辑项目',
          onPressed: _goal == null ? null : _showEditGoalSheet,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: '新增子任务',
          onPressed: _goal == null ? null : _showCreateTaskSheet,
          icon: const Icon(Icons.add_task_rounded),
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.goalId.isEmpty) {
      return const EmptyState(
        icon: Icons.link_off_outlined,
        title: '项目参数缺失',
        message: '请从项目列表重新进入详情页。',
      );
    }

    if (_loading) {
      return const AppLoadingState(label: '正在打开项目');
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        message: errorMessage,
      );
    }

    final goal = _goal;
    if (goal == null) {
      return const EmptyState(
        icon: Icons.flag_outlined,
        title: '项目不存在',
        message: '这个项目可能已经被删除了。',
      );
    }

    final activeTasks = _activeTasks;
    final completedTasks = _completedTasks;

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _GoalOverviewSection(
                  goal: goal,
                  progress: _calculatedProgress,
                  completedCount: _completedCount,
                  taskCount: _tasks.length,
                ),
                _GoalDocumentsSection(
                  goal: goal,
                  documents: _documents,
                  onOpenDocument: _openDocument,
                  onCreateDocument: _createLinkedDocument,
                  onCreateSummary: _createProjectSummary,
                  onOpenFolder: _openGoalFolder,
                ),
                AppSectionHeader(
                  title: '瀛愪换鍔?',
                  trailing: TextButton.icon(
                    onPressed: _showCreateTaskSheet,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('鏂板'),
                  ),
                  padding: EdgeInsets.zero,
                ),
                if (_tasks.isEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppSurface(
                    variant: AppSurfaceVariant.muted,
                    padding: EdgeInsets.zero,
                    child: EmptyState(
                      icon: Icons.playlist_add_check_outlined,
                      title: '\u8fd8\u6ca1\u6709\u5b50\u4efb\u52a1',
                      message:
                          '\u70b9\u51fb\u65b0\u589e\u521b\u5efa\u5b50\u4efb\u52a1\u3002',
                      actionLabel: '\u65b0\u589e',
                      onAction: _showCreateTaskSheet,
                      compact: true,
                    ),
                  ),
                ],
              ]),
            ),
          ),
          if (activeTasks.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == 0) {
                      return _GoalTaskGroupHeader(
                        title: '\u5f85\u5b8c\u6210',
                        count: activeTasks.length,
                        icon: Icons.radio_button_unchecked_rounded,
                      );
                    }

                    final task = activeTasks[index - 1];
                    return _buildTaskRow(task, completed: false);
                  },
                  childCount: activeTasks.length + 1,
                ),
              ),
            ),
          if (completedTasks.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == 0) {
                      return _GoalTaskGroupHeader(
                        title: '\u5df2\u5b8c\u6210',
                        count: completedTasks.length,
                        icon: Icons.check_circle_outline_rounded,
                        muted: true,
                      );
                    }

                    final task = completedTasks[index - 1];
                    return _buildTaskRow(task, completed: true);
                  },
                  childCount: completedTasks.length + 1,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  List<TaskItem> get _activeTasks {
    return _tasks.where((task) => !task.isCompleted).toList();
  }

  List<TaskItem> get _completedTasks {
    return _tasks.where((task) => task.isCompleted).toList()
      ..sort((left, right) {
        final leftCompletedAt = left.completedAt;
        final rightCompletedAt = right.completedAt;
        if (leftCompletedAt != null && rightCompletedAt != null) {
          return rightCompletedAt.compareTo(leftCompletedAt);
        }
        if (leftCompletedAt == null && rightCompletedAt != null) {
          return 1;
        }
        if (leftCompletedAt != null && rightCompletedAt == null) {
          return -1;
        }
        return left.createdAt.compareTo(right.createdAt);
      });
  }

  Widget _buildTaskRow(TaskItem task, {required bool completed}) {
    return _TaskRow(
      itemKey: _taskKeyFor(task.id),
      task: task,
      highlighted: _highlightedTaskId == task.id,
      onComplete: completed ? null : () => _completeTask(task),
      onEdit: () => _showEditTaskSheet(task),
      onPostpone: completed ? null : () => _postponeTask(task),
      onDelete: () => _deleteTask(task),
    );
  }

  double get _calculatedProgress {
    if (_tasks.isEmpty) {
      return _goal?.normalizedProgress ?? 0;
    }

    return _completedCount / _tasks.length;
  }

  int get _completedCount {
    return _tasks.where((task) => task.isCompleted).length;
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final goalRepository = context.read<GoalRepository>();
      final taskRepository = context.read<TaskRepository>();
      final documentRepository = context.read<DocumentRepository>();
      final results = await Future.wait([
        goalRepository.findById(widget.goalId),
        taskRepository.findByGoalId(widget.goalId),
        goalRepository.findAll(),
        documentRepository.findByGoalId(widget.goalId, limit: 3),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _goal = results[0] as Goal?;
        _tasks
          ..clear()
          ..addAll(results[1] as List<TaskItem>);
        _goals
          ..clear()
          ..addAll(results[2] as List<Goal>);
        _documents
          ..clear()
          ..addAll(results[3] as List<EvolyDocument>);
        _loading = false;
      });
      _scheduleInitialTaskReveal();
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

  Future<void> _showCreateTaskSheet() async {
    final created = await showAdaptiveFormModal<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return TaskCreateSheet(
          onCreate: (title, estimatedMinutes, dueDateTime, reminder) {
            return _createTask(
              title,
              estimatedMinutes,
              dueDateTime,
              reminder,
            );
          },
        );
      },
    );

    if (created == true) {
      await _loadDetail();
    }
  }

  Future<void> _openDocument(EvolyDocument document) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.documentEdit,
      arguments: document.id,
    );
    await _loadDetail();
  }

  Future<void> _openGoalFolder() async {
    final goal = _goal;
    if (goal == null) {
      return;
    }

    await Navigator.pushNamed(
      context,
      AppRoutes.documentGoalFolder,
      arguments: goal.id,
    );
    await _loadDetail();
  }

  Future<void> _createLinkedDocument() async {
    final goal = _goal;
    if (goal == null) {
      return;
    }

    await Navigator.pushNamed(
      context,
      AppRoutes.documentEdit,
      arguments: DocumentEditArguments(
        initialLinkedGoalId: goal.id,
        initialTitle: '${goal.title} 过程记录',
        initialType: DocumentType.projectNote,
      ),
    );
    await _loadDetail();
  }

  Future<void> _createProjectSummary() async {
    final goal = _goal;
    if (goal == null) {
      return;
    }

    final documentRepository = context.read<DocumentRepository>();
    final summaryTitle = '项目总结：${goal.title}';
    final linkedDocuments = await documentRepository.findByGoalId(goal.id);

    for (final document in linkedDocuments) {
      if (document.type == DocumentType.projectSummary &&
          document.title == summaryTitle) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已存在项目总结，已为你打开。')),
        );
        await _openDocument(document);
        return;
      }
    }

    final now = DateTime.now();
    final document = EvolyDocument(
      id: 'document-${const Uuid().v4()}',
      title: summaryTitle,
      contentMarkdown: buildProjectSummaryMarkdown(
        goal: goal,
        tasks: _tasks,
        progress: _calculatedProgress,
        generatedAt: now,
      ),
      type: DocumentType.projectSummary,
      createdAt: now,
      updatedAt: now,
    );

    await documentRepository.save(document);
    await documentRepository.replaceLinkedGoals(document.id, [goal.id]);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已创建项目总结草稿。')),
    );
    await _openDocument(document);
  }

  Future<void> _showEditGoalSheet() async {
    final goal = _goal;
    if (goal == null) {
      return;
    }

    final updated = await showAdaptiveFormModal<bool>(
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
      await _loadDetail();
    }
  }

  Future<void> _createTask(
    String title,
    int estimatedMinutes,
    DateTime? dueDateTime,
    TaskReminderSelection reminder,
  ) async {
    final goal = _goal;
    if (goal == null) {
      return;
    }

    final taskRepository = context.read<TaskRepository>();
    final reminderService = context.read<TaskReminderService>();
    final now = DateTime.now();
    final task = TaskItem(
      id: const Uuid().v4(),
      goalId: goal.id,
      title: title,
      priority: goal.priority,
      status: TaskStatus.pending,
      estimatedMinutes: estimatedMinutes.clamp(1, 1440),
      dueDateTime: dueDateTime,
      createdAt: now,
      updatedAt: now,
    );

    await taskRepository.save(task);
    if (reminder.enabled) {
      await reminderService.saveForTask(
        taskId: task.id,
        remindAt: reminder.remindAt,
        repeatRule: reminder.repeatRule,
        notificationBody: task.title,
      );
    }
    if (mounted) {
      notifyDataChanged();
    }
  }

  Future<void> _saveGoal(Goal updatedGoal) async {
    final oldGoal = _goal;

    setState(() {
      _goal = updatedGoal;
    });

    try {
      await context.read<GoalRepository>().save(updatedGoal);
      if (mounted) {
        notifyDataChanged();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _goal = oldGoal;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }

  Future<void> _completeTask(TaskItem task) async {
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

  Future<void> _postponeTask(TaskItem task) async {
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

  Future<void> _deleteTask(TaskItem task) async {
    final repository = context.read<TaskRepository>();
    final reminderService = context.read<TaskReminderService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除任务？'),
          content: Text('「${task.title}」会从这个项目中移除。'),
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
          title: '编辑子任务',
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
      await _loadDetail();
    }
  }

  Future<void> _updateTask(TaskItem oldTask, TaskItem newTask) async {
    final index = _tasks.indexWhere((task) => task.id == oldTask.id);
    final previousTasks = [..._tasks];
    final movedToOtherProject = newTask.goalId != widget.goalId;

    if (index != -1) {
      setState(() {
        if (movedToOtherProject) {
          _tasks.removeAt(index);
        } else {
          _tasks[index] = newTask;
        }
      });
    }

    try {
      await context.read<TaskRepository>().save(newTask);
      if (mounted) {
        notifyDataChanged();
        if (index != -1 && movedToOtherProject) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已移动到「${_projectTitleFor(newTask.goalId)}」'),
            ),
          );
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (index != -1) {
        setState(() {
          _tasks
            ..clear()
            ..addAll(previousTasks);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }

  GlobalKey? _taskKeyFor(String taskId) {
    if (taskId != widget.initialTaskId && taskId != _highlightedTaskId) {
      return null;
    }

    return _taskKeys.putIfAbsent(taskId, GlobalKey.new);
  }

  void _scheduleInitialTaskReveal() {
    final taskId = widget.initialTaskId;
    if (taskId == null || _initialTaskRevealConsumed) {
      return;
    }
    if (!_tasks.any((task) => task.id == taskId)) {
      return;
    }

    _initialTaskRevealConsumed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final rowContext = _taskKeys[taskId]?.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          alignment: 0.36,
          duration: MotionTokens.normal,
          curve: MotionTokens.standard,
        );
      } else {
        final taskIndex = _presentedTaskIndex(taskId);
        if (taskIndex != -1 && _scrollController.hasClients) {
          final estimatedOffset = 520 + taskIndex * 96.0;
          _scrollController.animateTo(
            estimatedOffset.clamp(
              0,
              _scrollController.position.maxScrollExtent,
            ),
            duration: MotionTokens.normal,
            curve: MotionTokens.standard,
          );
        }
      }

      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 2600), () {
        if (!mounted || _highlightedTaskId != taskId) {
          return;
        }
        setState(() => _highlightedTaskId = null);
      });
    });
  }

  int _presentedTaskIndex(String taskId) {
    final activeTasks = _activeTasks;
    final activeIndex = activeTasks.indexWhere((task) => task.id == taskId);
    if (activeIndex != -1) {
      return activeIndex;
    }

    final completedIndex =
        _completedTasks.indexWhere((task) => task.id == taskId);
    if (completedIndex == -1) {
      return -1;
    }

    return activeTasks.length + completedIndex;
  }

  String _projectTitleFor(String goalId) {
    return _goals.where((goal) => goal.id == goalId).firstOrNull?.title ??
        '未同步项目';
  }
}

class _GoalOverviewSection extends StatelessWidget {
  const _GoalOverviewSection({
    required this.goal,
    required this.progress,
    required this.completedCount,
    required this.taskCount,
  });

  final Goal goal;
  final double progress;
  final int completedCount;
  final int taskCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EvolyDesignTokens.of(context);
    final description = goal.description.trim();

    return AppSurface(
      variant: AppSurfaceVariant.raised,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            goal.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: tokens.textPrimary,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppStatusBadge(
                label: goal.status.label,
                color: _statusColor(context, goal.status),
                icon: _statusIcon(goal.status),
              ),
              AppMetaPill(
                label: '${goal.priority.label}优先级',
                icon: Icons.flag_rounded,
                color: _priorityColor(tokens, goal.priority),
                selected: true,
              ),
              if (goal.dueDate != null)
                AppMetaPill(
                  label: '截止 ${_formatDate(goal.dueDate!)}',
                  icon: Icons.event_outlined,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedProgressBar(value: progress),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$completedCount/$taskCount 个子任务完成',
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(EvolyDesignTokens tokens, Priority priority) {
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

  IconData _statusIcon(GoalStatus status) {
    return switch (status) {
      GoalStatus.notStarted => Icons.radio_button_unchecked_rounded,
      GoalStatus.inProgress => Icons.track_changes_rounded,
      GoalStatus.completed => Icons.check_circle_rounded,
      GoalStatus.paused => Icons.pause_circle_outline_rounded,
      GoalStatus.abandoned => Icons.cancel_rounded,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _GoalDocumentsSection extends StatelessWidget {
  const _GoalDocumentsSection({
    required this.goal,
    required this.documents,
    required this.onOpenDocument,
    required this.onCreateDocument,
    required this.onCreateSummary,
    required this.onOpenFolder,
  });

  final Goal goal;
  final List<EvolyDocument> documents;
  final ValueChanged<EvolyDocument> onOpenDocument;
  final VoidCallback onCreateDocument;
  final VoidCallback onCreateSummary;
  final VoidCallback onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EvolyDesignTokens.of(context);

    return AppSection(
      title: '项目档案',
      padding: EdgeInsets.zero,
      trailing: TextButton.icon(
        onPressed: onOpenFolder,
        icon: const Icon(Icons.folder_open_outlined),
        label: const Text('打开文件夹'),
      ),
      child: AppSurface(
        variant: AppSurfaceVariant.raised,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.icon(
                  onPressed: onCreateSummary,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                    goal.status == GoalStatus.completed ? '创建项目总结' : '创建总结草稿',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onCreateDocument,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('新建过程记录'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (documents.isEmpty)
              Text(
                goal.status == GoalStatus.completed ? '可创建项目总结。' : '暂无文档。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              )
            else
              ...documents.map((document) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.element),
                    onTap: () => onOpenDocument(document),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            child: Icon(
                              document.type == DocumentType.projectSummary
                                  ? Icons.fact_check_outlined
                                  : Icons.article_outlined,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  document.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  document.excerpt,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: tokens.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _GoalTasksSection extends StatelessWidget {
  const _GoalTasksSection({
    required this.tasks,
    required this.onCreateTask,
    required this.onCompleteTask,
    required this.onEditTask,
    required this.onPostponeTask,
    required this.onDeleteTask,
    required this.highlightedTaskId,
    required this.taskKeyFor,
  });

  final List<TaskItem> tasks;
  final VoidCallback onCreateTask;
  final ValueChanged<TaskItem> onCompleteTask;
  final ValueChanged<TaskItem> onEditTask;
  final ValueChanged<TaskItem> onPostponeTask;
  final ValueChanged<TaskItem> onDeleteTask;
  final String? highlightedTaskId;
  final GlobalKey Function(String taskId) taskKeyFor;

  @override
  Widget build(BuildContext context) {
    final activeTasks = tasks.where((task) => !task.isCompleted).toList();
    final completedTasks = tasks.where((task) => task.isCompleted).toList()
      ..sort((left, right) {
        final leftCompletedAt = left.completedAt;
        final rightCompletedAt = right.completedAt;
        if (leftCompletedAt != null && rightCompletedAt != null) {
          return rightCompletedAt.compareTo(leftCompletedAt);
        }
        if (leftCompletedAt == null && rightCompletedAt != null) {
          return 1;
        }
        if (leftCompletedAt != null && rightCompletedAt == null) {
          return -1;
        }
        return left.createdAt.compareTo(right.createdAt);
      });

    return AppSection(
      title: '子任务',
      padding: EdgeInsets.zero,
      trailing: TextButton.icon(
        onPressed: onCreateTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增'),
      ),
      child: tasks.isEmpty
          ? AppSurface(
              variant: AppSurfaceVariant.muted,
              padding: EdgeInsets.zero,
              child: EmptyState(
                icon: Icons.playlist_add_check_outlined,
                title: '还没有子任务',
                message: '点击新增创建子任务。',
                actionLabel: '新增',
                onAction: onCreateTask,
                compact: true,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (activeTasks.isNotEmpty) ...[
                  _GoalTaskGroupHeader(
                    title: '待完成',
                    count: activeTasks.length,
                    icon: Icons.radio_button_unchecked_rounded,
                  ),
                  for (final task in activeTasks)
                    _TaskRow(
                      itemKey: taskKeyFor(task.id),
                      task: task,
                      highlighted: highlightedTaskId == task.id,
                      onComplete: () => onCompleteTask(task),
                      onEdit: () => onEditTask(task),
                      onPostpone: () => onPostponeTask(task),
                      onDelete: () => onDeleteTask(task),
                    ),
                ],
                if (completedTasks.isNotEmpty) ...[
                  _GoalTaskGroupHeader(
                    title: '已完成',
                    count: completedTasks.length,
                    icon: Icons.check_circle_outline_rounded,
                    muted: true,
                  ),
                  for (final task in completedTasks)
                    _TaskRow(
                      itemKey: taskKeyFor(task.id),
                      task: task,
                      highlighted: highlightedTaskId == task.id,
                      onEdit: () => onEditTask(task),
                      onDelete: () => onDeleteTask(task),
                    ),
                ],
              ],
            ),
    );
  }
}

class _GoalTaskGroupHeader extends StatelessWidget {
  const _GoalTaskGroupHeader({
    required this.title,
    required this.count,
    required this.icon,
    this.muted = false,
  });

  final String title;
  final int count;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = EvolyDesignTokens.of(context);
    final color = muted ? tokens.textSecondary : tokens.textPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              title,
              style: textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AppMetaPill(
            label: '$count 项',
            icon: icon,
            color: muted ? tokens.statusSuccess : null,
            selected: muted,
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.itemKey,
    required this.task,
    required this.onDelete,
    required this.onEdit,
    required this.highlighted,
    this.onComplete,
    this.onPostpone,
  });

  final GlobalKey? itemKey;
  final TaskItem task;
  final VoidCallback onEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onPostpone;
  final VoidCallback onDelete;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = EvolyDesignTokens.of(context);
    final accent = tokens.hudAccent;

    return Dismissible(
      key: ValueKey(task.id),
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
      child: KeyedSubtree(
        key: itemKey,
        child: AnimatedContainer(
          duration: MotionTokens.normal,
          curve: MotionTokens.standard,
          decoration: BoxDecoration(
            color: highlighted
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: highlighted
                  ? accent.withValues(alpha: 0.62)
                  : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(AppRadii.container),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: AnimatedContainer(
                  duration: MotionTokens.normal,
                  curve: MotionTokens.standard,
                  width: highlighted ? 4 : 0,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
              InkWell(
                onTap: onEdit,
                child: TaskCard(
                  task: task,
                  onComplete: onComplete,
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  trailing: PopupMenuButton<_TaskAction>(
                    onSelected: (action) {
                      switch (action) {
                        case _TaskAction.edit:
                          onEdit();
                        case _TaskAction.postpone:
                          onPostpone?.call();
                        case _TaskAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _TaskAction.edit,
                        child: Text('编辑'),
                      ),
                      PopupMenuItem(
                        value: _TaskAction.postpone,
                        enabled: onPostpone != null,
                        child: const Text('延期到明天'),
                      ),
                      const PopupMenuItem(
                        value: _TaskAction.delete,
                        child: Text('删除'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TaskAction {
  edit,
  postpone,
  delete,
}
