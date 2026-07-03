class SyncOutboxEntry {
  const SyncOutboxEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.deviceId,
    required this.operation,
    required this.payload,
    required this.baseRemoteRevision,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String deviceId;
  final String operation;
  final Map<String, Object?> payload;
  final int baseRemoteRevision;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
}

class RemoteSyncChange {
  const RemoteSyncChange({
    required this.entityType,
    required this.entityId,
    required this.deviceId,
    required this.operation,
    required this.payload,
    required this.revision,
    required this.updatedAt,
  });

  final String entityType;
  final String entityId;
  final String deviceId;
  final String operation;
  final Map<String, Object?> payload;
  final int revision;
  final DateTime updatedAt;
}

class PushResult {
  const PushResult({
    required this.pushedCount,
    required this.latestRevision,
  });

  final int pushedCount;
  final int latestRevision;
}

class PullResult {
  const PullResult({
    required this.changes,
    required this.latestRevision,
  });

  final List<RemoteSyncChange> changes;
  final int latestRevision;
}

class SyncResult {
  const SyncResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.latestRevision,
    required this.skipped,
    this.message,
  });

  final int pushedCount;
  final int pulledCount;
  final int latestRevision;
  final bool skipped;
  final String? message;
}
