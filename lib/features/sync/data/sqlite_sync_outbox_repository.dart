import 'dart:convert';

import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/sync/domain/sync_models.dart';

class SqliteSyncOutboxRepository {
  const SqliteSyncOutboxRepository(this.database);

  final AppDatabase database;

  Future<List<SyncOutboxEntry>> findPending({int limit = 100}) async {
    final db = await database.database;
    final rows = await db.query(
      'sync_outbox',
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return rows.map(_fromMap).toList();
  }

  Future<void> deleteSynced(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }

    final db = await database.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.delete(
      'sync_outbox',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> markFailed(List<String> ids, String errorMessage) async {
    if (ids.isEmpty) {
      return;
    }

    final db = await database.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.rawUpdate(
      '''
      UPDATE sync_outbox
      SET attempts = attempts + 1,
          last_error = ?
      WHERE id IN ($placeholders)
      ''',
      [errorMessage, ...ids],
    );
  }

  SyncOutboxEntry _fromMap(Map<String, Object?> map) {
    final payload = jsonDecode(map['payload_json']! as String);

    return SyncOutboxEntry(
      id: map['id']! as String,
      entityType: map['entity_type']! as String,
      entityId: map['entity_id']! as String,
      deviceId: map['device_id']! as String,
      operation: map['operation']! as String,
      payload: Map<String, Object?>.from(payload as Map),
      baseRemoteRevision: (map['base_remote_revision']! as num).toInt(),
      createdAt: AppDatabaseDateCodec.decodeDate(map['created_at']!),
      attempts: (map['attempts']! as num).toInt(),
      lastError: map['last_error'] as String?,
    );
  }
}
