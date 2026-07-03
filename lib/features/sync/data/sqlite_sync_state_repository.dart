import 'package:evoly/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SyncStateKey {
  const SyncStateKey._();

  static const syncEnabled = 'sync_enabled';
  static const accountId = 'account_id';
  static const lastPulledRevision = 'last_pulled_revision';
  static const lastSuccessAt = 'last_success_at';
  static const lastError = 'last_error';

  static String initialSnapshotQueued(String accountId) {
    return 'initial_snapshot_queued_$accountId';
  }
}

class SqliteSyncStateRepository {
  const SqliteSyncStateRepository(this.database);

  final AppDatabase database;

  Future<String?> read(String key) async {
    final db = await database.database;
    final rows = await db.query(
      'sync_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value']! as String;
  }

  Future<void> write(String key, String value) async {
    final db = await database.database;
    await db.insert(
      'sync_state',
      {
        'key': key,
        'value': value,
        'updated_at': AppDatabaseDateCodec.encodeDate(DateTime.now()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setSyncEnabled(bool enabled) {
    return write(SyncStateKey.syncEnabled, enabled ? 'true' : 'false');
  }

  Future<bool> isSyncEnabled() async {
    final value = await read(SyncStateKey.syncEnabled);
    return value == 'true';
  }
}
