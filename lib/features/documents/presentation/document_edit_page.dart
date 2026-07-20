import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
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
  final _editorScrollController = ScrollController();
  final _previewScrollController = ScrollController();
  final _contentFocusNode = FocusNode();
  final _uuid = const Uuid();
  var _loading = true;
  var _saving = false;
  var _viewMode = _DocumentViewMode.edit;
  var _compactMarkdownEditing = false;
  var _syncingScroll = false;
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
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _viewMode = _DocumentViewMode.splitPreview;
    }
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
    _contentController.addListener(_syncPreviewScrollAfterLayout);
    _editorScrollController.addListener(_syncPreviewScrollFromEditor);
    _previewScrollController.addListener(_syncEditorScrollFromPreview);
    _contentFocusNode.addListener(_handleContentFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocument());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.removeListener(_syncPreviewScrollAfterLayout);
    _contentController.dispose();
    _editorScrollController.removeListener(_syncPreviewScrollFromEditor);
    _previewScrollController.removeListener(_syncEditorScrollFromPreview);
    _editorScrollController.dispose();
    _previewScrollController.dispose();
    _contentFocusNode.removeListener(_handleContentFocusChanged);
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          _saveDocument();
        },
      },
      child: PopScope(
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
          resizeToAvoidBottomInset:
              defaultTargetPlatform == TargetPlatform.android ? false : true,
          appBar: AppBar(
            title: Text(_documentId == null ? '新建文档' : '编辑文档'),
            actions: [
              IconButton(
                tooltip: _viewMode == _DocumentViewMode.preview ? '编辑' : '预览',
                onPressed: _loading
                    ? null
                    : () {
                        final nextMode = _viewMode == _DocumentViewMode.preview
                            ? _DocumentViewMode.edit
                            : _DocumentViewMode.preview;
                        _changeViewMode(nextMode);
                      },
                icon: Icon(
                  _viewMode == _DocumentViewMode.preview
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

    final viewMode = _effectiveViewMode(context);

    if (viewMode == _DocumentViewMode.preview) {
      return _DocumentPreview(
        title: _titleController.text,
        contentMarkdown: _contentController.text,
        type: _type,
        onEditCustomChord: _showEditCustomChordDialog,
        onTap: () => _changeViewMode(_DocumentViewMode.edit),
      );
    }

    final supportsSplitPreview = _supportsSplitPreview(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _DocumentEditMetadata(
              visible: !_compactMarkdownEditing,
              titleController: _titleController,
              type: _type,
              goals: _goals,
              linkedGoalIds: _linkedGoalIds,
              onTypeChanged: _changeDocumentType,
              onManageLinkedGoals: _showGoalLinkDialog,
              onOpenLinkedGoal: _openLinkedGoal,
            ),
            _DocumentEditorToolbar(
              viewMode: viewMode,
              supportsSplitPreview: supportsSplitPreview,
              onViewModeChanged: _changeViewMode,
              onInsertMusicBlock: _insertMusicBlockTemplate,
              onInsertCustomChord: _showCustomChordDialog,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: viewMode == _DocumentViewMode.splitPreview
                  ? _buildSplitMarkdownWorkspace(context)
                  : _buildMarkdownEditor(context),
            ),
            if (defaultTargetPlatform == TargetPlatform.android)
              const _AndroidKeyboardInsetSpacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitMarkdownWorkspace(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildMarkdownEditor(context)),
        const VerticalDivider(width: AppSpacing.lg),
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _titleController,
              _contentController,
            ]),
            builder: (context, _) {
              return _DocumentPreview(
                scrollController: _previewScrollController,
                title: _titleController.text,
                contentMarkdown: _contentController.text,
                type: _type,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                contentAlignment: Alignment.topCenter,
                maxContentWidth: 620,
                showDocumentHeader: false,
                safeArea: false,
                onEditCustomChord: _showEditCustomChordDialog,
                onTap: null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMarkdownEditor(BuildContext context) {
    return RepaintBoundary(
      child: TextField(
        key: const ValueKey('document-markdown-editor'),
        controller: _contentController,
        scrollController: _editorScrollController,
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
    );
  }

  _DocumentViewMode _effectiveViewMode(BuildContext context) {
    if (_viewMode == _DocumentViewMode.splitPreview &&
        !_supportsSplitPreview(context)) {
      return _DocumentViewMode.edit;
    }

    return _viewMode;
  }

  bool _supportsSplitPreview(BuildContext context) {
    return defaultTargetPlatform == TargetPlatform.windows &&
        MediaQuery.sizeOf(context).width >= 840;
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
        _viewMode = _DocumentViewMode.preview;
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
    if (_saving || _loading) {
      return;
    }

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
              title: const Text('关联项目'),
              content: SizedBox(
                width: 420,
                child: _goals.isEmpty
                    ? const Text('还没有可关联的项目。')
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

  void _changeDocumentType(DocumentType type) {
    setState(() {
      _type = type;
      _dirty = true;
    });
  }

  void _changeViewMode(_DocumentViewMode viewMode) {
    setState(() => _viewMode = viewMode);
    if (viewMode == _DocumentViewMode.splitPreview) {
      _syncPreviewScrollAfterLayout();
    }
  }

  void _syncPreviewScrollAfterLayout() {
    if (_viewMode != _DocumentViewMode.splitPreview) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _viewMode != _DocumentViewMode.splitPreview) {
        return;
      }
      _syncScrollByRatio(_editorScrollController, _previewScrollController);
    });
  }

  void _syncPreviewScrollFromEditor() {
    _syncScrollByRatio(_editorScrollController, _previewScrollController);
  }

  void _syncEditorScrollFromPreview() {
    _syncScrollByRatio(_previewScrollController, _editorScrollController);
  }

  void _syncScrollByRatio(
    ScrollController sourceController,
    ScrollController targetController,
  ) {
    if (_syncingScroll || _viewMode != _DocumentViewMode.splitPreview) {
      return;
    }
    if (!sourceController.hasClients || !targetController.hasClients) {
      return;
    }

    final sourcePosition = sourceController.position;
    final targetPosition = targetController.position;
    final sourceMax = sourcePosition.maxScrollExtent;
    final targetMax = targetPosition.maxScrollExtent;
    final ratio = sourceMax <= 0 ? 0.0 : sourcePosition.pixels / sourceMax;
    final targetOffset = (targetMax * ratio.clamp(0.0, 1.0))
        .clamp(
          targetPosition.minScrollExtent,
          targetMax,
        )
        .toDouble();

    if ((targetPosition.pixels - targetOffset).abs() < 1) {
      return;
    }

    _syncingScroll = true;
    try {
      targetController.jumpTo(targetOffset);
    } finally {
      _syncingScroll = false;
    }
  }

  void _handleContentFocusChanged() {
    if (!mounted) {
      return;
    }

    final compactMarkdownEditing =
        defaultTargetPlatform == TargetPlatform.android &&
            _contentFocusNode.hasFocus;
    if (_compactMarkdownEditing != compactMarkdownEditing) {
      setState(() => _compactMarkdownEditing = compactMarkdownEditing);
    }
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

  Future<void> _showCustomChordDialog() async {
    final definition = await showDialog<_CustomChordDefinition>(
      context: context,
      builder: (context) => const _CustomChordDialog(),
    );

    if (definition == null || !mounted) {
      return;
    }

    _insertCustomChordDefinition(definition);
  }

  Future<void> _showEditCustomChordDialog(String _, ChordShape shape) async {
    final initialDefinition = _CustomChordDefinition.fromShape(shape);
    final definition = await showDialog<_CustomChordDefinition>(
      context: context,
      builder: (context) => _CustomChordDialog(
        initialDefinition: initialDefinition,
      ),
    );

    if (definition == null || !mounted) {
      return;
    }

    _replaceCustomChordDefinition(
      originalName: initialDefinition.name,
      definition: definition,
    );
  }

  void _insertCustomChordDefinition(_CustomChordDefinition definition) {
    final currentText = _contentController.text;
    final selection = _normalizedContentSelection(currentText);
    final directive = definition.toChordProDirective();
    final chordProFence = _findChordProFenceForInsertion(
      currentText,
      selection.start,
    );

    late final String nextText;
    late final int cursorOffset;

    if (chordProFence != null) {
      final insertOffset = _definitionInsertOffset(currentText, chordProFence);
      final insertion = '$directive\n';
      nextText =
          currentText.replaceRange(insertOffset, insertOffset, insertion);
      cursorOffset = insertOffset + insertion.length;
    } else {
      final block = '''
```chordpro
$directive

[${definition.name}] 
```''';
      final insertion = _formatMarkdownBlockInsertion(
        currentText: currentText,
        selection: selection,
        block: block,
      );
      nextText = currentText.replaceRange(
        selection.start,
        selection.end,
        insertion,
      );
      cursorOffset = selection.start + insertion.length;
    }

    _contentController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursorOffset),
      composing: TextRange.empty,
    );
    _contentFocusNode.requestFocus();
  }

  void _replaceCustomChordDefinition({
    required String originalName,
    required _CustomChordDefinition definition,
  }) {
    final currentText = _contentController.text;
    final directive = definition.toChordProDirective();
    final targetName = normalizeChordName(originalName) ?? originalName;

    for (final fence in _collectChordProFences(currentText)) {
      var lineStart = fence.contentStart;
      while (lineStart < fence.contentEnd) {
        final newlineIndex = currentText.indexOf('\n', lineStart);
        final lineContentEnd =
            newlineIndex == -1 || newlineIndex > fence.contentEnd
                ? fence.contentEnd
                : newlineIndex;
        final lineEnd = newlineIndex == -1 ? lineContentEnd : newlineIndex + 1;
        final line = currentText.substring(lineStart, lineContentEnd);
        final match = _chordProDefineLinePattern.firstMatch(line.trim());

        if (match != null) {
          final definedName = match[1]!.trim();
          final normalizedDefinedName =
              normalizeChordName(definedName) ?? definedName;
          if (normalizedDefinedName == targetName) {
            var nextText = currentText.replaceRange(
              lineStart,
              lineContentEnd,
              directive,
            );

            if (definition.name != originalName) {
              final delta = directive.length - (lineContentEnd - lineStart);
              final updatedContentEnd = fence.contentEnd + delta;
              final block = nextText.substring(
                fence.contentStart,
                updatedContentEnd,
              );
              final renamedBlock = block.replaceAll(
                '[${originalName.trim()}]',
                '[${definition.name}]',
              );
              nextText = nextText.replaceRange(
                fence.contentStart,
                updatedContentEnd,
                renamedBlock,
              );
            }

            _contentController.value = TextEditingValue(
              text: nextText,
              selection: TextSelection.collapsed(
                offset: lineStart + directive.length,
              ),
              composing: TextRange.empty,
            );
            return;
          }
        }

        lineStart = lineEnd;
      }
    }

    _insertCustomChordDefinition(definition);
  }

  _ChordProFence? _findChordProFenceForInsertion(String text, int offset) {
    final fences = _collectChordProFences(text);
    if (fences.isEmpty) {
      return null;
    }

    for (final fence in fences) {
      if (offset >= fence.openingStart && offset <= fence.closingEnd) {
        return fence;
      }
    }

    return fences.length == 1 ? fences.single : null;
  }

  List<_ChordProFence> _collectChordProFences(String text) {
    final fences = <_ChordProFence>[];
    String? activeFence;
    var activeIsChordPro = false;
    var openingStart = 0;
    var contentStart = 0;

    var lineStart = 0;
    while (lineStart <= text.length) {
      final newlineIndex = text.indexOf('\n', lineStart);
      final lineContentEnd = newlineIndex == -1 ? text.length : newlineIndex;
      final lineEnd = newlineIndex == -1 ? text.length : newlineIndex + 1;
      final line = text.substring(lineStart, lineContentEnd);

      if (activeFence != null) {
        if (_isClosingFence(line, activeFence)) {
          if (activeIsChordPro) {
            fences.add(
              _ChordProFence(
                openingStart: openingStart,
                contentStart: contentStart,
                contentEnd: lineStart,
                closingEnd: lineEnd,
              ),
            );
          }
          activeFence = null;
          activeIsChordPro = false;
        }
      } else {
        final openingMatch = _markdownFenceOpeningPattern.firstMatch(line);
        if (openingMatch != null) {
          activeFence = openingMatch[1]!;
          final language = openingMatch[2]!.toLowerCase();
          activeIsChordPro = _chordProFenceLanguages.contains(language);
          openingStart = lineStart;
          contentStart = lineEnd;
        }
      }

      if (lineEnd == text.length) {
        break;
      }
      lineStart = lineEnd;
    }

    if (activeFence != null && activeIsChordPro) {
      fences.add(
        _ChordProFence(
          openingStart: openingStart,
          contentStart: contentStart,
          contentEnd: text.length,
          closingEnd: text.length,
        ),
      );
    }

    return fences;
  }

  bool _isClosingFence(String line, String fence) {
    final trimmed = line.trim();
    if (trimmed.length < fence.length) {
      return false;
    }

    final fenceChar = fence.codeUnitAt(0);
    for (final codeUnit in trimmed.codeUnits) {
      if (codeUnit != fenceChar) {
        return false;
      }
    }
    return true;
  }

  int _definitionInsertOffset(String text, _ChordProFence fence) {
    var offset = fence.contentStart;
    while (offset < fence.contentEnd) {
      final newlineIndex = text.indexOf('\n', offset);
      final lineContentEnd =
          newlineIndex == -1 || newlineIndex > fence.contentEnd
              ? fence.contentEnd
              : newlineIndex;
      final lineEnd = newlineIndex == -1 ? lineContentEnd : newlineIndex + 1;
      final trimmedLine = text.substring(offset, lineContentEnd).trim();

      if (trimmedLine.isEmpty ||
          !_chordProDirectiveLinePattern.hasMatch(trimmedLine)) {
        break;
      }

      offset = lineEnd;
    }

    return offset;
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

class _DocumentEditMetadata extends StatelessWidget {
  const _DocumentEditMetadata({
    required this.visible,
    required this.titleController,
    required this.type,
    required this.goals,
    required this.linkedGoalIds,
    required this.onTypeChanged,
    required this.onManageLinkedGoals,
    required this.onOpenLinkedGoal,
  });

  final bool visible;
  final TextEditingController titleController;
  final DocumentType type;
  final List<Goal> goals;
  final Set<String> linkedGoalIds;
  final ValueChanged<DocumentType> onTypeChanged;
  final VoidCallback onManageLinkedGoals;
  final ValueChanged<Goal> onOpenLinkedGoal;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      maintainState: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '例如：Android 通知适配复盘',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<DocumentType>(
              initialValue: type,
              decoration: const InputDecoration(labelText: '文档类型'),
              items: DocumentType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                );
              }).toList(),
              onChanged: (type) {
                if (type != null) {
                  onTypeChanged(type);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _LinkedGoalsSection(
              goals: goals,
              linkedGoalIds: linkedGoalIds,
              onManage: onManageLinkedGoals,
              onOpenGoal: onOpenLinkedGoal,
            ),
          ],
        ),
      ),
    );
  }
}

class _AndroidKeyboardInsetSpacer extends StatelessWidget {
  const _AndroidKeyboardInsetSpacer();

  @override
  Widget build(BuildContext context) {
    return _SettledKeyboardInsetSpacer(
      inset: MediaQuery.viewInsetsOf(context).bottom,
    );
  }
}

class _SettledKeyboardInsetSpacer extends StatefulWidget {
  const _SettledKeyboardInsetSpacer({
    required this.inset,
  });

  final double inset;

  @override
  State<_SettledKeyboardInsetSpacer> createState() =>
      _SettledKeyboardInsetSpacerState();
}

class _SettledKeyboardInsetSpacerState
    extends State<_SettledKeyboardInsetSpacer> {
  static const _settleDelay = Duration(milliseconds: 90);

  Timer? _settleTimer;
  double _settledInset = 0;
  double _pendingInset = 0;

  @override
  void initState() {
    super.initState();
    _pendingInset = widget.inset;
    _settledInset = widget.inset;
  }

  @override
  void didUpdateWidget(_SettledKeyboardInsetSpacer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inset == widget.inset) {
      return;
    }

    _pendingInset = widget.inset;
    _settleTimer?.cancel();
    if (widget.inset == 0) {
      if (_settledInset != 0) {
        setState(() => _settledInset = 0);
      }
      return;
    }

    _settleTimer = Timer(_settleDelay, () {
      if (!mounted || _settledInset == _pendingInset) {
        return;
      }
      setState(() => _settledInset = _pendingInset);
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: _settledInset);
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
    required this.viewMode,
    required this.supportsSplitPreview,
    required this.onViewModeChanged,
    required this.onInsertMusicBlock,
    required this.onInsertCustomChord,
  });

  final _DocumentViewMode viewMode;
  final bool supportsSplitPreview;
  final ValueChanged<_DocumentViewMode> onViewModeChanged;
  final ValueChanged<MarkdownMusicBlockTemplate> onInsertMusicBlock;
  final VoidCallback onInsertCustomChord;

  @override
  Widget build(BuildContext context) {
    final showModeSelector = defaultTargetPlatform == TargetPlatform.windows;
    final selectedViewMode =
        viewMode == _DocumentViewMode.splitPreview && !supportsSplitPreview
            ? _DocumentViewMode.edit
            : viewMode;

    return SizedBox(
      width: double.infinity,
      height: AppSpacing.minTouchTarget,
      child: Stack(
        children: [
          if (showModeSelector)
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_DocumentViewMode>(
                  showSelectedIcon: false,
                  selected: {selectedViewMode},
                  onSelectionChanged: (selection) {
                    onViewModeChanged(selection.first);
                  },
                  segments: [
                    const ButtonSegment(
                      value: _DocumentViewMode.edit,
                      icon: Icon(Icons.edit_note_rounded),
                      label: Text('编辑'),
                    ),
                    if (supportsSplitPreview)
                      const ButtonSegment(
                        value: _DocumentViewMode.splitPreview,
                        icon: Icon(Icons.splitscreen_rounded),
                        label: Text('分屏'),
                      ),
                    const ButtonSegment(
                      value: _DocumentViewMode.preview,
                      icon: Icon(Icons.visibility_outlined),
                      label: Text('预览'),
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('document-custom-chord-button'),
                  tooltip: '自定义和弦',
                  onPressed: onInsertCustomChord,
                  icon: const Icon(Icons.grid_view_rounded),
                ),
                PopupMenuButton<MarkdownMusicBlockTemplate>(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomChordDefinition {
  const _CustomChordDefinition({
    required this.name,
    required this.baseFret,
    required this.frets,
    required this.fingers,
  });

  factory _CustomChordDefinition.fromShape(ChordShape shape) {
    final fingers = shape.fingers;
    return _CustomChordDefinition(
      name: shape.name,
      baseFret: shape.baseFret,
      frets: List.unmodifiable([
        for (var index = 0; index < 6; index++)
          index < shape.frets.length ? shape.frets[index] : -1,
      ]),
      fingers: List.unmodifiable([
        for (var index = 0; index < 6; index++)
          fingers != null && index < fingers.length ? fingers[index] : 0,
      ]),
    );
  }

  final String name;
  final int baseFret;
  final List<int> frets;
  final List<int> fingers;

  String toChordProDirective() {
    final fretTokens = <String>[
      for (final fret in frets) _fretToken(fret),
    ];
    final fingerTokens = <String>[
      for (var index = 0; index < fingers.length; index++)
        frets[index] < 0 ? 'x' : '${fingers[index]}',
    ];

    return '{define: $name base-fret $baseFret frets '
        '${fretTokens.join(' ')} fingers ${fingerTokens.join(' ')}}';
  }

  String _fretToken(int fret) {
    if (fret < 0) {
      return 'x';
    }
    if (fret == 0) {
      return '0';
    }
    return '${fret - baseFret + 1}';
  }
}

class _CustomChordDialog extends StatefulWidget {
  const _CustomChordDialog({this.initialDefinition});

  final _CustomChordDefinition? initialDefinition;

  @override
  State<_CustomChordDialog> createState() => _CustomChordDialogState();
}

class _CustomChordDialogState extends State<_CustomChordDialog> {
  static const _stringLabels = ['E', 'A', 'D', 'G', 'B', 'e'];
  static const _fingerOptions = [0, 1, 2, 3, 4];
  static const _choiceCellWidth = 44.0;

  final _nameController = TextEditingController();
  var _baseFret = 1;
  var _frets = List<int>.filled(6, -1);
  final _fingers = List<int>.filled(6, 0);
  String? _inferredName;
  var _nameEdited = false;

  @override
  void initState() {
    super.initState();
    final initialDefinition = widget.initialDefinition;
    if (initialDefinition != null) {
      _baseFret = initialDefinition.baseFret;
      _frets = List<int>.of(initialDefinition.frets);
      for (var index = 0; index < _fingers.length; index++) {
        _fingers[index] = index < initialDefinition.fingers.length
            ? initialDefinition.fingers[index]
            : 0;
      }
      _nameController.text = initialDefinition.name;
      _nameEdited = true;
    }
    _updateInferredName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return AlertDialog(
      key: const ValueKey('custom-chord-dialog'),
      title: Text(_isEditing ? '编辑自定义和弦' : '自定义和弦'),
      content: SizedBox(
        width: 620,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildNameAndBaseControls(theme)),
                    const SizedBox(width: AppSpacing.md),
                    _buildPreview(theme),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('按弦', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                _buildFretGrid(theme),
                const SizedBox(height: AppSpacing.md),
                Text('指法', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                for (var index = 0; index < _stringLabels.length; index++)
                  _buildFingerRow(context, index),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('custom-chord-submit'),
          onPressed: _canSubmit ? _submit : null,
          child: Text(_isEditing ? '更新' : '插入'),
        ),
      ],
    );
  }

  bool get _isEditing => widget.initialDefinition != null;

  Widget _buildNameAndBaseControls(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('和弦名', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: const ValueKey('custom-chord-name-field'),
          controller: _nameController,
          maxLines: 1,
          decoration: const InputDecoration(
            hintText: '自动推算，可手动修改',
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
          ),
          onChanged: (_) => setState(() => _nameEdited = true),
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildInferenceSummary(theme),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text('把位', style: theme.textTheme.labelLarge),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              key: const ValueKey('custom-chord-base-decrease'),
              tooltip: '降低把位',
              onPressed:
                  _baseFret <= 1 ? null : () => _setBaseFret(_baseFret - 1),
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 64,
              child: Center(
                child: Text(
                  '$_baseFret',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('custom-chord-base-increase'),
              tooltip: '提高把位',
              onPressed:
                  _baseFret >= 20 ? null : () => _setBaseFret(_baseFret + 1),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInferenceSummary(ThemeData theme) {
    final soundingNotes = chordPitchNamesFromFrets(_frets);
    if (soundingNotes.isEmpty) {
      return Text(
        '选择按弦后显示推断依据',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final inferredName = _inferredName;
    final chordTones =
        inferredName == null ? const <String>[] : chordToneNames(inferredName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '按弦产生 ${soundingNotes.join(' · ')}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (inferredName != null)
          Text(
            chordTones.isEmpty
                ? '推断 $inferredName'
                : '$inferredName 组成音 ${chordTones.join(' · ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final displayName = _nameController.text.trim().isEmpty
        ? (_inferredName ?? 'Chord')
        : _nameController.text.trim();

    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ChordDiagramView(
        chord: displayName,
        shape: ChordShape(
          name: displayName,
          frets: List.unmodifiable(_frets),
          baseFret: _baseFret,
          fingers: List.unmodifiable(_fingers),
        ),
      ),
    );
  }

  Widget _buildFretGrid(ThemeData theme) {
    final options = _fretOptions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 24),
            const SizedBox(width: AppSpacing.sm),
            for (final fret in options)
              _FretHeaderCell(
                key: ValueKey('custom-chord-fret-header-${_fretKey(fret)}'),
                label: _fretHeaderLabel(fret),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var index = 0; index < _stringLabels.length; index++)
          _buildFretRow(index, options),
      ],
    );
  }

  Widget _buildFretRow(int stringIndex, List<int> options) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _StringLabel(label: _stringLabels[stringIndex]),
          const SizedBox(width: AppSpacing.sm),
          for (final fret in options)
            SizedBox(
              width: _choiceCellWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  key: ValueKey(
                    'custom-chord-fret-$stringIndex-${_fretKey(fret)}',
                  ),
                  label: SizedBox(
                    width: double.infinity,
                    child: Text(
                      _fretChoiceLabel(stringIndex, fret),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  selected: _frets[stringIndex] == fret,
                  onSelected: (_) => _setFret(stringIndex, fret),
                  showCheckmark: false,
                  labelPadding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFingerRow(BuildContext context, int stringIndex) {
    final fret = _frets[stringIndex];
    final canChooseFinger = fret > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _StringLabel(label: _stringLabels[stringIndex]),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final finger in _fingerOptions)
                  ChoiceChip(
                    key: ValueKey(
                      'custom-chord-finger-$stringIndex-$finger',
                    ),
                    label: Text('$finger'),
                    selected: _fingers[stringIndex] == finger,
                    onSelected: canChooseFinger
                        ? (_) => _setFinger(stringIndex, finger)
                        : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<int> _fretOptions() {
    final options = <int>{-1, 0};
    for (var fret = _baseFret; fret < _baseFret + 5; fret++) {
      options.add(fret);
    }
    return options.toList()..sort();
  }

  String _fretKey(int fret) {
    return fret < 0 ? 'x' : '$fret';
  }

  String _fretHeaderLabel(int fret) {
    if (fret < 0) {
      return 'x';
    }
    if (fret == 0) {
      return '0';
    }
    return '${fret - _baseFret + 1}';
  }

  String _fretChoiceLabel(int stringIndex, int fret) {
    if (fret < 0) {
      return 'x';
    }
    return guitarNoteNameFromFret(stringIndex, fret) ?? '$fret';
  }

  bool get _canSubmit {
    return _normalizedChordNameInput.isNotEmpty &&
        _frets.any((fret) => fret >= 0);
  }

  String get _normalizedChordNameInput {
    return _nameController.text.trim().replaceAll(RegExp(r'\s+'), '');
  }

  void _setBaseFret(int baseFret) {
    final nextBaseFret = baseFret.clamp(1, 20).toInt();
    final previousBaseFret = _baseFret;
    setState(() {
      _baseFret = nextBaseFret;
      _frets = [
        for (final fret in _frets)
          fret <= 0
              ? fret
              : (nextBaseFret + fret - previousBaseFret).clamp(1, 24).toInt(),
      ];
      _updateInferredName();
    });
  }

  void _setFret(int stringIndex, int fret) {
    setState(() {
      _frets[stringIndex] = fret;
      if (fret <= 0) {
        _fingers[stringIndex] = 0;
      } else if (_fingers[stringIndex] == 0) {
        _fingers[stringIndex] = 1;
      }
      _updateInferredName();
    });
  }

  void _setFinger(int stringIndex, int finger) {
    if (_frets[stringIndex] <= 0) {
      return;
    }

    setState(() => _fingers[stringIndex] = finger);
  }

  void _updateInferredName() {
    _inferredName = inferChordNameFromFrets(_frets);
    if (_nameEdited && _nameController.text.trim().isNotEmpty) {
      return;
    }

    final nextName = _inferredName ?? '';
    if (_nameController.text != nextName) {
      _nameController.value = TextEditingValue(
        text: nextName,
        selection: TextSelection.collapsed(offset: nextName.length),
      );
    }
    _nameEdited = false;
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }

    Navigator.pop(
      context,
      _CustomChordDefinition(
        name: _normalizedChordNameInput,
        baseFret: _baseFret,
        frets: List.unmodifiable(_frets),
        fingers: List.unmodifiable(_fingers),
      ),
    );
  }
}

class _StringLabel extends StatelessWidget {
  const _StringLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _FretHeaderCell extends StatelessWidget {
  const _FretHeaderCell({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _CustomChordDialogState._choiceCellWidth,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
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
              Text('关联项目', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: onManage,
                icon: const Icon(Icons.add_link_rounded),
                label: Text(linkedGoals.isEmpty ? '选择项目' : '管理'),
              ),
            ],
          ),
          if (linkedGoals.isEmpty)
            Text(
              '未关联项目。关联后，可在项目详情页看到这篇文档。',
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
    this.onEditCustomChord,
    this.scrollController,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.contentAlignment,
    this.maxContentWidth,
    this.showDocumentHeader = true,
    this.safeArea = true,
  });

  final String title;
  final String contentMarkdown;
  final DocumentType type;
  final VoidCallback? onTap;
  final ChordProCustomChordTap? onEditCustomChord;
  final ScrollController? scrollController;
  final EdgeInsets padding;
  final AlignmentGeometry? contentAlignment;
  final double? maxContentWidth;
  final bool showDocumentHeader;
  final bool safeArea;

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

    final preview = onTap == null
        ? _buildMarkdownPreview(
            theme, displayTitle, content, bodyStyle, mutedStyle)
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap,
            child: _buildMarkdownPreview(
              theme,
              displayTitle,
              content,
              bodyStyle,
              mutedStyle,
            ),
          );

    return safeArea ? SafeArea(child: preview) : preview;
  }

  Widget _buildMarkdownPreview(
    ThemeData theme,
    String displayTitle,
    String content,
    TextStyle? bodyStyle,
    TextStyle? mutedStyle,
  ) {
    final markdownData = showDocumentHeader
        ? '# $displayTitle\n\n> ${type.label}\n\n$content'
        : content;

    final markdown = Markdown(
      key: const ValueKey('document-markdown-preview'),
      padding: padding,
      controller: scrollController,
      data: markdownData,
      blockSyntaxes: [
        ...MarkdownMathSupport.blockSyntaxes,
        ...SafeMarkdownMusicSupport.blockSyntaxes(),
      ],
      inlineSyntaxes: MarkdownMathSupport.inlineSyntaxes(),
      builders: {
        ...MarkdownMathSupport.builders(),
        ...SafeMarkdownMusicSupport.builders(
          onCustomChordTap: onEditCustomChord,
        ),
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
    );

    final maxContentWidth = this.maxContentWidth;
    final contentAlignment = this.contentAlignment;
    if (maxContentWidth == null && contentAlignment == null) {
      return markdown;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedWidth = maxContentWidth == null
            ? constraints.maxWidth
            : constraints.maxWidth.clamp(0.0, maxContentWidth).toDouble();

        return Align(
          alignment: contentAlignment ?? Alignment.topCenter,
          child: SizedBox(
            width: boundedWidth,
            height: constraints.maxHeight,
            child: markdown,
          ),
        );
      },
    );
  }
}

class _ChordProFence {
  const _ChordProFence({
    required this.openingStart,
    required this.contentStart,
    required this.contentEnd,
    required this.closingEnd,
  });

  final int openingStart;
  final int contentStart;
  final int contentEnd;
  final int closingEnd;
}

final _markdownFenceOpeningPattern = RegExp(
  r'^\s*(`{3,}|~{3,})\s*([A-Za-z0-9_-]+)(?:\s+(.*))?\s*$',
);
final _chordProDefineLinePattern = RegExp(
  r'^\{define:\s*([^\s}]+)(?:\s+[^}]*)?\}\s*$',
  caseSensitive: false,
);
final _chordProDirectiveLinePattern = RegExp(r'^\{[^}]+\}\s*$');
const _chordProFenceLanguages = {
  'chord',
  'chords',
  'chordpro',
};

enum _DocumentEditAction {
  delete,
}

enum _DocumentViewMode {
  edit,
  splitPreview,
  preview,
}
