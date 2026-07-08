import 'package:evoly/features/sync/application/sqlite_remote_change_applier.dart';
import 'package:evoly/features/sync/data/remote_sync_repository.dart';
import 'package:evoly/features/sync/data/sqlite_sync_outbox_repository.dart';
import 'package:evoly/features/sync/data/sqlite_sync_state_repository.dart';
import 'package:evoly/features/sync/domain/sync_models.dart';

class SyncEngine {
  const SyncEngine({
    required this.outboxRepository,
    required this.remoteRepository,
    required this.remoteChangeApplier,
    required this.syncStateRepository,
  });

  final SqliteSyncOutboxRepository outboxRepository;
  final RemoteSyncRepository remoteRepository;
  final SqliteRemoteChangeApplier remoteChangeApplier;
  final SqliteSyncStateRepository syncStateRepository;

  Future<SyncResult> syncNow() async {
    final syncEnabled = await syncStateRepository.isSyncEnabled();
    if (!syncEnabled) {
      return const SyncResult(
        pushedCount: 0,
        pulledCount: 0,
        latestRevision: 0,
        skipped: true,
        message: '未登录，同步已关闭',
      );
    }

    final pending = await outboxRepository.findPending();
    final pendingIds = pending.map((entry) => entry.id).toList();
    var pushedCount = 0;

    try {
      if (pending.isNotEmpty) {
        final pushResult = await remoteRepository.pushChanges(pending);
        pushedCount = pushResult.pushedCount;
        await outboxRepository.deleteSynced(pendingIds);
      }

      final lastPulledRevision = await _lastPulledRevision();
      final pullResult = await remoteRepository.pullChanges(
        sinceRevision: lastPulledRevision,
      );
      final applyResult = await remoteChangeApplier.applyAll(
        pullResult.changes,
      );
      final latestSafeRevision = _latestSafeRevision(
        lastPulledRevision: lastPulledRevision,
        latestRemoteRevision: pullResult.latestRevision,
        applyResult: applyResult,
      );

      await syncStateRepository.write(
        SyncStateKey.lastPulledRevision,
        latestSafeRevision.toString(),
      );
      await syncStateRepository.write(
        SyncStateKey.lastSuccessAt,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      await syncStateRepository.write(SyncStateKey.lastError, '');

      return SyncResult(
        pushedCount: pushedCount,
        pulledCount: applyResult.appliedCount,
        latestRevision: latestSafeRevision,
        skipped: false,
        message: applyResult.skippedCount == 0
            ? null
            : '同步部分完成：有 ${applyResult.skippedCount} 条子项在等待对应项目同步',
      );
    } catch (error) {
      await outboxRepository.markFailed(pendingIds, error.toString());
      await syncStateRepository.write(SyncStateKey.lastError, error.toString());
      rethrow;
    }
  }

  Future<int> _lastPulledRevision() async {
    final value = await syncStateRepository.read(
      SyncStateKey.lastPulledRevision,
    );

    return int.tryParse(value ?? '') ?? 0;
  }

  int _latestSafeRevision({
    required int lastPulledRevision,
    required int latestRemoteRevision,
    required RemoteApplyResult applyResult,
  }) {
    final firstSkippedRevision = applyResult.firstSkippedRevision;
    if (firstSkippedRevision == null) {
      return latestRemoteRevision;
    }

    final safeRevision = firstSkippedRevision - 1;
    if (safeRevision < lastPulledRevision) {
      return lastPulledRevision;
    }

    return safeRevision;
  }
}
