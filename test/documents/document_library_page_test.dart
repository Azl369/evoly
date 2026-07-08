import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evoly/app/theme.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/document_folder_summary.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/documents/presentation/document_library_page.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/shared/ui/components/app_components.dart';

void main() {
  testWidgets('document library renders semantic surfaces for core sections',
      (tester) async {
    final now = DateTime(2026, 1, 2, 10, 30);
    final repository = _FakeDocumentRepository(
      folders: [
        DocumentFolderSummary(
          goalId: 'goal-1',
          goalTitle: '发布 V1',
          goalStatus: GoalStatus.inProgress,
          goalProgress: 0.45,
          documentCount: 1,
          latestDocumentTitle: '里程碑记录',
          latestUpdatedAt: now,
        ),
      ],
      documents: [
        EvolyDocument(
          id: 'doc-linked',
          title: '里程碑记录',
          contentMarkdown: '围绕发布节奏整理下一步。',
          type: DocumentType.projectNote,
          createdAt: now,
          updatedAt: now,
        ),
        EvolyDocument(
          id: 'doc-unfiled',
          title: '独立灵感',
          contentMarkdown: '暂时还没有关联项目。',
          type: DocumentType.knowledge,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      unfiledDocuments: [
        EvolyDocument(
          id: 'doc-unfiled',
          title: '独立灵感',
          contentMarkdown: '暂时还没有关联项目。',
          type: DocumentType.knowledge,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    await tester.pumpWidget(
      Provider<DocumentRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DocumentLibraryPage(showBottomNavigationBar: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('文档库'), findsOneWidget);
    expect(find.text('文档概览'), findsOneWidget);
    expect(find.text('项目档案夹'), findsOneWidget);
    expect(find.byType(AppSurface), findsAtLeastNWidgets(2));

    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pump();

    expect(find.text('未归档'), findsWidgets);
    expect(find.text('独立灵感'), findsOneWidget);
  });
}

class _FakeDocumentRepository implements DocumentRepository {
  const _FakeDocumentRepository({
    required this.folders,
    required this.documents,
    required this.unfiledDocuments,
  });

  final List<DocumentFolderSummary> folders;
  final List<EvolyDocument> documents;
  final List<EvolyDocument> unfiledDocuments;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<EvolyDocument>> findAll({
    String? query,
    DocumentType? type,
  }) async {
    return documents.where((document) {
      return type == null || document.type == type;
    }).toList();
  }

  @override
  Future<EvolyDocument?> findById(String id) async {
    return documents.where((document) => document.id == id).firstOrNull;
  }

  @override
  Future<List<EvolyDocument>> findByGoalId(String goalId, {int? limit}) async {
    return limit == null ? documents : documents.take(limit).toList();
  }

  @override
  Future<List<DocumentFolderSummary>> findGoalFolders({String? query}) async {
    return folders;
  }

  @override
  Future<List<String>> findLinkedGoalIds(String documentId) async {
    return const [];
  }

  @override
  Future<List<EvolyDocument>> findUnfiled({String? query}) async {
    return unfiledDocuments;
  }

  @override
  Future<void> replaceLinkedGoals(
      String documentId, List<String> goalIds) async {}

  @override
  Future<void> save(EvolyDocument document) async {}
}
