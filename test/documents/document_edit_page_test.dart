import 'dart:async';

import 'package:evoly/app/theme.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/document_folder_summary.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/documents/presentation/document_edit_page.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
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
}

Future<void> _pumpDocumentEditPage(
  WidgetTester tester,
  _RecordingDocumentRepository documentRepository,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<DocumentRepository>.value(value: documentRepository),
        Provider<GoalRepository>.value(value: _EmptyGoalRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const DocumentEditPage(),
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
