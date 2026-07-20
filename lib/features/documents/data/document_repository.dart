import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/documents/domain/document_folder_summary.dart';

abstract class DocumentRepository {
  Future<List<EvolyDocument>> findAll({
    String? query,
    DocumentType? type,
  });

  Future<List<EvolyDocument>> findByGoalId(String goalId, {int? limit});

  Future<List<DocumentFolderSummary>> findGoalFolders({String? query});

  Future<EvolyDocument?> findById(String id);

  Future<List<EvolyDocument>> findUnfiled({String? query});

  Future<List<String>> findLinkedGoalIds(String documentId);

  Future<void> replaceLinkedGoals(String documentId, List<String> goalIds);

  Future<void> save(EvolyDocument document);

  Future<void> delete(String id);
}

class InMemoryDocumentRepository implements DocumentRepository {
  final List<EvolyDocument> _documents = [];
  final Map<String, Set<String>> _linkedGoalIdsByDocumentId = {};

  @override
  Future<List<EvolyDocument>> findAll({
    String? query,
    DocumentType? type,
  }) async {
    final normalizedQuery = query?.trim().toLowerCase();
    final documents = _documents.where((document) {
      if (document.deletedAt != null) {
        return false;
      }
      if (type != null && document.type != type) {
        return false;
      }
      if (normalizedQuery == null || normalizedQuery.isEmpty) {
        return true;
      }
      return document.title.toLowerCase().contains(normalizedQuery) ||
          document.contentMarkdown.toLowerCase().contains(normalizedQuery);
    }).toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

    return List.unmodifiable(documents);
  }

  @override
  Future<EvolyDocument?> findById(String id) async {
    for (final document in _documents) {
      if (document.id == id && document.deletedAt == null) {
        return document;
      }
    }

    return null;
  }

  @override
  Future<List<DocumentFolderSummary>> findGoalFolders({String? query}) async {
    return const [];
  }

  @override
  Future<List<EvolyDocument>> findUnfiled({String? query}) async {
    return _documents.where((document) {
      if (document.deletedAt != null) {
        return false;
      }
      if (_linkedGoalIdsByDocumentId[document.id]?.isNotEmpty == true) {
        return false;
      }

      final normalizedQuery = query?.trim().toLowerCase();
      if (normalizedQuery == null || normalizedQuery.isEmpty) {
        return true;
      }

      return document.title.toLowerCase().contains(normalizedQuery) ||
          document.contentMarkdown.toLowerCase().contains(normalizedQuery);
    }).toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  @override
  Future<List<EvolyDocument>> findByGoalId(String goalId, {int? limit}) async {
    final documents = _documents.where((document) {
      if (document.deletedAt != null) {
        return false;
      }

      return _linkedGoalIdsByDocumentId[document.id]?.contains(goalId) ?? false;
    }).toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

    return limit == null ? documents : documents.take(limit).toList();
  }

  @override
  Future<List<String>> findLinkedGoalIds(String documentId) async {
    return List.unmodifiable(_linkedGoalIdsByDocumentId[documentId] ?? {});
  }

  @override
  Future<void> replaceLinkedGoals(
    String documentId,
    List<String> goalIds,
  ) async {
    _linkedGoalIdsByDocumentId[documentId] = goalIds.toSet();
  }

  @override
  Future<void> save(EvolyDocument document) async {
    final index = _documents.indexWhere((item) => item.id == document.id);
    if (index == -1) {
      _documents.add(document);
      return;
    }

    _documents[index] = document;
  }

  @override
  Future<void> delete(String id) async {
    final index = _documents.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }

    final now = DateTime.now();
    _documents[index] = _documents[index].copyWith(
      deletedAt: now,
      updatedAt: now,
    );
  }
}
