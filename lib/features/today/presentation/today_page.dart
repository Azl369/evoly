import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/coach/application/rule_based_coach_service.dart';
import 'package:evoly/features/coach/domain/coach_insight.dart';
import 'package:evoly/features/reminders/application/reminder_inbox.dart';
import 'package:evoly/features/reminders/application/task_reminder_service.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_card.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_edit_sheet.dart';
import 'package:evoly/shared/ui/components/animated_progress_bar.dart';
import 'package:evoly/shared/ui/motion/motion_tokens.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/widgets/empty_state.dart';
import 'package:evoly/shared/widgets/evoly_navigation_bar.dart';

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

class _TodayPageState extends State<TodayPage> {
  final List<TaskItem> _tasks = [];
  var _loading = true;
  var _coachExpanded = true;
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
  Widget build(BuildContext context) {
    final completedCount = _tasks.where((task) => task.isCompleted).length;
    final progress = _tasks.isEmpty ? 0.0 : completedCount / _tasks.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日计划'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: _buildBody(progress),
      bottomNavigationBar: widget.showBottomNavigationBar
          ? const EvolyNavigationBar(selectedIndex: 0)
          : null,
    );
  }

  Widget _buildBody(double progress) {
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

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今天最重要的事', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '保持小步前进，别让目标躺平。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              AnimatedProgressBar(value: progress),
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
        ),
        if (_tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: EmptyState(
              icon: Icons.task_alt_outlined,
              title: '今天暂时没有任务',
              message: '去目标页创建一个目标，让今天有个轻轻的抓手。',
            ),
          ),
        for (final group in _taskGroups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              group.title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final task in group.tasks)
            _TodayTaskRow(
              key: ValueKey(task.id),
              task: task,
              onEdit: () => _showEditTaskSheet(task),
              onComplete: task.isCompleted ? null : () => _complete(task),
              onPostpone: task.isCompleted ? null : () => _postpone(task),
              onDelete: () => _delete(task),
            ),
        ],
      ],
    );
  }

  List<_TaskGroup> get _taskGroups {
    final pending = _sortedTasks.where((task) => !task.isCompleted).toList();
    final completed = _sortedTasks.where((task) => task.isCompleted).toList();

    return [
      _TaskGroup(
        title: '高优先级',
        tasks: pending.where((task) => task.priority == Priority.high).toList(),
      ),
      _TaskGroup(
        title: '中优先级',
        tasks:
            pending.where((task) => task.priority == Priority.medium).toList(),
      ),
      _TaskGroup(
        title: '低优先级',
        tasks: pending.where((task) => task.priority == Priority.low).toList(),
      ),
      _TaskGroup(title: '已完成', tasks: completed),
    ].where((group) => group.tasks.isNotEmpty).toList();
  }

  List<TaskItem> get _sortedTasks {
    final tasks = [..._tasks];
    tasks.sort((left, right) {
      final priorityCompare =
          right.priority.weight.compareTo(left.priority.weight);
      if (priorityCompare != 0) {
        return priorityCompare;
      }

      return _compareNullableDate(left.dueDateTime, right.dueDateTime);
    });

    return tasks;
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

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<TaskRepository>();
      final coachService = context.read<RuleBasedCoachService>();
      final now = DateTime.now();
      final results = await Future.wait([
        repository.findDueToday(now),
        coachService.generateTodayInsight(now),
      ]);
      if (!mounted) {
        return;
      }

      setState(() {
        _tasks
          ..clear()
          ..addAll(results[0] as List<TaskItem>);
        _coachInsight = results[1] as CoachInsight;
        _loading = false;
      });
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
        const SnackBar(content: Text('这项任务已经不在今天列表里了')),
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
    final tasksToPostpone = _tasks.where((task) {
      return !task.isCompleted && !topTaskIds.contains(task.id);
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
          content: Text('「${task.title}」会从今天的计划中移除。'),
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

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return TaskEditSheet(
          title: '编辑任务',
          task: task,
          reminder: reminder,
          onSave: (updatedTask, remindAt) async {
            await _updateTask(task, updatedTask);
            await reminderService.saveForTask(
              taskId: task.id,
              remindAt: remindAt,
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

    setState(() {
      _tasks[index] = newTask;
    });

    try {
      await taskRepository.save(newTask);
      final coachInsight = await coachService.generateTodayInsight(
        DateTime.now(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _coachInsight = coachInsight;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _tasks[index] = oldTask;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
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
                '今天任务偏多，Coach 建议先专注 Top 3，其余任务延期到明天。确认前不会修改任何数据。',
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
      return '高优先级，优先推动核心目标';
    }
    if (dueDate != null && dueDate.isBefore(DateTime.now())) {
      return '已经过了计划时间，适合今天先收掉';
    }
    if (dueDate != null) {
      return '截止时间靠前，今天处理更稳';
    }

    return '在今日 Top 3 中，适合优先推进';
  }

  String _postponeReasonFor(TaskItem task) {
    if (task.priority == Priority.low) {
      return '低优先级，适合让位给关键任务';
    }
    if (task.estimatedMinutes >= 60) {
      return '耗时较长，今天先避免过载';
    }

    return '不是今日 Top 3，先延期保持专注';
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

class _TodayTaskRow extends StatelessWidget {
  const _TodayTaskRow({
    required super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    this.onComplete,
    this.onPostpone,
  });

  final TaskItem task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onComplete;
  final VoidCallback? onPostpone;

  @override
  Widget build(BuildContext context) {
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
      child: InkWell(
        onTap: onEdit,
        child: TaskCard(
          task: task,
          onComplete: onComplete,
          trailing: PopupMenuButton<_TodayTaskAction>(
            onSelected: (action) {
              switch (action) {
                case _TodayTaskAction.edit:
                  onEdit();
                case _TodayTaskAction.postpone:
                  onPostpone?.call();
                case _TodayTaskAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _TodayTaskAction.edit,
                child: Text('编辑'),
              ),
              PopupMenuItem(
                value: _TodayTaskAction.postpone,
                enabled: onPostpone != null,
                child: const Text('延期到明天'),
              ),
              const PopupMenuItem(
                value: _TodayTaskAction.delete,
                child: Text('删除'),
              ),
            ],
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
    final insight = this.insight;

    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onToggleExpanded,
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_alt_outlined,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Evoly Coach 今日建议',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: MotionTokens.fast,
                    curve: MotionTokens.standard,
                    child: const Icon(Icons.keyboard_arrow_down),
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
                              onOpenFirstDelayedGoal: onOpenFirstDelayedGoal,
                              onReviewCompletedDay: onReviewCompletedDay,
                            ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
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
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(insight.summary, style: textTheme.bodyMedium),
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
            label: const Text('查看延期目标'),
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
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _CoachTopTaskTile extends StatelessWidget {
  const _CoachTopTaskTile({required this.task});

  final CoachTopTask task;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.radio_button_checked,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
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
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            Icons.flag_circle_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.error,
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
    final color = switch (suggestion.severity) {
      CoachSuggestionSeverity.success => Theme.of(context).colorScheme.primary,
      CoachSuggestionSeverity.warning => Theme.of(context).colorScheme.error,
      CoachSuggestionSeverity.info => Theme.of(context).colorScheme.secondary,
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 18, color: color),
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
    required this.title,
    required this.tasks,
  });

  final String title;
  final List<TaskItem> tasks;
}

enum _TodayTaskAction {
  edit,
  postpone,
  delete,
}
