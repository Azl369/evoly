import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/sync/application/sync_change_recorder.dart';
import 'package:evoly/features/sync/domain/sync_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteRemoteChangeApplier {
  const SqliteRemoteChangeApplier(this.database);

  final AppDatabase database;

  Future<RemoteApplyResult> applyAll(List<RemoteSyncChange> changes) async {
    var appliedCount = 0;
    var skippedCount = 0;
    int? firstSkippedRevision;
    final sortedChanges = _sortForDependencies(changes);

    for (final change in sortedChanges) {
      final applied = await apply(change);
      if (applied) {
        appliedCount += 1;
      } else {
        skippedCount += 1;
        final skippedRevision = change.revision;
        if (firstSkippedRevision == null ||
            skippedRevision < firstSkippedRevision) {
          firstSkippedRevision = skippedRevision;
        }
      }
    }

    return RemoteApplyResult(
      appliedCount: appliedCount,
      skippedCount: skippedCount,
      firstSkippedRevision: firstSkippedRevision,
    );
  }

  Future<bool> apply(RemoteSyncChange change) async {
    try {
      if (change.operation == SyncOperation.delete) {
        return _applyDelete(change);
      }

      return _applyUpsert(change);
    } catch (error) {
      if (_isForeignKeyError(error)) {
        return false;
      }

      rethrow;
    }
  }

  Future<bool> _applyUpsert(RemoteSyncChange change) async {
    final payload = Map<String, Object?>.from(change.payload);

    switch (change.entityType) {
      case SyncEntityType.goal:
        await _upsertById('goals', payload);
        return true;
      case SyncEntityType.task:
        final goalId = payload['goal_id'] as String?;
        if (goalId == null || !await _exists('goals', goalId)) {
          return false;
        }
        await _upsertById('tasks', payload);
        return true;
      case SyncEntityType.document:
        await _upsertById('documents', payload);
        return true;
      case SyncEntityType.reminder:
        await _upsertById('reminders', payload);
        return true;
      case SyncEntityType.documentLinks:
        final documentId = payload['document_id'] as String?;
        if (documentId == null || !await _exists('documents', documentId)) {
          return false;
        }
        await _replaceDocumentLinks(payload);
        return true;
    }

    return false;
  }

  Future<bool> _applyDelete(RemoteSyncChange change) async {
    final db = await database.database;

    switch (change.entityType) {
      case SyncEntityType.goal:
        await db.delete('goals', where: 'id = ?', whereArgs: [change.entityId]);
        return true;
      case SyncEntityType.task:
        await db.delete('tasks', where: 'id = ?', whereArgs: [change.entityId]);
        return true;
      case SyncEntityType.document:
        final deletedAt = change.payload['deleted_at'];
        await db.update(
          'documents',
          {
            'deleted_at': deletedAt,
            'updated_at': deletedAt,
          },
          where: 'id = ?',
          whereArgs: [change.entityId],
        );
        return true;
      case SyncEntityType.reminder:
        await db.delete(
          'reminders',
          where: 'id = ?',
          whereArgs: [change.entityId],
        );
        return true;
      case SyncEntityType.documentLinks:
        await db.delete(
          'document_links',
          where: 'document_id = ? AND target_type = ?',
          whereArgs: [change.entityId, 'goal'],
        );
        return true;
    }

    return false;
  }

  Future<void> _replaceDocumentLinks(Map<String, Object?> payload) async {
    final documentId = payload['document_id']! as String;
    final targetType = payload['target_type'] as String? ?? 'goal';
    final goalIds = (payload['goal_ids'] as List? ?? const []).cast<String>();
    final now = AppDatabaseDateCodec.encodeDate(DateTime.now());
    final db = await database.database;

    await db.transaction((transaction) async {
      await transaction.delete(
        'document_links',
        where: 'document_id = ? AND target_type = ?',
        whereArgs: [documentId, targetType],
      );

      for (final goalId in goalIds) {
        await transaction.insert(
          'document_links',
          {
            'id': '$documentId-$targetType-$goalId',
            'document_id': documentId,
            'target_type': targetType,
            'target_id': goalId,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<bool> _exists(String table, String id) async {
    final db = await database.database;
    final rows = await db.query(
      table,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<void> _upsertById(
    String table,
    Map<String, Object?> payload,
  ) async {
    final id = payload['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('Remote $table payload is missing id.');
    }

    final db = await database.database;
    final updated = await db.update(
      table,
      payload,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (updated == 0) {
      await db.insert(table, payload);
    }
  }

  bool _isForeignKeyError(Object error) {
    final message = error.toString().toLowerCase();

    return message.contains('foreign key') ||
        message.contains('sqlite_constraint_foreignkey') ||
        message.contains('code 787');
  }

  List<RemoteSyncChange> _sortForDependencies(
    List<RemoteSyncChange> changes,
  ) {
    return [...changes]..sort((left, right) {
        final rankCompare = _applicationRank(left).compareTo(
          _applicationRank(right),
        );
        if (rankCompare != 0) {
          return rankCompare;
        }

        return left.revision.compareTo(right.revision);
      });
  }

  int _applicationRank(RemoteSyncChange change) {
    if (change.operation == SyncOperation.delete) {
      return switch (change.entityType) {
        SyncEntityType.documentLinks => 50,
        SyncEntityType.reminder => 60,
        SyncEntityType.task => 70,
        SyncEntityType.document => 80,
        SyncEntityType.goal => 90,
        _ => 99,
      };
    }

    return switch (change.entityType) {
      SyncEntityType.goal => 0,
      SyncEntityType.document => 10,
      SyncEntityType.task => 20,
      SyncEntityType.reminder => 30,
      SyncEntityType.documentLinks => 40,
      _ => 49,
    };
  }
}

class RemoteApplyResult {
  const RemoteApplyResult({
    required this.appliedCount,
    required this.skippedCount,
    this.firstSkippedRevision,
  });

  final int appliedCount;
  final int skippedCount;
  final int? firstSkippedRevision;
}
