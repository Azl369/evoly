import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/sync/application/sync_change_recorder.dart';
import 'package:evoly/features/sync/data/sqlite_sync_state_repository.dart';

class SyncInitialSnapshotQueue {
  const SyncInitialSnapshotQueue({
    required this.database,
    required this.changeRecorder,
    required this.syncStateRepository,
  });

  final AppDatabase database;
  final SyncChangeRecorder changeRecorder;
  final SqliteSyncStateRepository syncStateRepository;

  Future<void> queueForAccount(String accountId) async {
    final stateKey = SyncStateKey.initialSnapshotQueued(accountId);
    final alreadyQueued = await syncStateRepository.read(stateKey);
    if (alreadyQueued == 'true') {
      return;
    }

    final referencedGoalIds = await _findReferencedGoalIds();
    await _queueGoals(referencedGoalIds: referencedGoalIds);
    await _queueDocuments();
    await _queueTasks();
    await _queueReminders();
    await _queueDocumentLinks();
    await syncStateRepository.write(stateKey, 'true');
  }

  Future<void> _queueGoals({required Set<String> referencedGoalIds}) async {
    final db = await database.database;
    final rows = await db.query('goals', orderBy: 'updated_at ASC');

    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null ||
          (_isUntouchedDefaultSeedGoal(row) &&
              !referencedGoalIds.contains(id))) {
        continue;
      }

      await changeRecorder.recordUpsert(
        entityType: SyncEntityType.goal,
        entityId: id,
        payload: Map<String, Object?>.from(row),
      );
    }
  }

  Future<void> _queueDocuments() async {
    final db = await database.database;
    final rows = await db.query('documents', orderBy: 'updated_at ASC');

    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) {
        continue;
      }

      await changeRecorder.recordUpsert(
        entityType: SyncEntityType.document,
        entityId: id,
        payload: Map<String, Object?>.from(row),
      );
    }
  }

  Future<void> _queueTasks() async {
    final db = await database.database;
    final rows = await db.query('tasks', orderBy: 'updated_at ASC');

    for (final row in rows) {
      final id = row['id'] as String?;
      final goalId = row['goal_id'] as String?;
      if (id == null || goalId == null || _isUntouchedDefaultSeedTask(row)) {
        continue;
      }

      await changeRecorder.recordUpsert(
        entityType: SyncEntityType.task,
        entityId: id,
        payload: Map<String, Object?>.from(row),
      );
    }
  }

  Future<void> _queueReminders() async {
    final db = await database.database;
    final rows = await db.query('reminders', orderBy: 'updated_at ASC');

    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) {
        continue;
      }

      await changeRecorder.recordUpsert(
        entityType: SyncEntityType.reminder,
        entityId: id,
        payload: Map<String, Object?>.from(row),
      );
    }
  }

  Future<void> _queueDocumentLinks() async {
    final db = await database.database;
    final rows = await db.query(
      'document_links',
      orderBy: 'document_id ASC, created_at ASC',
    );
    final goalIdsByDocument = <String, Set<String>>{};

    for (final row in rows) {
      final documentId = row['document_id'] as String?;
      final targetType = row['target_type'] as String?;
      final targetId = row['target_id'] as String?;
      if (documentId == null || targetType != 'goal' || targetId == null) {
        continue;
      }

      goalIdsByDocument.putIfAbsent(documentId, () => <String>{}).add(targetId);
    }

    final now = AppDatabaseDateCodec.encodeDate(DateTime.now());
    for (final entry in goalIdsByDocument.entries) {
      await changeRecorder.recordUpsert(
        entityType: SyncEntityType.documentLinks,
        entityId: entry.key,
        payload: {
          'document_id': entry.key,
          'target_type': 'goal',
          'goal_ids': entry.value.toList(),
          'updated_at': now,
        },
      );
    }
  }

  Future<Set<String>> _findReferencedGoalIds() async {
    final db = await database.database;
    final goalIds = <String>{};

    final taskRows = await db.query('tasks');
    final taskGoalIds = <String, String>{};
    for (final row in taskRows) {
      final taskId = row['id'] as String?;
      final goalId = row['goal_id'] as String?;
      if (taskId == null || goalId == null) {
        continue;
      }

      taskGoalIds[taskId] = goalId;
      if (!_isUntouchedDefaultSeedTask(row)) {
        goalIds.add(goalId);
      }
    }

    final reminderRows = await db.query('reminders');
    for (final row in reminderRows) {
      final targetType = row['target_type'] as String?;
      final targetId = row['target_id'] as String?;
      if (targetType == 'goal' && targetId != null) {
        goalIds.add(targetId);
      } else if (targetType == 'task' && targetId != null) {
        final taskGoalId = taskGoalIds[targetId];
        if (taskGoalId != null) {
          goalIds.add(taskGoalId);
        }
      }
    }

    final linkRows = await db.query('document_links');
    for (final row in linkRows) {
      final targetType = row['target_type'] as String?;
      final targetId = row['target_id'] as String?;
      if (targetType == 'goal' && targetId != null) {
        goalIds.add(targetId);
      }
    }

    return goalIds;
  }

  bool _isUntouchedDefaultSeedGoal(Map<String, Object?> row) {
    final id = row['id'] as String?;
    return id != null && _isDefaultSeedGoalId(id) && _hasSameTimestamps(row);
  }

  bool _isUntouchedDefaultSeedTask(Map<String, Object?> row) {
    final id = row['id'] as String?;
    return id != null && _isDefaultSeedTaskId(id) && _hasSameTimestamps(row);
  }

  bool _hasSameTimestamps(Map<String, Object?> row) {
    final createdAt = row['created_at'];
    final updatedAt = row['updated_at'];
    return createdAt != null && createdAt == updatedAt;
  }

  bool _isDefaultSeedGoalId(String id) {
    return id.startsWith('goal-');
  }

  bool _isDefaultSeedTaskId(String id) {
    return id.startsWith('task-');
  }
}
