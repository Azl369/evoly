import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:evoly/core/database/app_database.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/sync/application/sync_change_recorder.dart';
import 'package:evoly/features/goals/data/sqlite_goal_repository.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/tasks/data/sqlite_task_repository.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

void main() {
  test(
      'findPlanningCandidates includes due and long-running pending tasks only',
      () async {
    final directory = await Directory.systemTemp.createTemp('evoly-tasks-');
    final database = AppDatabase.testing(p.join(directory.path, 'evoly.db'));
    final goalRepository = SqliteGoalRepository(database);
    final taskRepository = SqliteTaskRepository(database);
    final db = await database.database;
    await db.delete('tasks');
    await db.delete('goals');
    addTearDown(() async {
      await database.close();
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final now = DateTime(2026, 7, 6, 10);
    await goalRepository.save(
      Goal(
        id: 'goal-plan',
        title: '计划页测试项目',
        type: GoalType.longTerm,
        priority: Priority.high,
        status: GoalStatus.inProgress,
        startDate: now.subtract(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await Future.wait([
      taskRepository.save(
        _task(
          id: 'overdue',
          title: '逾期任务',
          priority: Priority.high,
          dueDateTime: DateTime(2026, 7, 5, 18),
          now: now,
        ),
      ),
      taskRepository.save(
        _task(
          id: 'today',
          title: '今日到期任务',
          priority: Priority.medium,
          dueDateTime: DateTime(2026, 7, 6, 18),
          now: now,
        ),
      ),
      taskRepository.save(
        _task(
          id: 'long-running',
          title: '无截止任务',
          priority: Priority.low,
          now: now,
        ),
      ),
      taskRepository.save(
        _task(
          id: 'future',
          title: '未来任务',
          priority: Priority.high,
          dueDateTime: DateTime(2026, 7, 7, 9),
          now: now,
        ),
      ),
      taskRepository.save(
        _task(
          id: 'completed-long-running',
          title: '已完成无截止任务',
          priority: Priority.high,
          status: TaskStatus.completed,
          completedAt: now,
          now: now,
        ),
      ),
      taskRepository.save(
        _task(
          id: 'cancelled-long-running',
          title: '已取消无截止任务',
          priority: Priority.high,
          status: TaskStatus.cancelled,
          now: now,
        ),
      ),
    ]);

    final results = await taskRepository.findPlanningCandidates(now);

    expect(results.map((task) => task.id), [
      'overdue',
      'today',
      'long-running',
    ]);
  });

  test('findCompletedToday returns tasks completed during the current day',
      () async {
    final directory = await Directory.systemTemp.createTemp('evoly-tasks-');
    final database = AppDatabase.testing(p.join(directory.path, 'evoly.db'));
    final goalRepository = SqliteGoalRepository(database);
    final taskRepository = SqliteTaskRepository(database);
    final db = await database.database;
    await db.delete('tasks');
    await db.delete('goals');
    addTearDown(() async {
      await database.close();
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final now = DateTime(2026, 7, 6, 10);
    await goalRepository.save(
      Goal(
        id: 'goal-plan',
        title: '计划页完成项测试项目',
        type: GoalType.longTerm,
        priority: Priority.high,
        status: GoalStatus.inProgress,
        startDate: now.subtract(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await Future.wait([
      taskRepository.save(
        _task(
          id: 'completed-late',
          title: '稍后完成',
          priority: Priority.medium,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 6, 18),
          now: now,
        ),
      ),
      taskRepository.save(
        _task(
          id: 'completed-early',
          title: '较早完成',
          priority: Priority.high,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 6, 9),
          now: now,
        ),
      ),
      taskRepository.save(
        _task(
          id: 'completed-yesterday',
          title: '昨天完成',
          priority: Priority.high,
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 7, 5, 21),
          now: now,
        ),
      ),
      taskRepository.save(
        _task(
          id: 'pending',
          title: '待完成',
          priority: Priority.high,
          now: now,
        ),
      ),
    ]);

    final results = await taskRepository.findCompletedToday(now);

    expect(results.map((task) => task.id), [
      'completed-late',
      'completed-early',
    ]);
  });

  test('saves and reorders tasks within the same priority', () async {
    final directory = await Directory.systemTemp.createTemp('evoly-tasks-');
    final database = AppDatabase.testing(p.join(directory.path, 'evoly.db'));
    final goalRepository = SqliteGoalRepository(database);
    final taskRepository = SqliteTaskRepository(
      database,
      changeRecorder: SyncChangeRecorder(database),
    );
    final db = await database.database;
    await db.delete('sync_outbox');
    await db.delete('tasks');
    await db.delete('goals');
    addTearDown(() async {
      await database.close();
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final now = DateTime(2026, 7, 6, 10);
    await goalRepository.save(
      Goal(
        id: 'goal-plan',
        title: 'Plan test goal',
        type: GoalType.longTerm,
        priority: Priority.high,
        status: GoalStatus.inProgress,
        startDate: now.subtract(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await taskRepository.save(
      _task(
        id: 'first',
        title: 'First',
        priority: Priority.high,
        dueDateTime: DateTime(2026, 7, 6, 18),
        sortOrder: 1000,
        now: now,
      ),
    );
    await taskRepository.save(
      _task(
        id: 'second',
        title: 'Second',
        priority: Priority.high,
        dueDateTime: DateTime(2026, 7, 6, 12),
        sortOrder: 2000,
        now: now,
      ),
    );
    await taskRepository.save(
      _task(
        id: 'medium',
        title: 'Medium',
        priority: Priority.medium,
        dueDateTime: DateTime(2026, 7, 6, 8),
        sortOrder: 1000,
        now: now,
      ),
    );

    await db.delete('sync_outbox');
    await taskRepository.reorderWithinPriority(
      priority: Priority.high,
      orderedTaskIds: ['second', 'first', 'medium'],
    );

    final results = await taskRepository.findPlanningCandidates(now);

    expect(results.map((task) => task.id), ['second', 'first', 'medium']);
    expect(results.first.sortOrder, 1000);
    expect(results[1].sortOrder, 2000);
    expect(results[2].priority, Priority.medium);

    final outboxRows = await db.query(
      'sync_outbox',
      orderBy: 'created_at ASC',
    );
    expect(outboxRows, hasLength(2));
    final payloads = outboxRows
        .map((row) =>
            jsonDecode(row['payload_json']! as String) as Map<String, Object?>)
        .toList();
    expect(payloads.map((payload) => payload['id']), ['second', 'first']);
    expect(payloads.map((payload) => payload['sort_order']), [1000, 2000]);
  });
}

TaskItem _task({
  required String id,
  required String title,
  required Priority priority,
  required DateTime now,
  TaskStatus status = TaskStatus.pending,
  DateTime? dueDateTime,
  DateTime? completedAt,
  int sortOrder = 0,
}) {
  return TaskItem(
    id: id,
    goalId: 'goal-plan',
    title: title,
    priority: priority,
    status: status,
    estimatedMinutes: 20,
    dueDateTime: dueDateTime,
    completedAt: completedAt,
    createdAt: now,
    updatedAt: now,
    sortOrder: sortOrder,
  );
}
