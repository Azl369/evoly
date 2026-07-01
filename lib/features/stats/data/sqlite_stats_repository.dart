import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/stats/data/stats_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

class SqliteStatsRepository implements StatsRepository {
  const SqliteStatsRepository(this.database);

  final AppDatabase database;

  @override
  Future<StatsSnapshot> loadWeeklySnapshot() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final weekStart =
        todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final results = await Future.wait([
      _countTasks(
        status: TaskStatus.completed,
        from: todayStart,
        to: tomorrowStart,
        timeColumn: 'completed_at',
      ),
      _countTasks(
        status: TaskStatus.completed,
        from: weekStart,
        to: weekEnd,
        timeColumn: 'completed_at',
      ),
      _countTasks(
        status: TaskStatus.postponed,
        from: todayStart,
        to: tomorrowStart,
        timeColumn: 'updated_at',
      ),
      _countTasks(
        status: TaskStatus.postponed,
        from: weekStart,
        to: weekEnd,
        timeColumn: 'updated_at',
      ),
      _countGoals(),
      _calculateStreakDays(todayStart),
      _findTasksByStatus(
        status: TaskStatus.completed,
        from: todayStart,
        to: tomorrowStart,
        timeColumn: 'completed_at',
      ),
      _findTasksByStatus(
        status: TaskStatus.completed,
        from: weekStart,
        to: weekEnd,
        timeColumn: 'completed_at',
      ),
      _findTasksByStatus(
        status: TaskStatus.postponed,
        from: todayStart,
        to: tomorrowStart,
        timeColumn: 'updated_at',
      ),
      _findTasksByStatus(
        status: TaskStatus.postponed,
        from: weekStart,
        to: weekEnd,
        timeColumn: 'updated_at',
      ),
    ]);

    final goalCounts = results[4] as _GoalCounts;

    return StatsSnapshot(
      todayCompletedTasks: results[0] as int,
      weekCompletedTasks: results[1] as int,
      todayPostponedTasks: results[2] as int,
      weekPostponedTasks: results[3] as int,
      goalCompletionRate:
          goalCounts.total == 0 ? 0 : goalCounts.completed / goalCounts.total,
      streakDays: results[5] as int,
      totalGoals: goalCounts.total,
      completedGoals: goalCounts.completed,
      todayCompletedItems: results[6] as List<StatsTaskItem>,
      weekCompletedItems: results[7] as List<StatsTaskItem>,
      todayPostponedItems: results[8] as List<StatsTaskItem>,
      weekPostponedItems: results[9] as List<StatsTaskItem>,
    );
  }

  Future<int> _countTasks({
    required TaskStatus status,
    required DateTime from,
    required DateTime to,
    required String timeColumn,
  }) async {
    final db = await database.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM tasks
      WHERE status = ?
        AND $timeColumn >= ?
        AND $timeColumn < ?
      ''',
      [
        status.name,
        AppDatabaseDateCodec.encodeDate(from),
        AppDatabaseDateCodec.encodeDate(to),
      ],
    );

    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<_GoalCounts> _countGoals() async {
    final db = await database.database;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed
      FROM goals
    ''');

    final row = rows.first;
    return _GoalCounts(
      total: (row['total'] as num?)?.toInt() ?? 0,
      completed: (row['completed'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<StatsTaskItem>> _findTasksByStatus({
    required TaskStatus status,
    required DateTime from,
    required DateTime to,
    required String timeColumn,
  }) async {
    final db = await database.database;
    final rows = await db.query(
      'tasks',
      columns: ['id', 'title', timeColumn, 'estimated_minutes'],
      where: '''
        status = ?
        AND $timeColumn >= ?
        AND $timeColumn < ?
      ''',
      whereArgs: [
        status.name,
        AppDatabaseDateCodec.encodeDate(from),
        AppDatabaseDateCodec.encodeDate(to),
      ],
      orderBy: '$timeColumn DESC',
    );

    return rows.map((row) {
      return StatsTaskItem(
        id: row['id']! as String,
        title: row['title']! as String,
        occurredAt: AppDatabaseDateCodec.decodeDate(row[timeColumn]!),
        estimatedMinutes: (row['estimated_minutes'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<int> _calculateStreakDays(DateTime todayStart) async {
    final db = await database.database;
    var streak = 0;
    var cursor = todayStart;

    while (true) {
      final nextDay = cursor.add(const Duration(days: 1));
      final rows = await db.rawQuery(
        '''
        SELECT COUNT(*) AS count
        FROM tasks
        WHERE status = ?
          AND completed_at >= ?
          AND completed_at < ?
        ''',
        [
          TaskStatus.completed.name,
          AppDatabaseDateCodec.encodeDate(cursor),
          AppDatabaseDateCodec.encodeDate(nextDay),
        ],
      );

      final count = (rows.first['count'] as num?)?.toInt() ?? 0;
      if (count == 0) {
        break;
      }

      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }
}

class _GoalCounts {
  const _GoalCounts({
    required this.total,
    required this.completed,
  });

  final int total;
  final int completed;
}
