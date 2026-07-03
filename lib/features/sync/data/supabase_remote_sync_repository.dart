import 'dart:convert';
import 'dart:math' as math;

import 'package:evoly/features/sync/data/remote_sync_repository.dart';
import 'package:evoly/features/sync/domain/sync_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRemoteSyncRepository implements RemoteSyncRepository {
  const SupabaseRemoteSyncRepository(this.client);

  static const _tableName = 'sync_changes';

  final SupabaseClient client;

  @override
  Future<PushResult> pushChanges(List<SyncOutboxEntry> changes) async {
    if (changes.isEmpty) {
      return const PushResult(pushedCount: 0, latestRevision: 0);
    }

    final accountId = _requireAccountId();
    final rows = changes
        .map(
          (change) => {
            'account_id': accountId,
            'entity_type': change.entityType,
            'entity_id': change.entityId,
            'operation': change.operation,
            'payload_json': change.payload,
            'base_remote_revision': change.baseRemoteRevision,
            'device_id': change.deviceId,
            'client_change_id': change.id,
          },
        )
        .toList();

    final insertedRows = await client
        .from(_tableName)
        .insert(rows)
        .select('revision') as List<dynamic>;
    final latestRevision = insertedRows
        .map((row) => _intFrom((row as Map)['revision']))
        .fold<int>(0, math.max);

    return PushResult(
      pushedCount: changes.length,
      latestRevision: latestRevision,
    );
  }

  @override
  Future<PullResult> pullChanges({required int sinceRevision}) async {
    final accountId = _requireAccountId();
    final rows = await client
        .from(_tableName)
        .select(
          'entity_type, entity_id, operation, payload_json, device_id, revision, updated_at',
        )
        .eq('account_id', accountId)
        .gt('revision', sinceRevision)
        .order('revision') as List<dynamic>;

    final changes = rows
        .map((row) => _changeFromMap(Map<String, Object?>.from(row as Map)))
        .toList();
    final parentGoalChanges = await _findParentGoalChanges(
      accountId: accountId,
      changes: changes,
    );
    final mergedChanges = _dedupeChanges([
      ...parentGoalChanges,
      ...changes,
    ]);

    return PullResult(
      changes: mergedChanges,
      latestRevision: changes.isEmpty ? sinceRevision : changes.last.revision,
    );
  }

  Future<List<RemoteSyncChange>> _findParentGoalChanges({
    required String accountId,
    required List<RemoteSyncChange> changes,
  }) async {
    final goalIds = changes
        .where(
          (change) =>
              change.entityType == 'task' && change.operation == 'upsert',
        )
        .map((change) => change.payload['goal_id'])
        .whereType<String>()
        .toSet()
        .toList();

    if (goalIds.isEmpty) {
      return const [];
    }

    final rows = await client
        .from(_tableName)
        .select(
          'entity_type, entity_id, operation, payload_json, device_id, revision, updated_at',
        )
        .eq('account_id', accountId)
        .eq('entity_type', 'goal')
        .inFilter('entity_id', goalIds)
        .order('revision', ascending: false) as List<dynamic>;

    final latestByGoalId = <String, RemoteSyncChange>{};
    for (final row in rows) {
      final change = _changeFromMap(Map<String, Object?>.from(row as Map));
      latestByGoalId.putIfAbsent(change.entityId, () => change);
    }

    return latestByGoalId.values.toList()
      ..sort((left, right) => left.revision.compareTo(right.revision));
  }

  List<RemoteSyncChange> _dedupeChanges(List<RemoteSyncChange> changes) {
    final seen = <String>{};
    final deduped = <RemoteSyncChange>[];

    for (final change in changes) {
      final key = '${change.entityType}/${change.entityId}/${change.revision}';
      if (seen.add(key)) {
        deduped.add(change);
      }
    }

    return deduped;
  }

  RemoteSyncChange _changeFromMap(Map<String, Object?> map) {
    return RemoteSyncChange(
      entityType: map['entity_type']! as String,
      entityId: map['entity_id']! as String,
      operation: map['operation']! as String,
      payload: _payloadFrom(map['payload_json']),
      deviceId: map['device_id']! as String,
      revision: _intFrom(map['revision']),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  Map<String, Object?> _payloadFrom(Object? value) {
    if (value is String) {
      return Map<String, Object?>.from(jsonDecode(value) as Map);
    }

    return Map<String, Object?>.from(value! as Map);
  }

  int _intFrom(Object? value) {
    return (value! as num).toInt();
  }

  String _requireAccountId() {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('未登录，无法同步');
    }

    return userId;
  }
}
