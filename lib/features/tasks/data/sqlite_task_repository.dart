import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/tasks/data/task_mapper.dart';
import 'package:evoly/features/tasks/data/task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

class SqliteTaskRepository implements TaskRepository {
  const SqliteTaskRepository(this.database);

  final AppDatabase database;

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
      orderBy: 'due_date_time ASC, priority DESC',
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
        due_date_time ASC
      ''',
    );

    return rows.map(TaskMapper.fromMap).toList();
  }

  @override
  Future<void> save(TaskItem task) async {
    final db = await database.database;
    await db.insert(
      'tasks',
      TaskMapper.toMap(task),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await database.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
