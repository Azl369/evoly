import 'package:evoly/app/data_refresh_controller.dart';
import 'package:evoly/features/sync/application/sync_engine.dart';
import 'package:evoly/features/sync/domain/sync_models.dart';

class SyncCoordinator {
  SyncCoordinator({
    required this.syncEngine,
    required this.dataRefreshController,
  });

  final SyncEngine syncEngine;
  final DataRefreshController dataRefreshController;
  Future<SyncResult>? _inFlightSync;

  Future<SyncResult> syncNow() {
    final activeSync = _inFlightSync;
    if (activeSync != null) {
      return activeSync;
    }

    final sync = _runSync();
    _inFlightSync = sync;
    return sync.whenComplete(() {
      if (identical(_inFlightSync, sync)) {
        _inFlightSync = null;
      }
    });
  }

  Future<SyncResult> _runSync() async {
    final result = await syncEngine.syncNow();
    if (!result.skipped && (result.pulledCount > 0 || result.pushedCount > 0)) {
      dataRefreshController.markChanged();
    }

    return result;
  }
}
