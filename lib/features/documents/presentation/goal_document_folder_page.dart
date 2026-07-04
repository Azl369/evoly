import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/features/documents/application/project_summary_template.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/documents/presentation/document_edit_page.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';
import 'package:evoly/shared/ui/components/animated_progress_bar.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/widgets/empty_state.dart';
import 'package:evoly/shared/widgets/evoly_navigation_bar.dart';

class GoalDocumentFolderPage extends StatefulWidget {
  const GoalDocumentFolderPage({
    required this.goalId,
    super.key,
  });

  final String goalId;

  @override
  State<GoalDocumentFolderPage> createState() => _GoalDocumentFolderPageState();
}

class _GoalDocumentFolderPageState extends State<GoalDocumentFolderPage> {
  Goal? _goal;
  final List<EvolyDocument> _documents = [];
  final List<TaskItem> _tasks = [];
  var _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFolder());
  }

  @override
  Widget build(BuildContext context) {
    final goalTitle = _goal?.title ?? '目标档案夹';

    return Scaffold(
      appBar: AppBar(
        title: Text(goalTitle),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadFolder,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _goal == null
          ? null
          : FloatingActionButton(
              onPressed: _createLinkedDocument,
              tooltip: '新建文档',
              child: const Icon(Icons.note_add_outlined),
            ),
      bottomNavigationBar: const EvolyNavigationBar(selectedIndex: 2),
    );
  }

  Widget _buildBody() {
    if (widget.goalId.isEmpty) {
      return const EmptyState(
        icon: Icons.link_off_outlined,
        title: '目标参数缺失',
        message: '请从文档库或目标详情重新进入目标档案夹。',
      );
    }

    if (_loading) {
      return const AppLoadingState(label: '正在打开档案夹');
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '档案夹加载失败',
        message: errorMessage,
      );
    }

    final goal = _goal;
    if (goal == null) {
      return const EmptyState(
        icon: Icons.folder_off_outlined,
        title: '目标不存在',
        message: '这个目标可能已经被删除，无法打开对应档案夹。',
      );
    }

    final progress = _calculatedProgress;

    return RefreshIndicator(
      onRefresh: _loadFolder,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl * 2,
        ),
        children: [
          _FolderHeader(
            goal: goal,
            progress: progress,
            taskCount: _tasks.length,
            documentCount: _documents.length,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: _createProjectSummary,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  goal.status == GoalStatus.completed ? '创建项目总结' : '创建总结草稿',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _createLinkedDocument,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('新建过程记录'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('文件夹内文档', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (_documents.isEmpty)
            const EmptyState(
              icon: Icons.article_outlined,
              title: '这个目标还没有文档',
              message: '可新建过程记录或项目总结。',
            )
          else
            ..._documents.map((document) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _FolderDocumentCard(
                  document: document,
                  onTap: () => _openDocument(document),
                ),
              );
            }),
        ],
      ),
    );
  }

  double get _calculatedProgress {
    if (_tasks.isEmpty) {
      return _goal?.normalizedProgress ?? 0;
    }

    final completedCount = _tasks.where((task) => task.isCompleted).length;
    return completedCount / _tasks.length;
  }

  Future<void> _loadFolder() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final goalRepository = context.read<GoalRepository>();
      final taskRepository = context.read<TaskRepository>();
      final documentRepository = context.read<DocumentRepository>();
      final results = await Future.wait([
        goalRepository.findById(widget.goalId),
        taskRepository.findByGoalId(widget.goalId),
        documentRepository.findByGoalId(widget.goalId),
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
        _errorMessage = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _openDocument(EvolyDocument document) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.documentEdit,
      arguments: document.id,
    );
    await _loadFolder();
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
    await _loadFolder();
  }

  Future<void> _createProjectSummary() async {
    final goal = _goal;
    if (goal == null) {
      return;
    }

    final documentRepository = context.read<DocumentRepository>();
    final summaryTitle = '项目总结：${goal.title}';

    for (final document in _documents) {
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
}

class _FolderHeader extends StatelessWidget {
  const _FolderHeader({
    required this.goal,
    required this.progress,
    required this.taskCount,
    required this.documentCount,
  });

  final Goal goal;
  final double progress;
  final int taskCount;
  final int documentCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = (progress.clamp(0.0, 1.0) * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.folder_rounded)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    goal.title,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (goal.description.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(goal.description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.md),
            AnimatedProgressBar(value: progress),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${_goalStatusLabel(goal.status)} · $progressPercent% · $taskCount 个子任务 · $documentCount 篇文档',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderDocumentCard extends StatelessWidget {
  const _FolderDocumentCard({
    required this.document,
    required this.onTap,
  });

  final EvolyDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(
                  document.type == DocumentType.projectSummary
                      ? Icons.fact_check_outlined
                      : Icons.article_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(document.type.label),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      document.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '更新于 ${_formatDateTime(document.updatedAt)}',
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
  }
}

String _goalStatusLabel(GoalStatus status) {
  return switch (status) {
    GoalStatus.notStarted => '未开始',
    GoalStatus.inProgress => '进行中',
    GoalStatus.completed => '已完成',
    GoalStatus.paused => '已暂停',
    GoalStatus.abandoned => '已放弃',
  };
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.month}/${value.day} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}
