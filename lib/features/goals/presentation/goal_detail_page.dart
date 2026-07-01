import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/features/documents/application/project_summary_template.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/documents/presentation/document_edit_page.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/goals/presentation/widgets/goal_edit_sheet.dart';
import 'package:evoly/features/reminders/application/task_reminder_service.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_card.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_create_sheet.dart';
import 'package:evoly/features/tasks/presentation/widgets/task_edit_sheet.dart';
import 'package:evoly/shared/ui/components/animated_progress_bar.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/widgets/empty_state.dart';
import 'package:uuid/uuid.dart';

class GoalDetailPage extends StatefulWidget {
  const GoalDetailPage({
    required this.goalId,
    super.key,
  });

  final String goalId;

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  Goal? _goal;
  final List<TaskItem> _tasks = [];
  final List<EvolyDocument> _documents = [];
  var _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('目标详情'),
        actions: [
          IconButton(
            onPressed: _goal == null ? null : _showEditGoalSheet,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _goal == null ? null : _showCreateTaskSheet,
            icon: const Icon(Icons.add_task_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.goalId.isEmpty) {
      return const EmptyState(
        icon: Icons.link_off_outlined,
        title: '目标参数缺失',
        message: '请从目标列表重新进入详情页。',
      );
    }

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

    final goal = _goal;
    if (goal == null) {
      return const EmptyState(
        icon: Icons.flag_outlined,
        title: '目标不存在',
        message: '这个目标可能已经被删除了。',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(goal.title, style: Theme.of(context).textTheme.headlineSmall),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(goal.description,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.lg),
          AnimatedProgressBar(value: _calculatedProgress),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$_completedCount/${_tasks.length} 个子任务完成',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          _GoalDocumentsSection(
            goal: goal,
            documents: _documents,
            onOpenDocument: _openDocument,
            onCreateDocument: _createLinkedDocument,
            onCreateSummary: _createProjectSummary,
            onOpenFolder: _openGoalFolder,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text('子任务', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: _showCreateTaskSheet,
                icon: const Icon(Icons.add_rounded),
                label: const Text('新增'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_tasks.isEmpty)
            const EmptyState(
              icon: Icons.playlist_add_check_outlined,
              title: '还没有子任务',
              message: '新增一个小步骤，目标就会开始向前滚动。',
            )
          else
            for (final task in _tasks)
              _TaskRow(
                task: task,
                onComplete: task.isCompleted ? null : () => _completeTask(task),
                onEdit: () => _showEditTaskSheet(task),
                onPostpone: task.isCompleted ? null : () => _postponeTask(task),
                onDelete: () => _deleteTask(task),
              ),
        ],
      ),
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
        _documents
          ..clear()
          ..addAll(results[2] as List<EvolyDocument>);
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

  Future<void> _showCreateTaskSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return TaskCreateSheet(
          onCreate: (title, estimatedMinutes) {
            return _createTask(title, estimatedMinutes);
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
      await _loadDetail();
    }
  }

  Future<void> _createTask(String title, int estimatedMinutes) async {
    final goal = _goal;
    if (goal == null) {
      return;
    }

    final now = DateTime.now();
    final task = TaskItem(
      id: const Uuid().v4(),
      goalId: goal.id,
      title: title,
      priority: goal.priority,
      status: TaskStatus.pending,
      estimatedMinutes: estimatedMinutes.clamp(1, 1440),
      dueDateTime: DateTime(now.year, now.month, now.day, 23, 59),
      createdAt: now,
      updatedAt: now,
    );

    await context.read<TaskRepository>().save(task);
  }

  Future<void> _saveGoal(Goal updatedGoal) async {
    final oldGoal = _goal;

    setState(() {
      _goal = updatedGoal;
    });

    try {
      await context.read<GoalRepository>().save(updatedGoal);
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
          content: Text('「${task.title}」会从这个目标中移除。'),
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
          title: '编辑子任务',
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
      await _loadDetail();
    }
  }

  Future<void> _updateTask(TaskItem oldTask, TaskItem newTask) async {
    final index = _tasks.indexWhere((task) => task.id == oldTask.id);
    if (index == -1) {
      return;
    }

    setState(() {
      _tasks[index] = newTask;
    });

    try {
      await context.read<TaskRepository>().save(newTask);
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('目标档案', style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: onOpenFolder,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('打开文件夹'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.xs),
            if (documents.isEmpty)
              Text(
                goal.status == GoalStatus.completed
                    ? '目标已完成，可以写一篇项目总结，把过程沉淀下来。'
                    : '这个目标文件夹还没有文档。记录过程、问题和经验，目标就不只是一串任务了。',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...documents.map((document) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
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
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
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

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onDelete,
    required this.onEdit,
    this.onComplete,
    this.onPostpone,
  });

  final TaskItem task;
  final VoidCallback onEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onPostpone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
      child: InkWell(
        onTap: onEdit,
        child: TaskCard(
          task: task,
          onComplete: onComplete,
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
    );
  }
}

enum _TaskAction {
  edit,
  postpone,
  delete,
}
