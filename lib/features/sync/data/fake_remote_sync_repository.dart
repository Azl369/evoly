import 'package:evoly/features/sync/data/remote_sync_repository.dart';
import 'package:evoly/features/sync/domain/sync_models.dart';

class FakeRemoteSyncRepository implements RemoteSyncRepository {
  final Map<String, RemoteSyncChange> _entities = {};
  var _revision = 0;

  @override
  Future<PushResult> pushChanges(List<SyncOutboxEntry> changes) async {
    for (final change in changes) {
      _revision += 1;
      final remoteChange = RemoteSyncChange(
        entityType: change.entityType,
        entityId: change.entityId,
        deviceId: change.deviceId,
        operation: change.operation,
        payload: Map<String, Object?>.from(change.payload),
        revision: _revision,
        updatedAt: DateTime.now(),
      );
      _entities[_keyFor(change.entityType, change.entityId)] = remoteChange;
    }

    return PushResult(
      pushedCount: changes.length,
      latestRevision: _revision,
    );
  }

  @override
  Future<PullResult> pullChanges({required int sinceRevision}) async {
    final changes = _entities.values
        .where((change) => change.revision > sinceRevision)
        .toList()
      ..sort((left, right) => left.revision.compareTo(right.revision));

    return PullResult(
      changes: changes,
      latestRevision: changes.isEmpty ? sinceRevision : changes.last.revision,
    );
  }

  String _keyFor(String entityType, String entityId) {
    return '$entityType/$entityId';
  }
}
