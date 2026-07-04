import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/document_folder_summary.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/tokens/app_radii.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/ui/tokens/evoly_design_tokens.dart';
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
  static const _unfiledPreviewLimit = 3;

  final _searchController = TextEditingController();
  final _desktopFolderScrollController = ScrollController();
  final _desktopDocumentScrollController = ScrollController();
  final List<DocumentFolderSummary> _folders = [];
  final List<EvolyDocument> _documents = [];
  final List<EvolyDocument> _unfiledDocuments = [];
  var _loading = true;
  var _showEmptyFolders = false;
  var _showAllUnfiled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLibrary());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _desktopFolderScrollController.dispose();
    _desktopDocumentScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useDesktopLayout = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文档库'),
        actions: [
          IconButton(
            tooltip: '刷新文档库',
            onPressed: _loading ? null : _loadLibrary,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (useDesktopLayout)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: FilledButton.icon(
                onPressed: _openCreateDocument,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('新建文档'),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: useDesktopLayout
          ? null
          : FloatingActionButton(
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

    final queryText = _searchController.text.trim();
    final normalizedQuery = queryText.toLowerCase();
    final isSearching = normalizedQuery.isNotEmpty;
    final documentFolders =
        _folders.where((folder) => folder.hasDocuments).toList();
    final emptyFolders =
        _folders.where((folder) => !folder.hasDocuments).toList();
    final unfiledDocuments = _uniqueDocuments(_unfiledDocuments);
    final unfiledIds = unfiledDocuments.map((document) => document.id).toSet();
    final matchingFolders = isSearching
        ? _folders
            .where((folder) => _matchesFolder(folder, normalizedQuery))
            .toList()
        : const <DocumentFolderSummary>[];
    final matchingDocuments = isSearching
        ? _uniqueDocuments(
            _documents.where(
              (document) => _matchesDocument(document, normalizedQuery),
            ),
          )
        : const <EvolyDocument>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 980) {
          return _buildDesktopBody(
            maxWidth: constraints.maxWidth,
            isSearching: isSearching,
            queryText: queryText,
            documentFolders: documentFolders,
            emptyFolders: emptyFolders,
            unfiledDocuments: unfiledDocuments,
            matchingFolders: matchingFolders,
            matchingDocuments: matchingDocuments,
            unfiledIds: unfiledIds,
          );
        }

        return _buildMobileBody(
          isSearching: isSearching,
          queryText: queryText,
          documentFolders: documentFolders,
          emptyFolders: emptyFolders,
          unfiledDocuments: unfiledDocuments,
          matchingFolders: matchingFolders,
          matchingDocuments: matchingDocuments,
          unfiledIds: unfiledIds,
        );
      },
    );
  }

  Widget _buildMobileBody({
    required bool isSearching,
    required String queryText,
    required List<DocumentFolderSummary> documentFolders,
    required List<DocumentFolderSummary> emptyFolders,
    required List<EvolyDocument> unfiledDocuments,
    required List<DocumentFolderSummary> matchingFolders,
    required List<EvolyDocument> matchingDocuments,
    required Set<String> unfiledIds,
  }) {
    return RefreshIndicator(
      onRefresh: _loadLibrary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl * 2,
        ),
        children: [
          _LibrarySummaryCard(
            documentFolderCount: documentFolders.length,
            totalDocumentCount: _documents.length,
            unfiledDocumentCount: unfiledDocuments.length,
            emptyFolderCount: emptyFolders.length,
          ),
          const SizedBox(height: AppSpacing.md),
          _LibrarySearchField(
            controller: _searchController,
            isSearching: isSearching,
            onChanged: (_) => setState(() {}),
            onClear: _clearSearch,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isSearching)
            ..._buildSearchSections(
              queryText: queryText,
              matchingFolders: matchingFolders,
              matchingDocuments: matchingDocuments,
              unfiledIds: unfiledIds,
            )
          else
            ..._buildBrowseSections(
              documentFolders: documentFolders,
              emptyFolders: emptyFolders,
              unfiledDocuments: unfiledDocuments,
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody({
    required double maxWidth,
    required bool isSearching,
    required String queryText,
    required List<DocumentFolderSummary> documentFolders,
    required List<DocumentFolderSummary> emptyFolders,
    required List<EvolyDocument> unfiledDocuments,
    required List<DocumentFolderSummary> matchingFolders,
    required List<EvolyDocument> matchingDocuments,
    required Set<String> unfiledIds,
  }) {
    final leftWidth = maxWidth >= 1180 ? 430.0 : 388.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: leftWidth,
            child: Scrollbar(
              controller: _desktopFolderScrollController,
              child: ListView(
                controller: _desktopFolderScrollController,
                padding: EdgeInsets.zero,
                children: [
                  _LibrarySummaryCard(
                    documentFolderCount: documentFolders.length,
                    totalDocumentCount: _documents.length,
                    unfiledDocumentCount: unfiledDocuments.length,
                    emptyFolderCount: emptyFolders.length,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _LibrarySearchField(
                    controller: _searchController,
                    isSearching: isSearching,
                    onChanged: (_) => setState(() {}),
                    onClear: _clearSearch,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ..._buildDesktopFolderPaneSections(
                    isSearching: isSearching,
                    documentFolders: documentFolders,
                    emptyFolders: emptyFolders,
                    matchingFolders: matchingFolders,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Scrollbar(
              controller: _desktopDocumentScrollController,
              child: ListView(
                controller: _desktopDocumentScrollController,
                padding: EdgeInsets.zero,
                children: _buildDesktopDocumentPaneSections(
                  isSearching: isSearching,
                  queryText: queryText,
                  matchingFolders: matchingFolders,
                  matchingDocuments: matchingDocuments,
                  unfiledDocuments: unfiledDocuments,
                  unfiledIds: unfiledIds,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDesktopFolderPaneSections({
    required bool isSearching,
    required List<DocumentFolderSummary> documentFolders,
    required List<DocumentFolderSummary> emptyFolders,
    required List<DocumentFolderSummary> matchingFolders,
  }) {
    if (isSearching) {
      if (matchingFolders.isEmpty) {
        return const [
          EmptyState(
            icon: Icons.folder_off_outlined,
            title: '没有匹配档案夹',
            message: '请调整关键词后重试。',
            compact: true,
          ),
        ];
      }

      return [
        const _SectionHeader(title: '匹配档案夹'),
        const SizedBox(height: AppSpacing.sm),
        ...matchingFolders.map((folder) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _GoalFolderCard(
              folder: folder,
              onTap: () => _openGoalFolder(folder.goalId),
            ),
          );
        }),
      ];
    }

    return [
      if (_documents.isEmpty)
        EmptyState(
          icon: Icons.folder_copy_outlined,
          title: '还没有文档',
          message:
              emptyFolders.isEmpty ? '新建文档，或从目标档案夹创建关联文档。' : '展开空档案夹可新建关联文档。',
          actionLabel: '新建文档',
          onAction: _openCreateDocument,
          compact: true,
        ),
      if (documentFolders.isNotEmpty) ...[
        const _SectionHeader(title: '目标档案夹'),
        const SizedBox(height: AppSpacing.sm),
        ...documentFolders.map((folder) {
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
      if (emptyFolders.isNotEmpty) ...[
        _EmptyFolderDisclosure(
          count: emptyFolders.length,
          expanded: _showEmptyFolders,
          onTap: () {
            setState(() {
              _showEmptyFolders = !_showEmptyFolders;
            });
          },
        ),
        if (_showEmptyFolders) ...[
          const SizedBox(height: AppSpacing.sm),
          ...emptyFolders.map((folder) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _GoalFolderCard(
                folder: folder,
                onTap: () => _openGoalFolder(folder.goalId),
              ),
            );
          }),
        ],
      ],
    ];
  }

  List<Widget> _buildDesktopDocumentPaneSections({
    required bool isSearching,
    required String queryText,
    required List<DocumentFolderSummary> matchingFolders,
    required List<EvolyDocument> matchingDocuments,
    required List<EvolyDocument> unfiledDocuments,
    required Set<String> unfiledIds,
  }) {
    if (isSearching) {
      final hasResults =
          matchingFolders.isNotEmpty || matchingDocuments.isNotEmpty;

      return [
        _SearchResultSummary(
          queryText: queryText,
          folderCount: matchingFolders.length,
          documentCount: matchingDocuments.length,
        ),
        const SizedBox(height: AppSpacing.md),
        if (!hasResults)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: '没有匹配内容',
            message: '请调整关键词后重试。',
            compact: true,
          )
        else if (matchingDocuments.isEmpty)
          const EmptyState(
            icon: Icons.article_outlined,
            title: '没有匹配文档',
            message: '左侧显示匹配档案夹。',
            compact: true,
          )
        else ...[
          const _SectionHeader(title: '匹配文档'),
          const SizedBox(height: AppSpacing.sm),
          ...matchingDocuments.map((document) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DocumentCard(
                document: document,
                isUnfiled: unfiledIds.contains(document.id),
                onTap: () => _openDocument(document.id),
              ),
            );
          }),
        ],
      ];
    }

    final visibleUnfiledDocuments = _showAllUnfiled
        ? unfiledDocuments
        : unfiledDocuments.take(_unfiledPreviewLimit).toList();
    final hiddenUnfiledCount =
        unfiledDocuments.length - visibleUnfiledDocuments.length;

    if (unfiledDocuments.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.inventory_2_outlined,
          title: '暂无未归档文档',
          message: '未关联目标的文档会显示在这里。',
          compact: true,
        ),
      ];
    }

    return [
      const _SectionHeader(
        title: '未归档',
        subtitle: '未关联目标的文档。',
      ),
      const SizedBox(height: AppSpacing.sm),
      ...visibleUnfiledDocuments.map((document) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _DocumentCard(
            document: document,
            isUnfiled: true,
            onTap: () => _openDocument(document.id),
          ),
        );
      }),
      if (unfiledDocuments.length > _unfiledPreviewLimit)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _showAllUnfiled = !_showAllUnfiled;
              });
            },
            icon: Icon(
              _showAllUnfiled
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            label: Text(
              _showAllUnfiled ? '收起未归档文档' : '显示剩余 $hiddenUnfiledCount 篇',
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildBrowseSections({
    required List<DocumentFolderSummary> documentFolders,
    required List<DocumentFolderSummary> emptyFolders,
    required List<EvolyDocument> unfiledDocuments,
  }) {
    final hasAnyDocuments = _documents.isNotEmpty;
    final visibleUnfiledDocuments = _showAllUnfiled
        ? unfiledDocuments
        : unfiledDocuments.take(_unfiledPreviewLimit).toList();
    final hiddenUnfiledCount =
        unfiledDocuments.length - visibleUnfiledDocuments.length;

    return [
      if (!hasAnyDocuments)
        EmptyState(
          icon: Icons.folder_copy_outlined,
          title: '还没有文档',
          message:
              emptyFolders.isEmpty ? '新建文档，或从目标档案夹创建关联文档。' : '展开空档案夹可新建关联文档。',
          actionLabel: '新建文档',
          onAction: _openCreateDocument,
          compact: true,
        ),
      if (documentFolders.isNotEmpty) ...[
        const _SectionHeader(
          title: '目标档案夹',
        ),
        const SizedBox(height: AppSpacing.sm),
        ...documentFolders.map((folder) {
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
      if (unfiledDocuments.isNotEmpty) ...[
        const _SectionHeader(
          title: '未归档',
          subtitle: '未关联目标的文档。',
        ),
        const SizedBox(height: AppSpacing.sm),
        ...visibleUnfiledDocuments.map((document) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _DocumentCard(
              document: document,
              isUnfiled: true,
              onTap: () => _openDocument(document.id),
            ),
          );
        }),
        if (unfiledDocuments.length > _unfiledPreviewLimit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllUnfiled = !_showAllUnfiled;
                });
              },
              icon: Icon(
                _showAllUnfiled
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
              ),
              label: Text(
                _showAllUnfiled ? '收起未归档文档' : '显示剩余 $hiddenUnfiledCount 篇',
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (emptyFolders.isNotEmpty) ...[
        _EmptyFolderDisclosure(
          count: emptyFolders.length,
          expanded: _showEmptyFolders,
          onTap: () {
            setState(() {
              _showEmptyFolders = !_showEmptyFolders;
            });
          },
        ),
        if (_showEmptyFolders) ...[
          const SizedBox(height: AppSpacing.sm),
          ...emptyFolders.map((folder) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _GoalFolderCard(
                folder: folder,
                onTap: () => _openGoalFolder(folder.goalId),
              ),
            );
          }),
        ],
      ],
    ];
  }

  List<Widget> _buildSearchSections({
    required String queryText,
    required List<DocumentFolderSummary> matchingFolders,
    required List<EvolyDocument> matchingDocuments,
    required Set<String> unfiledIds,
  }) {
    final hasResults =
        matchingFolders.isNotEmpty || matchingDocuments.isNotEmpty;

    return [
      _SearchResultSummary(
        queryText: queryText,
        folderCount: matchingFolders.length,
        documentCount: matchingDocuments.length,
      ),
      const SizedBox(height: AppSpacing.md),
      if (!hasResults)
        const EmptyState(
          icon: Icons.search_off_rounded,
          title: '没有匹配内容',
          message: '请调整关键词后重试。',
          compact: true,
        ),
      if (matchingFolders.isNotEmpty) ...[
        const _SectionHeader(
          title: '匹配档案夹',
        ),
        const SizedBox(height: AppSpacing.sm),
        ...matchingFolders.map((folder) {
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
      if (matchingDocuments.isNotEmpty) ...[
        const _SectionHeader(
          title: '匹配文档',
        ),
        const SizedBox(height: AppSpacing.sm),
        ...matchingDocuments.map((document) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _DocumentCard(
              document: document,
              isUnfiled: unfiledIds.contains(document.id),
              onTap: () => _openDocument(document.id),
            ),
          );
        }),
      ],
    ];
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
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
      final results = await Future.wait([
        repository.findGoalFolders(),
        repository.findAll(),
        repository.findUnfiled(),
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

class _LibrarySummaryCard extends StatelessWidget {
  const _LibrarySummaryCard({
    required this.documentFolderCount,
    required this.totalDocumentCount,
    required this.unfiledDocumentCount,
    required this.emptyFolderCount,
  });

  final int documentFolderCount;
  final int totalDocumentCount;
  final int unfiledDocumentCount;
  final int emptyFolderCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = EvolyDesignTokens.of(context);

    return AppSurfaceCard(
      margin: EdgeInsets.zero,
      elevated: true,
      backgroundColor: tokens.surfaceSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(
                icon: Icons.auto_stories_outlined,
                color: colorScheme.primary,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('文档概览', style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 4 : 2;
              final itemWidth =
                  (constraints.maxWidth - AppSpacing.md * (columns - 1)) /
                      columns;

              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '档案夹',
                      value: '$documentFolderCount',
                      icon: Icons.folder_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '文档',
                      value: '$totalDocumentCount',
                      icon: Icons.article_outlined,
                      color: colorScheme.secondary,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '未归档',
                      value: '$unfiledDocumentCount',
                      icon: Icons.inventory_2_outlined,
                      color: tokens.statusWarning,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetric(
                      label: '空目标',
                      value: '$emptyFolderCount',
                      icon: Icons.folder_off_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibrarySearchField extends StatelessWidget {
  const _LibrarySearchField({
    required this.controller,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: '搜索目标、标题、正文或类型',
        suffixIcon: isSearching
            ? IconButton(
                tooltip: '清空搜索',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
      ),
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }
}

class _SearchResultSummary extends StatelessWidget {
  const _SearchResultSummary({
    required this.queryText,
    required this.folderCount,
    required this.documentCount,
  });

  final String queryText;
  final int folderCount;
  final int documentCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.compact,
        ),
        child: Row(
          children: [
            Icon(Icons.manage_search_rounded, color: colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '“$queryText” 找到 $folderCount 个档案夹、$documentCount 篇文档',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFolderDisclosure extends StatelessWidget {
  const _EmptyFolderDisclosure({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurfaceCard(
      margin: EdgeInsets.zero,
      onTap: onTap,
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.34,
      ),
      child: Row(
        children: [
          _IconBadge(
            icon: Icons.folder_off_outlined,
            color: colorScheme.onSurfaceVariant,
            size: 44,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count 个空档案夹', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '展开查看无文档目标。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

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
    final tokens = EvolyDesignTokens.of(context);
    final progress = folder.goalProgress.clamp(0.0, 1.0).toDouble();
    final progressPercent = (progress * 100).round();
    final latestTitle = folder.latestDocumentTitle?.trim();
    final statusColor = _goalStatusColor(
      folder.goalStatus,
      theme.colorScheme,
      tokens,
    );

    return AppSurfaceCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(
                icon: folder.hasDocuments
                    ? Icons.folder_rounded
                    : Icons.create_new_folder_outlined,
                color: statusColor,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.goalTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppMetaPill(
                          label: _goalStatusLabel(folder.goalStatus),
                          icon: Icons.flag_outlined,
                          color: statusColor,
                          selected: true,
                        ),
                        AppMetaPill(
                          label: '$progressPercent%',
                          icon: Icons.timeline_rounded,
                        ),
                        AppMetaPill(
                          label: '${folder.documentCount} 篇',
                          icon: Icons.article_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: progress,
              color: statusColor,
              backgroundColor: statusColor.withValues(alpha: 0.14),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            latestTitle == null || latestTitle.isEmpty
                ? '暂无文档。'
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
    this.isUnfiled = false,
  });

  final EvolyDocument document;
  final VoidCallback onTap;
  final bool isUnfiled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = EvolyDesignTokens.of(context);
    final typeColor =
        _documentTypeColor(document.type, theme.colorScheme, tokens);

    return AppSurfaceCard(
      onTap: onTap,
      margin: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(
            icon: _documentTypeIcon(document.type),
            color: typeColor,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppMetaPill(
                      label: document.type.label,
                      icon: _documentTypeIcon(document.type),
                      color: typeColor,
                      selected: true,
                    ),
                    if (isUnfiled)
                      AppMetaPill(
                        label: '未归档',
                        icon: Icons.inventory_2_outlined,
                        color: tokens.statusWarning,
                        selected: true,
                      ),
                    AppMetaPill(
                      label: _formatDateTime(document.updatedAt),
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  document.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, color: color, size: size > 44 ? 24 : 22),
      ),
    );
  }
}

List<EvolyDocument> _uniqueDocuments(Iterable<EvolyDocument> documents) {
  final seenIds = <String>{};
  final uniqueDocuments = <EvolyDocument>[];

  for (final document in documents) {
    if (seenIds.add(document.id)) {
      uniqueDocuments.add(document);
    }
  }

  return uniqueDocuments;
}

bool _matchesFolder(DocumentFolderSummary folder, String query) {
  final latestTitle = folder.latestDocumentTitle?.toLowerCase() ?? '';
  return folder.goalTitle.toLowerCase().contains(query) ||
      latestTitle.contains(query) ||
      _goalStatusLabel(folder.goalStatus).toLowerCase().contains(query);
}

bool _matchesDocument(EvolyDocument document, String query) {
  return document.displayTitle.toLowerCase().contains(query) ||
      document.contentMarkdown.toLowerCase().contains(query) ||
      document.type.label.toLowerCase().contains(query);
}

IconData _documentTypeIcon(DocumentType type) {
  return switch (type) {
    DocumentType.projectNote => Icons.article_outlined,
    DocumentType.projectSummary => Icons.fact_check_outlined,
    DocumentType.review => Icons.rate_review_outlined,
    DocumentType.knowledge => Icons.auto_stories_outlined,
  };
}

Color _documentTypeColor(
  DocumentType type,
  ColorScheme colorScheme,
  EvolyDesignTokens tokens,
) {
  return switch (type) {
    DocumentType.projectNote => colorScheme.primary,
    DocumentType.projectSummary => tokens.statusSuccess,
    DocumentType.review => tokens.statusWarning,
    DocumentType.knowledge => colorScheme.tertiary,
  };
}

Color _goalStatusColor(
  GoalStatus status,
  ColorScheme colorScheme,
  EvolyDesignTokens tokens,
) {
  return switch (status) {
    GoalStatus.notStarted => colorScheme.onSurfaceVariant,
    GoalStatus.inProgress => colorScheme.primary,
    GoalStatus.completed => tokens.statusSuccess,
    GoalStatus.paused => tokens.statusWarning,
    GoalStatus.abandoned => colorScheme.error,
  };
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
