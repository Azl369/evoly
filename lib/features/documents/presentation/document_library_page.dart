import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/document_folder_summary.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/widgets/empty_state.dart';
import 'package:evoly/shared/widgets/evoly_navigation_bar.dart';

class DocumentLibraryPage extends StatefulWidget {
  const DocumentLibraryPage({
    this.showBottomNavigationBar = true,
    super.key,
  });

  final bool showBottomNavigationBar;

  @override
  State<DocumentLibraryPage> createState() => _DocumentLibraryPageState();
}

class _DocumentLibraryPageState extends State<DocumentLibraryPage> {
  final _searchController = TextEditingController();
  final List<DocumentFolderSummary> _folders = [];
  final List<EvolyDocument> _documents = [];
  final List<EvolyDocument> _unfiledDocuments = [];
  var _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLibrary());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文档库'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadLibrary,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: _openCreateDocument,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateDocument,
        tooltip: '新建文档',
        child: const Icon(Icons.edit_note_rounded),
      ),
      bottomNavigationBar: widget.showBottomNavigationBar
          ? const EvolyNavigationBar(selectedIndex: 2)
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(label: '正在打开文档库');
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '文档库加载失败',
        message: errorMessage,
      );
    }

    final isSearching = _searchController.text.trim().isNotEmpty;
    final visibleDocuments =
        isSearching ? _documents : _documents.take(5).toList();
    final visibleUnfiledDocuments =
        isSearching ? _unfiledDocuments : _unfiledDocuments.take(5).toList();
    final hasAnyContent = _folders.isNotEmpty ||
        visibleDocuments.isNotEmpty ||
        visibleUnfiledDocuments.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadLibrary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl * 2,
        ),
        children: [
          Text(
            '一个目标就是一个档案夹，把过程、复盘和知识沉淀都收在对应目标下面。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: '搜索目标文件夹或文档',
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _loadLibrary();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadLibrary(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!hasAnyContent)
            EmptyState(
              icon: Icons.folder_copy_outlined,
              title: isSearching ? '没有匹配内容' : '还没有目标档案',
              message: isSearching
                  ? '换个关键词试试，或者回到目标页确认是否有关联文档。'
                  : '先创建一个目标，再把过程记录、项目总结和复盘文档归档进去。',
            )
          else ...[
            if (_folders.isNotEmpty) ...[
              const _SectionHeader(
                title: '目标文件夹',
                subtitle: '按目标聚合文档，每个目标都有自己的档案夹。',
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._folders.map((folder) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _GoalFolderCard(
                    folder: folder,
                    onTap: () => _openGoalFolder(folder.goalId),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.md),
            ],
            if (visibleDocuments.isNotEmpty) ...[
              _SectionHeader(
                title: isSearching ? '匹配文档' : '最近文档',
                subtitle: isSearching ? '标题或正文命中的文档。' : '最近更新的文档，方便继续编辑。',
              ),
              const SizedBox(height: AppSpacing.sm),
              ...visibleDocuments.map((document) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _DocumentCard(
                    document: document,
                    onTap: () => _openDocument(document.id),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.md),
            ],
            if (visibleUnfiledDocuments.isNotEmpty) ...[
              const _SectionHeader(
                title: '未归档文档',
                subtitle: '这些文档还没有关联目标，后续可以归入目标文件夹。',
              ),
              const SizedBox(height: AppSpacing.sm),
              ...visibleUnfiledDocuments.map((document) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _DocumentCard(
                    document: document,
                    onTap: () => _openDocument(document.id),
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _loadLibrary() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final repository = context.read<DocumentRepository>();
      final query = _searchController.text;
      final results = await Future.wait([
        repository.findGoalFolders(query: query),
        repository.findAll(query: query),
        repository.findUnfiled(query: query),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _folders
          ..clear()
          ..addAll(results[0] as List<DocumentFolderSummary>);
        _documents
          ..clear()
          ..addAll(results[1] as List<EvolyDocument>);
        _unfiledDocuments
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

  Future<void> _openCreateDocument() async {
    await Navigator.pushNamed(context, AppRoutes.documentEdit);
    await _loadLibrary();
  }

  Future<void> _openDocument(String documentId) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.documentEdit,
      arguments: documentId,
    );
    await _loadLibrary();
  }

  Future<void> _openGoalFolder(String goalId) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.documentGoalFolder,
      arguments: goalId,
    );
    await _loadLibrary();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(
      title: title,
      subtitle: subtitle,
      padding: EdgeInsets.zero,
    );
  }
}

class _GoalFolderCard extends StatelessWidget {
  const _GoalFolderCard({
    required this.folder,
    required this.onTap,
  });

  final DocumentFolderSummary folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = (folder.goalProgress.clamp(0.0, 1.0) * 100).round();
    final latestTitle = folder.latestDocumentTitle?.trim();

    return AppSurfaceCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Icon(
                  folder.hasDocuments
                      ? Icons.folder_rounded
                      : Icons.create_new_folder_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.goalTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${_goalStatusLabel(folder.goalStatus)} · $progressPercent% · ${folder.documentCount} 篇文档',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            latestTitle == null || latestTitle.isEmpty
                ? '还没有文档，点进去创建过程记录或项目总结。'
                : '最近更新：$latestTitle',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          if (folder.latestUpdatedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formatDateTime(folder.latestUpdatedAt!),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.onTap,
  });

  final EvolyDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurfaceCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
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
              const SizedBox(width: AppSpacing.sm),
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
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '更新于 ${_formatDateTime(document.updatedAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
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
