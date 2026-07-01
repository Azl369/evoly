import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/documents/data/document_mapper.dart';
import 'package:evoly/features/documents/data/document_repository.dart';
import 'package:evoly/features/documents/domain/document_folder_summary.dart';
import 'package:evoly/features/documents/domain/evoly_document.dart';
import 'package:evoly/features/goals/domain/goal.dart';

class SqliteDocumentRepository implements DocumentRepository {
  const SqliteDocumentRepository(this.database);

  final AppDatabase database;

  @override
  Future<List<EvolyDocument>> findAll({
    String? query,
    DocumentType? type,
  }) async {
    final db = await database.database;
    final whereParts = <String>['deleted_at IS NULL'];
    final whereArgs = <Object?>[];
    final normalizedQuery = query?.trim();

    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      whereParts.add('(title LIKE ? OR content_markdown LIKE ?)');
      final likeQuery = '%$normalizedQuery%';
      whereArgs.addAll([likeQuery, likeQuery]);
    }

    if (type != null) {
      whereParts.add('type = ?');
      whereArgs.add(type.name);
    }

    final rows = await db.query(
      'documents',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );

    return rows.map(DocumentMapper.fromMap).toList();
  }

  @override
  Future<EvolyDocument?> findById(String id) async {
    final db = await database.database;
    final rows = await db.query(
      'documents',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return DocumentMapper.fromMap(rows.first);
  }

  @override
  Future<List<DocumentFolderSummary>> findGoalFolders({String? query}) async {
    final db = await database.database;
    final whereParts = <String>[];
    final whereArgs = <Object?>[];
    final normalizedQuery = query?.trim();

    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      whereParts.add('g.title LIKE ?');
      whereArgs.add('%$normalizedQuery%');
    }

    final rows = await db.rawQuery(
      '''
      SELECT
        g.id AS goal_id,
        g.title AS goal_title,
        g.status AS goal_status,
        g.progress AS goal_progress,
        COUNT(d.id) AS document_count,
        MAX(d.updated_at) AS latest_updated_at,
        (
          SELECT d2.title
          FROM documents d2
          INNER JOIN document_links l2 ON l2.document_id = d2.id
          WHERE d2.deleted_at IS NULL
            AND l2.target_type = 'goal'
            AND l2.target_id = g.id
          ORDER BY d2.updated_at DESC
          LIMIT 1
        ) AS latest_document_title
      FROM goals g
      LEFT JOIN document_links l
        ON l.target_type = 'goal'
       AND l.target_id = g.id
      LEFT JOIN documents d
        ON d.id = l.document_id
       AND d.deleted_at IS NULL
      ${whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}'}
      GROUP BY g.id
      ORDER BY
        CASE WHEN MAX(d.updated_at) IS NULL THEN 1 ELSE 0 END,
        MAX(d.updated_at) DESC,
        g.updated_at DESC
      ''',
      whereArgs,
    );

    return rows.map((row) {
      return DocumentFolderSummary(
        goalId: row['goal_id']! as String,
        goalTitle: row['goal_title']! as String,
        goalStatus: GoalStatus.values.byName(row['goal_status']! as String),
        goalProgress: (row['goal_progress']! as num).toDouble(),
        documentCount: row['document_count']! as int,
        latestDocumentTitle: row['latest_document_title'] as String?,
        latestUpdatedAt: AppDatabaseDateCodec.decodeNullableDate(
          row['latest_updated_at'],
        ),
      );
    }).toList();
  }

  @override
  Future<List<EvolyDocument>> findUnfiled({String? query}) async {
    final db = await database.database;
    final whereParts = <String>[
      'd.deleted_at IS NULL',
      '''
      NOT EXISTS (
        SELECT 1
        FROM document_links l
        WHERE l.document_id = d.id
          AND l.target_type = 'goal'
      )
      ''',
    ];
    final whereArgs = <Object?>[];
    final normalizedQuery = query?.trim();

    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      whereParts.add('(d.title LIKE ? OR d.content_markdown LIKE ?)');
      final likeQuery = '%$normalizedQuery%';
      whereArgs.addAll([likeQuery, likeQuery]);
    }

    final rows = await db.query(
      'documents d',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'd.updated_at DESC',
    );

    return rows.map(DocumentMapper.fromMap).toList();
  }

  @override
  Future<List<EvolyDocument>> findByGoalId(
    String goalId, {
    int? limit,
  }) async {
    final db = await database.database;
    final rows = await db.rawQuery(
      '''
      SELECT d.*
      FROM documents d
      INNER JOIN document_links l ON l.document_id = d.id
      WHERE d.deleted_at IS NULL
        AND l.target_type = ?
        AND l.target_id = ?
      ORDER BY d.updated_at DESC
      ${limit == null ? '' : 'LIMIT ?'}
      ''',
      [
        'goal',
        goalId,
        if (limit != null) limit,
      ],
    );

    return rows.map(DocumentMapper.fromMap).toList();
  }

  @override
  Future<List<String>> findLinkedGoalIds(String documentId) async {
    final db = await database.database;
    final rows = await db.query(
      'document_links',
      columns: ['target_id'],
      where: 'document_id = ? AND target_type = ?',
      whereArgs: [documentId, 'goal'],
      orderBy: 'created_at ASC',
    );

    return rows.map((row) => row['target_id']! as String).toList();
  }

  @override
  Future<void> replaceLinkedGoals(
    String documentId,
    List<String> goalIds,
  ) async {
    final db = await database.database;
    final uniqueGoalIds = goalIds.toSet().toList();
    final now = AppDatabaseDateCodec.encodeDate(DateTime.now());

    await db.transaction((transaction) async {
      await transaction.delete(
        'document_links',
        where: 'document_id = ? AND target_type = ?',
        whereArgs: [documentId, 'goal'],
      );

      for (final goalId in uniqueGoalIds) {
        await transaction.insert(
          'document_links',
          {
            'id': '$documentId-goal-$goalId',
            'document_id': documentId,
            'target_type': 'goal',
            'target_id': goalId,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<void> save(EvolyDocument document) async {
    final db = await database.database;
    await db.insert(
      'documents',
      DocumentMapper.toMap(document),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await database.database;
    final now = AppDatabaseDateCodec.encodeDate(DateTime.now());
    await db.update(
      'documents',
      {
        'deleted_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
