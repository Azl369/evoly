import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/coach/data/coach_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

class SqliteCoachRepository implements CoachRepository {
  const SqliteCoachRepository(this.database);

  final AppDatabase database;

  @override
  Future<CoachTodayContext> loadTodayContext(DateTime now) async {
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final delayedFrom = todayStart.subtract(const Duration(days: 13));

    final results = await Future.wait([
      _findTodayTasks(todayStart, tomorrowStart),
      _findDelayedGoalStats(delayedFrom, tomorrowStart),
    ]);

    return CoachTodayContext(
      todayTasks: results[0] as List<CoachTaskContext>,
      delayedGoalStats: results[1] as List<CoachDelayedGoalStat>,
    );
  }

  Future<List<CoachTaskContext>> _findTodayTasks(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        tasks.id,
        tasks.goal_id,
        tasks.title,
        tasks.priority,
        tasks.status,
        tasks.estimated_minutes,
        tasks.due_date_time,
        tasks.completed_at,
        goals.title AS goal_title
      FROM tasks
      INNER JOIN goals ON goals.id = tasks.goal_id
      WHERE tasks.due_date_time >= ?
        AND tasks.due_date_time < ?
        AND tasks.status != ?
      ORDER BY
        CASE tasks.priority
          WHEN 'high' THEN 0
          WHEN 'medium' THEN 1
          ELSE 2
        END,
        tasks.due_date_time ASC
      ''',
      [
        AppDatabaseDateCodec.encodeDate(from),
        AppDatabaseDateCodec.encodeDate(to),
        TaskStatus.cancelled.name,
      ],
    );

    return rows.map((row) {
      return CoachTaskContext(
        id: row['id']! as String,
        goalId: row['goal_id']! as String,
        title: row['title']! as String,
        priority: Priority.values.byName(row['priority']! as String),
        status: TaskStatus.values.byName(row['status']! as String),
        estimatedMinutes: (row['estimated_minutes'] as num?)?.toInt() ?? 0,
        dueDateTime:
            AppDatabaseDateCodec.decodeNullableDate(row['due_date_time']),
        completedAt:
            AppDatabaseDateCodec.decodeNullableDate(row['completed_at']),
        goalTitle: row['goal_title']! as String,
      );
    }).toList();
  }

  Future<List<CoachDelayedGoalStat>> _findDelayedGoalStats(
    DateTime from,
    DateTime to,
  ) async {
    final db = await database.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        tasks.goal_id,
        goals.title AS goal_title,
        COUNT(*) AS postponed_count,
        MAX(tasks.updated_at) AS latest_postponed_at
      FROM tasks
      INNER JOIN goals ON goals.id = tasks.goal_id
      WHERE tasks.status = ?
        AND tasks.updated_at >= ?
        AND tasks.updated_at < ?
      GROUP BY tasks.goal_id, goals.title
      HAVING COUNT(*) >= 2
      ORDER BY postponed_count DESC, latest_postponed_at DESC
      LIMIT 3
      ''',
      [
        TaskStatus.postponed.name,
        AppDatabaseDateCodec.encodeDate(from),
        AppDatabaseDateCodec.encodeDate(to),
      ],
    );

    return rows.map((row) {
      return CoachDelayedGoalStat(
        goalId: row['goal_id']! as String,
        goalTitle: row['goal_title']! as String,
        postponedTaskCount: (row['postponed_count'] as num?)?.toInt() ?? 0,
        latestPostponedAt:
            AppDatabaseDateCodec.decodeDate(row['latest_postponed_at']!),
      );
    }).toList();
  }
}
