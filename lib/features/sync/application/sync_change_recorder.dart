import 'dart:convert';
import 'dart:io';

import 'package:evoly/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

class SyncEntityType {
  const SyncEntityType._();

  static const goal = 'goal';
  static const task = 'task';
  static const reminder = 'reminder';
  static const document = 'document';
  static const documentLinks = 'document_links';
}

class SyncOperation {
  const SyncOperation._();

  static const upsert = 'upsert';
  static const delete = 'delete';
}

class SyncChangeRecorder {
  SyncChangeRecorder(this.database);

  final AppDatabase database;
  final _uuid = const Uuid();
  String? _deviceId;

  Future<void> recordUpsert({
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) {
    return _recordChange(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.upsert,
      payload: payload,
    );
  }

  Future<void> recordDelete({
    required String entityType,
    required String entityId,
    Map<String, Object?>? payload,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _recordChange(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.delete,
      payload: payload ??
          {
            'id': entityId,
            'deleted_at': now,
          },
    );
  }

  Future<String> ensureDeviceIdentity() async {
    final cachedDeviceId = _deviceId;
    if (cachedDeviceId != null) {
      return cachedDeviceId;
    }

    final db = await database.database;
    final rows = await db.query(
      'device_identity',
      orderBy: 'created_at ASC',
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final id = rows.first['id']! as String;
      _deviceId = id;
      return id;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'device-${_uuid.v4()}';
    await db.insert(
      'device_identity',
      {
        'id': id,
        'device_name': _deviceName(),
        'platform': Platform.operatingSystem,
        'created_at': now,
        'updated_at': now,
      },
    );

    _deviceId = id;
    return id;
  }

  Future<void> _recordChange({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    final db = await database.database;
    final deviceId = await ensureDeviceIdentity();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('sync_outbox', {
      'id': 'change-${_uuid.v4()}',
      'entity_type': entityType,
      'entity_id': entityId,
      'device_id': deviceId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'base_remote_revision': 0,
      'created_at': now,
      'attempts': 0,
      'last_error': null,
    });
  }

  String _deviceName() {
    final hostName = Platform.localHostname.trim();
    if (hostName.isNotEmpty) {
      return hostName;
    }

    return '${Platform.operatingSystem} device';
  }
}
