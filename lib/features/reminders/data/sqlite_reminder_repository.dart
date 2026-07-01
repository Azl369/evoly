import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/features/reminders/data/reminder_mapper.dart';
import 'package:evoly/features/reminders/data/reminder_repository.dart';
import 'package:evoly/features/reminders/domain/reminder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SqliteReminderRepository implements ReminderRepository {
  const SqliteReminderRepository(this.database);

  final AppDatabase database;

  @override
  Future<List<Reminder>> findEnabled() async {
    final db = await database.database;
    final rows = await db.query(
      'reminders',
      where: 'enabled = 1',
      orderBy: 'remind_at ASC',
    );

    return rows.map(ReminderMapper.fromMap).toList();
  }

  @override
  Future<List<Reminder>> findUpcoming(DateTime from, DateTime to) async {
    final db = await database.database;
    final rows = await db.query(
      'reminders',
      where: 'enabled = 1 AND remind_at >= ? AND remind_at < ?',
      whereArgs: [
        AppDatabaseDateCodec.encodeDate(from),
        AppDatabaseDateCodec.encodeDate(to),
      ],
      orderBy: 'remind_at ASC',
    );

    return rows.map(ReminderMapper.fromMap).toList();
  }

  @override
  Future<List<Reminder>> findDue(DateTime now) async {
    final db = await database.database;
    final rows = await db.query(
      'reminders',
      where: '''
        enabled = 1
        AND fired_at IS NULL
        AND remind_at <= ?
      ''',
      whereArgs: [AppDatabaseDateCodec.encodeDate(now)],
      orderBy: 'remind_at ASC',
    );

    return rows.map(ReminderMapper.fromMap).toList();
  }

  @override
  Future<Reminder?> findByTaskId(String taskId) async {
    final db = await database.database;
    final rows = await db.query(
      'reminders',
      where: 'target_type = ? AND target_id = ? AND enabled = 1',
      whereArgs: [ReminderTargetType.task.name, taskId],
      orderBy: 'remind_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return ReminderMapper.fromMap(rows.first);
  }

  @override
  Future<void> save(Reminder reminder) async {
    final db = await database.database;
    await db.insert(
      'reminders',
      ReminderMapper.toMap(reminder),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> disable(String id) async {
    final db = await database.database;
    await db.update(
      'reminders',
      {
        'enabled': 0,
        'updated_at': AppDatabaseDateCodec.encodeDate(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> disableForTask(String taskId) async {
    final db = await database.database;
    await db.update(
      'reminders',
      {
        'enabled': 0,
        'updated_at': AppDatabaseDateCodec.encodeDate(DateTime.now()),
      },
      where: 'target_type = ? AND target_id = ?',
      whereArgs: [ReminderTargetType.task.name, taskId],
    );
  }

  @override
  Future<void> markFired(String id, DateTime firedAt) async {
    final db = await database.database;
    await db.update(
      'reminders',
      {
        'fired_at': AppDatabaseDateCodec.encodeDate(firedAt),
        'updated_at': AppDatabaseDateCodec.encodeDate(firedAt),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
