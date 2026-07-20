import 'dart:async';

import 'package:evoly/app/theme.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/document_folder_summary.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/documents/presentation/document_edit_page.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly_markdown_music_preview/evoly_markdown_music_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Ctrl+S saves the document while markdown editor is focused', (
    tester,
  ) async {
    final documentRepository = _RecordingDocumentRepository();

    await _pumpDocumentEditPage(tester, documentRepository);
    await tester.enterText(find.byType(TextField).first, 'Release notes');
    await tester.enterText(find.byType(TextField).last, '# v0.4.1\nSaved');
    await tester.tap(find.byType(TextField).last);
    await tester.pump();

    await _sendCtrlS(tester);
    await tester.pumpAndSettle();

    expect(documentRepository.saveCount, 1);
    expect(documentRepository.savedDocument?.title, 'Release notes');
    expect(
        documentRepository.savedDocument?.contentMarkdown, '# v0.4.1\nSaved');
    expect(documentRepository.replacedLinkedGoalsCount, 1);
  });

  testWidgets('repeated Ctrl+S is ignored while a save is in progress', (
    tester,
  ) async {
    final saveCompleter = Completer<void>();
    final documentRepository = _RecordingDocumentRepository(
      saveCompleter: saveCompleter,
    );

    await _pumpDocumentEditPage(tester, documentRepository);
    await tester.enterText(find.byType(TextField).first, 'Draft');
    await tester.enterText(find.byType(TextField).last, 'Body');
    await tester.tap(find.byType(TextField).last);
    await tester.pump();

    await _sendCtrlS(tester);
    await tester.pump();
    await _sendCtrlS(tester);
    await tester.pump();

    expect(documentRepository.saveCount, 1);

    saveCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Windows editor can show live split markdown preview', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final documentRepository = _RecordingDocumentRepository();

    await _pumpDocumentEditPage(
      tester,
      documentRepository,
      mediaQueryData: const MediaQueryData(size: Size(1200, 800)),
    );

    await tester.enterText(find.byType(TextField).first, 'Live notes');
    await tester.enterText(
      find.byType(TextField).last,
      '# Heading\nInitial paragraph',
    );
    await tester.pump();

    await tester.tap(find.text('分屏'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(
      tester.getTopRight(find.byIcon(Icons.library_music_outlined)).dx,
      greaterThan(1140),
    );
    expect(find.text('Initial paragraph'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).last,
      '# Heading\nUpdated paragraph',
    );
    await tester.pump();

    expect(find.text('Initial paragraph'), findsNothing);
    expect(find.text('Updated paragraph'), findsOneWidget);

    await tester.tap(find.text('预览'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Updated paragraph'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows split preview scrolls with the markdown editor', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final documentRepository = _RecordingDocumentRepository();
    final markdown = List.generate(
      80,
      (index) => '## Section $index\n\nParagraph $index',
    ).join('\n\n');

    await _pumpDocumentEditPage(
      tester,
      documentRepository,
      mediaQueryData: const MediaQueryData(size: Size(1200, 620)),
    );

    await tester.enterText(find.byType(TextField).last, markdown);
    await tester.pump();

    await tester.tap(find.text('分屏'));
    await tester.pumpAndSettle();

    final editorScrollable = find.descendant(
      of: find.byKey(const ValueKey('document-markdown-editor')),
      matching: find.byType(Scrollable),
    );
    final previewScrollable = find.descendant(
      of: find.byKey(const ValueKey('document-markdown-preview')),
      matching: find.byType(Scrollable),
    );
    final editorState = tester.state<ScrollableState>(editorScrollable);
    final previewState = tester.state<ScrollableState>(previewScrollable);

    editorState.position.jumpTo(0);
    await tester.pump();

    expect(previewState.position.pixels, 0);

    editorState.position.jumpTo(editorState.position.maxScrollExtent * 0.75);
    await tester.pump();

    expect(previewState.position.pixels, greaterThan(0));

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('inserts a custom ChordPro chord definition into the song block',
      (
    tester,
  ) async {
    final documentRepository = _RecordingDocumentRepository();

    await _pumpDocumentEditPage(tester, documentRepository);
    await tester.enterText(
      find.byType(TextField).last,
      '''
```chordpro
{title: Custom}
{key: C}

When [C]custom shapes ring
```
''',
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('document-custom-chord-button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('custom-chord-fret-header-4')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('custom-chord-fret-0-4')),
        matching: find.text('G#'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('custom-chord-fret-1-3')),
        matching: find.text('C'),
      ),
      findsOneWidget,
    );

    await _tapCustomChordChip(tester, 'custom-chord-fret-1-3');
    await _tapCustomChordChip(tester, 'custom-chord-fret-2-2');
    await _tapCustomChordChip(tester, 'custom-chord-fret-3-0');
    await _tapCustomChordChip(tester, 'custom-chord-fret-4-1');
    await _tapCustomChordChip(tester, 'custom-chord-fret-5-0');
    await _tapCustomChordChip(tester, 'custom-chord-finger-1-3');
    await _tapCustomChordChip(tester, 'custom-chord-finger-2-2');

    expect(find.text('按弦产生 C · E · G · C · E'), findsOneWidget);
    expect(find.text('C 组成音 C · E · G'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('custom-chord-submit')));
    await tester.pumpAndSettle();

    final contentField = tester.widget<TextField>(find.byType(TextField).last);
    final content = contentField.controller!.text;
    const definition =
        '{define: C base-fret 1 frets x 3 2 0 1 0 fingers x 3 2 0 1 0}';

    expect(content, contains(definition));
    expect(
        content.indexOf(definition), greaterThan(content.indexOf('{key: C}')));
    expect(
      content.indexOf(definition),
      lessThan(content.indexOf('\n\nWhen [C]custom')),
    );
  });

  testWidgets('clicking a custom chord in split preview edits its definition', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final documentRepository = _RecordingDocumentRepository();

    await _pumpDocumentEditPage(
      tester,
      documentRepository,
      mediaQueryData: const MediaQueryData(size: Size(1200, 800)),
    );
    await tester.enterText(
      find.byType(TextField).last,
      '''
```chordpro
{title: Custom}
{define: C base-fret 1 frets x 3 2 0 1 0 fingers x 3 2 0 1 0}

When [C]custom shapes ring
```
''',
    );
    await tester.pumpAndSettle();

    final customChordDiagram = find.byWidgetPredicate(
      (widget) => widget is ChordDiagramView && widget.chord == 'C',
    );
    expect(customChordDiagram, findsOneWidget);

    await tester.tap(customChordDiagram);
    await tester.pumpAndSettle();

    expect(find.text('编辑自定义和弦'), findsOneWidget);
    await _tapCustomChordChip(tester, 'custom-chord-fret-1-5');
    await tester.tap(find.byKey(const ValueKey('custom-chord-submit')));
    await tester.pumpAndSettle();

    final contentField = tester.widget<TextField>(find.byType(TextField).last);
    final content = contentField.controller!.text;
    const updatedDefinition =
        '{define: C base-fret 1 frets x 5 2 0 1 0 fingers x 3 2 0 1 0}';

    expect(content, contains(updatedDefinition));
    expect(
      RegExp(r'\{define:\s*C\b').allMatches(content),
      hasLength(1),
    );

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Windows wide split preview centers preview content', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(2048, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final documentRepository = _RecordingDocumentRepository();

    await _pumpDocumentEditPage(
      tester,
      documentRepository,
      mediaQueryData: const MediaQueryData(size: Size(2048, 920)),
    );

    await tester.enterText(
      find.byType(TextField).last,
      '''
```chordpro
{title: 挚友}
{key: A}
{tempo: 76}

相当[Cmaj7]星辰, [G]up, up
[Am]Keep it steady [F]and light
```
''',
    );
    await tester.pumpAndSettle();

    final previewTitleX = tester.getTopLeft(find.text('挚友')).dx;
    expect(previewTitleX, greaterThan(1180));
    expect(previewTitleX, lessThan(1450));

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'Android markdown focus hides document metadata before keyboard inset animates',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final documentRepository = _RecordingDocumentRepository();

      await _pumpDocumentEditPage(tester, documentRepository);

      expect(find.text('标题'), findsOneWidget);
      expect(find.text('关联项目'), findsOneWidget);

      await tester.showKeyboard(find.byType(TextField).last);
      await tester.pump();

      expect(find.text('标题'), findsNothing);
      expect(find.text('文档类型'), findsNothing);
      expect(find.text('关联项目'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      await _pumpDocumentEditPage(
        tester,
        documentRepository,
        mediaQueryData: const MediaQueryData(
          viewInsets: EdgeInsets.only(bottom: 320),
        ),
      );

      expect(find.text('标题'), findsNothing);
      expect(find.text('文档类型'), findsNothing);
      expect(find.text('关联项目'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    },
  );
}

Future<void> _pumpDocumentEditPage(
  WidgetTester tester,
  _RecordingDocumentRepository documentRepository, {
  MediaQueryData? mediaQueryData,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<DocumentRepository>.value(value: documentRepository),
        Provider<GoalRepository>.value(value: _EmptyGoalRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: mediaQueryData ?? const MediaQueryData(),
          child: const DocumentEditPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _sendCtrlS(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Future<void> _tapCustomChordChip(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _RecordingDocumentRepository implements DocumentRepository {
  _RecordingDocumentRepository({this.saveCompleter});

  final Completer<void>? saveCompleter;
  var saveCount = 0;
  var replacedLinkedGoalsCount = 0;
  EvolyDocument? savedDocument;

  @override
  Future<void> save(EvolyDocument document) async {
    saveCount += 1;
    savedDocument = document;
    await saveCompleter?.future;
  }

  @override
  Future<void> replaceLinkedGoals(
      String documentId, List<String> goalIds) async {
    replacedLinkedGoalsCount += 1;
  }

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<EvolyDocument>> findAll({
    String? query,
    DocumentType? type,
  }) async {
    return const [];
  }

  @override
  Future<List<EvolyDocument>> findByGoalId(String goalId, {int? limit}) async {
    return const [];
  }

  @override
  Future<EvolyDocument?> findById(String id) async {
    return null;
  }

  @override
  Future<List<DocumentFolderSummary>> findGoalFolders({String? query}) async {
    return const [];
  }

  @override
  Future<List<String>> findLinkedGoalIds(String documentId) async {
    return const [];
  }

  @override
  Future<List<EvolyDocument>> findUnfiled({String? query}) async {
    return const [];
  }
}

class _EmptyGoalRepository implements GoalRepository {
  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Goal>> findAll() async {
    return const [];
  }

  @override
  Future<Goal?> findById(String id) async {
    return null;
  }

  @override
  Future<void> save(Goal goal) async {}
}
