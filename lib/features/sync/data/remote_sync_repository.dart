import 'package:evoly/features/sync/domain/sync_models.dart';

abstract interface class RemoteSyncRepository {
  Future<PushResult> pushChanges(List<SyncOutboxEntry> changes);

  Future<PullResult> pullChanges({required int sinceRevision});
}
