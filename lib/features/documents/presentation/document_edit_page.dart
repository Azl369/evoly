import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:evoly/app/router.dart';
import 'package:evoly_markdown_music_preview/evoly_markdown_music_preview.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/documents/presentation/markdown_math_support.dart';
import 'package:evoly/features/documents/presentation/markdown_music_safe_support.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/shared/ui/components/app_components.dart';
import 'package:evoly/shared/ui/tokens/app_spacing.dart';
import 'package:evoly/shared/widgets/empty_state.dart';

class DocumentEditPage extends StatefulWidget {
  const DocumentEditPage({
    this.documentId,
    this.initialLinkedGoalId,
    this.initialTitle,
    this.initialContentMarkdown,
    this.initialType = DocumentType.projectNote,
    super.key,
  });

  final String? documentId;
  final String? initialLinkedGoalId;
  final String? initialTitle;
  final String? initialContentMarkdown;
  final DocumentType initialType;

  @override
  State<DocumentEditPage> createState() => _DocumentEditPageState();
}

class _DocumentEditPageState extends State<DocumentEditPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();
  final _uuid = const Uuid();
  var _loading = true;
  var _saving = false;
  var _previewMode = false;
  var _dirty = false;
  var _type = DocumentType.projectNote;
  String? _documentId;
  DateTime? _createdAt;
  String? _errorMessage;
  final List<Goal> _goals = [];
  final Set<String> _linkedGoalIds = {};

  @override
  void initState() {
    super.initState();
    _documentId = widget.documentId;
    _type = widget.initialType;
    final initialTitle = widget.initialTitle;
    if (initialTitle != null) {
      _titleController.text = initialTitle;
    }
    final initialContentMarkdown = widget.initialContentMarkdown;
    if (initialContentMarkdown != null) {
      _contentController.text = initialContentMarkdown;
    }
    _titleController.addListener(_markDirty);
    _contentController.addListener(_markDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocument());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }

        final shouldDiscard = await _confirmDiscardChanges();
        if (shouldDiscard && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_documentId == null ? '新建文档' : '编辑文档'),
          actions: [
            IconButton(
              tooltip: _previewMode ? '编辑' : '预览',
              onPressed: _loading
                  ? null
                  : () => setState(() => _previewMode = !_previewMode),
              icon: Icon(
                _previewMode
                    ? Icons.edit_note_rounded
                    : Icons.visibility_outlined,
              ),
            ),
            TextButton(
              onPressed: _saving || _loading ? null : _saveDocument,
              child: Text(_saving ? '保存中' : '保存'),
            ),
            PopupMenuButton<_DocumentEditAction>(
              onSelected: (action) {
                if (action == _DocumentEditAction.delete) {
                  _deleteDocument();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _DocumentEditAction.delete,
                  child: Text('删除文档'),
                ),
              ],
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(label: '正在打开文档');
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: '文档打开失败',
        message: errorMessage,
      );
    }

    if (_previewMode) {
      return _DocumentPreview(
        title: _titleController.text,
        contentMarkdown: _contentController.text,
        type: _type,
        onTap: () => setState(() => _previewMode = false),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '例如：Android 通知适配复盘',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<DocumentType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '文档类型'),
              items: DocumentType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                );
              }).toList(),
              onChanged: (type) {
                if (type == null) {
                  return;
                }
                setState(() {
                  _type = type;
                  _dirty = true;
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _LinkedGoalsSection(
              goals: _goals,
              linkedGoalIds: _linkedGoalIds,
              onManage: _showGoalLinkDialog,
              onOpenGoal: _openLinkedGoal,
            ),
            const SizedBox(height: AppSpacing.md),
            _DocumentEditorToolbar(
              onInsertMusicBlock: _insertMusicBlockTemplate,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.46,
                    ),
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadDocument() async {
    final goalRepository = context.read<GoalRepository>();
    final documentId = _documentId;
    if (documentId == null) {
      final goals = await goalRepository.findAll();
      if (!mounted) {
        return;
      }

      setState(() {
        final initialLinkedGoalId = widget.initialLinkedGoalId;
        if (initialLinkedGoalId != null) {
          _linkedGoalIds.add(initialLinkedGoalId);
        }
        _goals
          ..clear()
          ..addAll(goals);
        _loading = false;
      });
      return;
    }

    try {
      final documentRepository = context.read<DocumentRepository>();
      final results = await Future.wait([
        documentRepository.findById(documentId),
        documentRepository.findLinkedGoalIds(documentId),
        goalRepository.findAll(),
      ]);
      if (!mounted) {
        return;
      }

      final document = results[0] as EvolyDocument?;
      if (document == null) {
        setState(() {
          _errorMessage = '没有找到这篇文档，可能已经被删除。';
          _loading = false;
        });
        return;
      }

      _titleController.text = document.title;
      _contentController.text = document.contentMarkdown;
      setState(() {
        _type = document.type;
        _createdAt = document.createdAt;
        _linkedGoalIds
          ..clear()
          ..addAll(results[1] as List<String>);
        _goals
          ..clear()
          ..addAll(results[2] as List<Goal>);
        _dirty = false;
        _previewMode = true;
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

  Future<void> _saveDocument() async {
    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      final documentId = _documentId ?? 'document-${_uuid.v4()}';
      final createdAt = _createdAt ?? now;
      final title = _titleController.text.trim();
      final document = EvolyDocument(
        id: documentId,
        title: title.isEmpty ? '未命名文档' : title,
        contentMarkdown: _contentController.text,
        type: _type,
        createdAt: createdAt,
        updatedAt: now,
      );

      final repository = context.read<DocumentRepository>();
      await repository.save(document);
      await repository.replaceLinkedGoals(documentId, _linkedGoalIds.toList());

      if (!mounted) {
        return;
      }

      setState(() {
        _documentId = documentId;
        _createdAt = createdAt;
        _dirty = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文档已保存')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    }
  }

  Future<void> _deleteDocument() async {
    final documentId = _documentId;
    if (documentId == null) {
      Navigator.pop(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除文档？'),
          content: const Text('删除后不会再出现在文档库里。'),
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

    if (confirmed != true || !mounted) {
      return;
    }

    await context.read<DocumentRepository>().delete(documentId);

    if (!mounted) {
      return;
    }

    _dirty = false;
    Navigator.pop(context);
  }

  Future<void> _showGoalLinkDialog() async {
    final selectedGoalIds = Set<String>.of(_linkedGoalIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('关联目标'),
              content: SizedBox(
                width: 420,
                child: _goals.isEmpty
                    ? const Text('还没有可关联的目标。')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _goals.length,
                        itemBuilder: (context, index) {
                          final goal = _goals[index];
                          final selected = selectedGoalIds.contains(goal.id);

                          return CheckboxListTile(
                            value: selected,
                            title: Text(goal.title),
                            subtitle: Text(goal.status.label),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selectedGoalIds.add(goal.id);
                                } else {
                                  selectedGoalIds.remove(goal.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selectedGoalIds),
                  child: const Text('保存关联'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _linkedGoalIds
        ..clear()
        ..addAll(result);
      _dirty = true;
    });
  }

  Future<void> _openLinkedGoal(Goal goal) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.goalDetail,
      arguments: goal.id,
    );

    if (mounted) {
      await _reloadGoals();
    }
  }

  Future<void> _reloadGoals() async {
    final goals = await context.read<GoalRepository>().findAll();
    if (!mounted) {
      return;
    }

    setState(() {
      _goals
        ..clear()
        ..addAll(goals);
    });
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_dirty) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('放弃未保存修改？'),
          content: const Text('当前文档还有未保存内容，离开后会丢失。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  void _markDirty() {
    if (_loading || _dirty) {
      return;
    }

    setState(() => _dirty = true);
  }

  void _insertMusicBlockTemplate(MarkdownMusicBlockTemplate template) {
    final currentText = _contentController.text;
    final selection = _normalizedContentSelection(currentText);
    final insertion = _formatMarkdownBlockInsertion(
      currentText: currentText,
      selection: selection,
      block: template.fencedSource,
    );
    final nextText = currentText.replaceRange(
      selection.start,
      selection.end,
      insertion,
    );
    final cursorOffset = selection.start + insertion.length;

    _contentController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursorOffset),
      composing: TextRange.empty,
    );
    _contentFocusNode.requestFocus();
  }

  TextSelection _normalizedContentSelection(String text) {
    final selection = _contentController.selection;
    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      return TextSelection.collapsed(offset: text.length);
    }

    var start = selection.start;
    var end = selection.end;
    if (start > text.length) {
      start = text.length;
    }
    if (end > text.length) {
      end = text.length;
    }
    if (start > end) {
      final originalStart = start;
      start = end;
      end = originalStart;
    }

    return TextSelection(baseOffset: start, extentOffset: end);
  }

  String _formatMarkdownBlockInsertion({
    required String currentText,
    required TextSelection selection,
    required String block,
  }) {
    final before = currentText.substring(0, selection.start);
    final after = currentText.substring(selection.end);
    var insertion = block.trimRight();

    if (before.isNotEmpty && !before.endsWith('\n\n')) {
      if (before.endsWith('\n')) {
        insertion = '\n$insertion';
      } else {
        insertion = '\n\n$insertion';
      }
    }

    if (after.isNotEmpty && !after.startsWith('\n\n')) {
      if (after.startsWith('\n')) {
        insertion = '$insertion\n';
      } else {
        insertion = '$insertion\n\n';
      }
    }

    return insertion;
  }
}

class DocumentEditArguments {
  const DocumentEditArguments({
    this.documentId,
    this.initialLinkedGoalId,
    this.initialTitle,
    this.initialContentMarkdown,
    this.initialType = DocumentType.projectNote,
  });

  final String? documentId;
  final String? initialLinkedGoalId;
  final String? initialTitle;
  final String? initialContentMarkdown;
  final DocumentType initialType;
}

class _DocumentEditorToolbar extends StatelessWidget {
  const _DocumentEditorToolbar({
    required this.onInsertMusicBlock,
  });

  final ValueChanged<MarkdownMusicBlockTemplate> onInsertMusicBlock;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<MarkdownMusicBlockTemplate>(
        tooltip: '插入音乐谱块',
        icon: const Icon(Icons.library_music_outlined),
        onSelected: onInsertMusicBlock,
        itemBuilder: (context) {
          return [
            for (final template in MarkdownMusicTemplates.all)
              PopupMenuItem(
                value: template,
                child: _MusicTemplateMenuItem(template: template),
              ),
          ];
        },
      ),
    );
  }
}

class _MusicTemplateMenuItem extends StatelessWidget {
  const _MusicTemplateMenuItem({required this.template});

  final MarkdownMusicBlockTemplate template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          _templateIcon(template.kind),
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(template.label, style: theme.textTheme.bodyMedium),
              Text(
                template.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _templateIcon(MarkdownMusicTemplateKind kind) {
    return switch (kind) {
      MarkdownMusicTemplateKind.chordpro => Icons.queue_music_rounded,
      MarkdownMusicTemplateKind.tab => Icons.view_week_rounded,
      MarkdownMusicTemplateKind.abc => Icons.music_note_rounded,
    };
  }
}

class _LinkedGoalsSection extends StatelessWidget {
  const _LinkedGoalsSection({
    required this.goals,
    required this.linkedGoalIds,
    required this.onManage,
    required this.onOpenGoal,
  });

  final List<Goal> goals;
  final Set<String> linkedGoalIds;
  final VoidCallback onManage;
  final ValueChanged<Goal> onOpenGoal;

  @override
  Widget build(BuildContext context) {
    final linkedGoals = goals
        .where((goal) => linkedGoalIds.contains(goal.id))
        .toList()
      ..sort((left, right) => left.title.compareTo(right.title));

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('关联目标', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: onManage,
                icon: const Icon(Icons.add_link_rounded),
                label: Text(linkedGoals.isEmpty ? '选择目标' : '管理'),
              ),
            ],
          ),
          if (linkedGoals.isEmpty)
            Text(
              '未关联目标。关联后，可在目标详情页看到这篇文档。',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: linkedGoals.map((goal) {
                return ActionChip(
                  avatar: const Icon(Icons.flag_outlined, size: 16),
                  label: Text(goal.title),
                  onPressed: () => onOpenGoal(goal),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({
    required this.title,
    required this.contentMarkdown,
    required this.type,
    required this.onTap,
  });

  final String title;
  final String contentMarkdown;
  final DocumentType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayTitle = title.trim().isEmpty ? '未命名文档' : title.trim();
    final content =
        contentMarkdown.trim().isEmpty ? '_暂无正文。_' : contentMarkdown;
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.65);
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.55,
    );

    return SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: Markdown(
          padding: const EdgeInsets.all(AppSpacing.md),
          data: '# $displayTitle\n\n> ${type.label}\n\n$content',
          blockSyntaxes: [
            ...MarkdownMathSupport.blockSyntaxes,
            ...SafeMarkdownMusicSupport.blockSyntaxes(),
          ],
          inlineSyntaxes: MarkdownMathSupport.inlineSyntaxes(),
          builders: {
            ...MarkdownMathSupport.builders(),
            ...SafeMarkdownMusicSupport.builders(),
          },
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            h1: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.22,
            ),
            h2: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
            h3: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            p: bodyStyle,
            listBullet: bodyStyle,
            blockquote: mutedStyle,
            blockquotePadding: const EdgeInsets.only(
              left: AppSpacing.md,
              top: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
            code: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'Consolas',
              fontFamilyFallback: const [
                'Microsoft YaHei UI',
                'Microsoft YaHei',
                'Noto Sans CJK SC',
                'Arial',
              ],
              color: theme.colorScheme.onSecondaryContainer,
              backgroundColor: theme.colorScheme.secondaryContainer,
            ),
            codeblockDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DocumentEditAction {
  delete,
}
