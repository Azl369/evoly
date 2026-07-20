import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/sync/application/sync_change_recorder.dart';
import 'package:evoly/features/tasks/data/task_mapper.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

class SqliteTaskRepository implements TaskRepository {
  const SqliteTaskRepository(
    this.database, {
    this.changeRecorder,
  });

  final AppDatabase database;
  final SyncChangeRecorder? changeRecorder;

  @override
  Future<TaskItem?> findById(String id) async {
    final db = await database.database;
    final rows = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return TaskMapper.fromMap(rows.first);
  }

  @override
  Future<List<TaskItem>> findByGoalId(String goalId) async {
    final db = await database.database;
    final rows = await db.query(
      'tasks',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: '''
        CASE priority
          WHEN 'high' THEN 0
          WHEN 'medium' THEN 1
          ELSE 2
        END,
        sort_order ASC,
        due_date_time ASC,
        created_at ASC
      ''',
    );

    return rows.map(TaskMapper.fromMap).toList();
  }

  @override
  Future<List<TaskItem>> findDueToday(DateTime today) async {
    final db = await database.database;
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final rows = await db.query(
      'tasks',
      where: '''
        due_date_time >= ?
        AND due_date_time < ?
        AND status != ?
      ''',
      whereArgs: [
        AppDatabaseDateCodec.encodeDate(start),
        AppDatabaseDateCodec.encodeDate(end),
        TaskStatus.cancelled.name,
      ],
      orderBy: '''
        CASE priority
          WHEN 'high' THEN 0
          WHEN 'medium' THEN 1
          ELSE 2
        END,
        sort_order ASC,
        due_date_time ASC,
        created_at ASC
      ''',
    );

    return rows.map(TaskMapper.fromMap).toList();
  }

  @override
  Future<List<TaskItem>> findPlanningCandidates(DateTime today) async {
    final db = await database.database;
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final weekEnd = start.add(Duration(days: 8 - start.weekday));

    final rows = await db.query(
      'tasks',
      where: '''
        status NOT IN (?, ?)
        AND (
          due_date_time IS NULL
          OR due_date_time < ?
          OR (due_date_time >= ? AND due_date_time < ?)
          OR status = ?
        )
      ''',
      whereArgs: [
        TaskStatus.completed.name,
        TaskStatus.cancelled.name,
        AppDatabaseDateCodec.encodeDate(end),
        AppDatabaseDateCodec.encodeDate(end),
        AppDatabaseDateCodec.encodeDate(weekEnd),
        TaskStatus.postponed.name,
      ],
      orderBy: '''
        CASE
          WHEN due_date_time IS NULL THEN 1
          ELSE 0
        END,
        CASE priority
          WHEN 'high' THEN 0
          WHEN 'medium' THEN 1
          ELSE 2
        END,
        sort_order ASC,
        due_date_time ASC,
        created_at ASC
      ''',
    );

    return rows.map(TaskMapper.fromMap).toList();
  }

  @override
  Future<TaskItem?> findRepeatOccurrence({
    required String repeatSeriesId,
    required DateTime dueDateTime,
  }) async {
    final db = await database.database;
    final rows = await db.query(
      'tasks',
      where: 'repeat_series_id = ? AND due_date_time = ?',
      whereArgs: [
        repeatSeriesId,
        AppDatabaseDateCodec.encodeDate(dueDateTime),
      ],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return TaskMapper.fromMap(rows.first);
  }

  @override
  Future<List<TaskItem>> findCompletedToday(DateTime today) async {
    final db = await database.database;
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final rows = await db.query(
      'tasks',
      where: '''
        status = ?
        AND completed_at >= ?
        AND completed_at < ?
      ''',
      whereArgs: [
        TaskStatus.completed.name,
        AppDatabaseDateCodec.encodeDate(start),
        AppDatabaseDateCodec.encodeDate(end),
      ],
      orderBy: '''
        completed_at DESC,
        CASE priority
          WHEN 'high' THEN 0
          WHEN 'medium' THEN 1
          ELSE 2
        END,
        sort_order ASC,
        created_at ASC
      ''',
    );

    return rows.map(TaskMapper.fromMap).toList();
  }

  @override
  Future<void> save(TaskItem task) async {
    final db = await database.database;
    final payload = TaskMapper.toMap(
      task.sortOrder == 0
          ? task.copyWith(sortOrder: await _nextSortOrder(task.priority))
          : task,
    );
    await db.insert(
      'tasks',
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await changeRecorder?.recordUpsert(
      entityType: SyncEntityType.task,
      entityId: task.id,
      payload: payload,
    );
  }

  @override
  Future<void> reorderWithinPriority({
    required Priority priority,
    required List<String> orderedTaskIds,
  }) async {
    if (orderedTaskIds.isEmpty) {
      return;
    }

    final db = await database.database;
    final now = AppDatabaseDateCodec.encodeDate(DateTime.now());
    final updates = <Map<String, Object?>>[];
    final placeholders = List.filled(orderedTaskIds.length, '?').join(', ');
    final existingRows = await db.query(
      'tasks',
      where: 'id IN ($placeholders) AND priority = ?',
      whereArgs: [...orderedTaskIds, priority.name],
    );
    final taskById = {
      for (final row in existingRows)
        row['id']! as String: TaskMapper.fromMap(row)
    };

    await db.transaction((transaction) async {
      for (var index = 0; index < orderedTaskIds.length; index += 1) {
        final task = taskById[orderedTaskIds[index]];
        if (task == null) {
          continue;
        }

        final updatedTask = task.copyWith(
          sortOrder: (index + 1) * 1000,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
        );
        final payload = TaskMapper.toMap(updatedTask);
        updates.add(payload);
        await transaction.update(
          'tasks',
          payload,
          where: 'id = ?',
          whereArgs: [task.id],
        );
      }
    });

    for (final payload in updates) {
      await changeRecorder?.recordUpsert(
        entityType: SyncEntityType.task,
        entityId: payload['id']! as String,
        payload: payload,
      );
    }
  }

  Future<int> _nextSortOrder(Priority priority) async {
    final db = await database.database;
    final rows = await db.rawQuery(
      '''
      SELECT MAX(sort_order) AS max_sort_order
      FROM tasks
      WHERE priority = ?
      ''',
      [priority.name],
    );
    final maxSortOrder =
        rows.isEmpty ? null : rows.first['max_sort_order'] as int?;
    return (maxSortOrder ?? 0) + 1000;
  }

  @override
  Future<void> delete(String id) async {
    final db = await database.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    await changeRecorder?.recordDelete(
      entityType: SyncEntityType.task,
      entityId: id,
    );
  }
}
