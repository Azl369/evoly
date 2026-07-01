import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/goals/data/goal_mapper.dart';
import 'package:evoly/features/goals/data/goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';

class SqliteGoalRepository implements GoalRepository {
  const SqliteGoalRepository(this.database);

  final AppDatabase database;

  @override
  Future<List<Goal>> findAll() async {
    final db = await database.database;
    final rows = await db.rawQuery('''
      SELECT
        g.*,
        COALESCE(
          CAST(SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) AS REAL)
          / NULLIF(COUNT(t.id), 0),
          g.progress
        ) AS calculated_progress
      FROM goals g
      LEFT JOIN tasks t ON t.goal_id = g.id AND t.status != 'cancelled'
      GROUP BY g.id
      ORDER BY g.updated_at DESC
    ''');

    return rows.map((row) {
      return GoalMapper.fromMap({
        ...row,
        'progress': row['calculated_progress'] ?? row['progress'],
      });
    }).toList();
  }

  @override
  Future<Goal?> findById(String id) async {
    final db = await database.database;
    final rows = await db.query(
      'goals',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return GoalMapper.fromMap(rows.first);
  }

  @override
  Future<void> save(Goal goal) async {
    final db = await database.database;
    await db.insert(
      'goals',
      GoalMapper.toMap(goal),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await database.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }
}
