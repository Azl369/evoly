import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();

  final databasePath = _databasePath();
  final databaseFile = File(databasePath);
  if (!databaseFile.existsSync()) {
    stderr.writeln('Database not found: $databasePath');
    stderr.writeln('Run the Windows app once before seeding coverage data.');
    exitCode = 1;
    return;
  }

  final database = await databaseFactoryFfi.openDatabase(databasePath);
  try {
    await database.execute('PRAGMA foreign_keys = ON');
    await database.transaction((txn) async {
      await _clearCoverageData(txn);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final goals = _goals(now, today);
      final tasks = _tasks(now, today);
      final documents = _documents(now);
      final documentLinks = _documentLinks(now);
      final reminders = _reminders(now);

      for (final goal in goals) {
        await txn.insert(
          'goals',
          goal,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final task in tasks) {
        await txn.insert(
          'tasks',
          task,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final document in documents) {
        await txn.insert(
          'documents',
          document,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final link in documentLinks) {
        await txn.insert(
          'document_links',
          link,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final reminder in reminders) {
        await txn.insert(
          'reminders',
          reminder,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    final counts = await Future.wait([
      _count(database, 'goals'),
      _count(database, 'tasks'),
      _count(database, 'documents'),
      _count(database, 'reminders'),
    ]);

    stdout.writeln('Coverage test data injected.');
    stdout.writeln('Database: $databasePath');
    stdout.writeln('Coverage goals: ${counts[0]}');
    stdout.writeln('Coverage tasks: ${counts[1]}');
    stdout.writeln('Coverage documents: ${counts[2]}');
    stdout.writeln('Coverage reminders: ${counts[3]}');
  } finally {
    await database.close();
  }
}

String _databasePath() {
  final appData = Platform.environment['APPDATA'];
  final baseDir = appData == null || appData.isEmpty
      ? p.join(Directory.current.path, '.evoly')
      : p.join(appData, 'Evoly');
  return p.join(baseDir, 'evoly.db');
}

Future<void> _clearCoverageData(Transaction txn) async {
  await txn.delete(
    'document_links',
    where: "document_id LIKE 'coverage-%' OR target_id LIKE 'coverage-%'",
  );
  await txn.delete('reminders', where: "id LIKE 'coverage-%'");
  await txn.delete('documents', where: "id LIKE 'coverage-%'");
  await txn.delete('tasks', where: "id LIKE 'coverage-%'");
  await txn.delete('goals', where: "id LIKE 'coverage-%'");
}

Future<int> _count(Database database, String table) async {
  final rows = await database.rawQuery(
    "SELECT COUNT(*) AS count FROM $table WHERE id LIKE 'coverage-%'",
  );
  return rows.first['count']! as int;
}

List<Map<String, Object?>> _goals(DateTime now, DateTime today) {
  return [
    _goal(
      id: 'coverage-goal-launch',
      title: '发布前检查',
      description: '覆盖高优先级、今日到期、已延期和项目详情页的密集信息展示。',
      type: 'oneTime',
      priority: 'high',
      status: 'inProgress',
      startDate: today.subtract(const Duration(days: 3)),
      dueDate: today.add(const Duration(days: 1)),
      progress: 0.42,
      createdAt: now.subtract(const Duration(days: 6)),
      updatedAt: now.subtract(const Duration(minutes: 10)),
    ),
    _goal(
      id: 'coverage-goal-learning',
      title: 'Flutter 动效优化',
      description: '覆盖无截止时间任务、明天到期任务、普通优先级和长期项目。',
      type: 'longTerm',
      priority: 'medium',
      status: 'inProgress',
      startDate: today.subtract(const Duration(days: 1)),
      dueDate: today.add(const Duration(days: 21)),
      progress: 0.2,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
    ),
    _goal(
      id: 'coverage-goal-health',
      title: '晨间健康节律',
      description: '覆盖低优先级、手动延期和周期提醒。',
      type: 'recurring',
      priority: 'low',
      status: 'inProgress',
      startDate: today.subtract(const Duration(days: 14)),
      dueDate: null,
      progress: 0.3,
      createdAt: now.subtract(const Duration(days: 18)),
      updatedAt: now.subtract(const Duration(hours: 4)),
    ),
    _goal(
      id: 'coverage-goal-docs',
      title: '文档库整理',
      description: '覆盖已完成项目、文档关联和统计页完成数据。',
      type: 'longTerm',
      priority: 'high',
      status: 'completed',
      startDate: today.subtract(const Duration(days: 30)),
      dueDate: today.subtract(const Duration(days: 1)),
      progress: 1,
      createdAt: now.subtract(const Duration(days: 32)),
      updatedAt: now.subtract(const Duration(hours: 6)),
    ),
  ];
}

List<Map<String, Object?>> _tasks(DateTime now, DateTime today) {
  DateTime at(int hour, [int minute = 0]) {
    return DateTime(today.year, today.month, today.day, hour, minute);
  }

  return [
    _task(
      id: 'coverage-task-overdue-high',
      goalId: 'coverage-goal-launch',
      title: '昨天未完成：回归计划页已延期分组',
      description: '到期时间已经过去，但状态仍是待完成，UI 应自动视为已延期。',
      priority: 'high',
      status: 'pending',
      dueDateTime: at(18).subtract(const Duration(days: 1)),
      sortOrder: 1000,
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    _task(
      id: 'coverage-task-postponed-manual',
      goalId: 'coverage-goal-health',
      title: '手动延期：晨跑改成散步',
      description: '用户手动把状态改为已延期，应进入已延期分组。',
      priority: 'low',
      status: 'postponed',
      dueDateTime: at(8),
      sortOrder: 2000,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(hours: 1)),
    ),
    _task(
      id: 'coverage-task-today-high',
      goalId: 'coverage-goal-launch',
      title: '今日到期：检查同步登录流程',
      description: '高优先级今日任务，用于验证今日到期分组。',
      priority: 'high',
      status: 'pending',
      dueDateTime: at(23, 59),
      sortOrder: 3000,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(minutes: 20)),
    ),
    _task(
      id: 'coverage-task-today-medium',
      goalId: 'coverage-goal-launch',
      title: '今日到期：整理 v0.4.3 测试反馈',
      description: '中优先级今日任务，用于验证优先级分组。',
      priority: 'medium',
      status: 'pending',
      dueDateTime: at(22),
      sortOrder: 4000,
      createdAt: now.subtract(const Duration(hours: 8)),
      updatedAt: now.subtract(const Duration(minutes: 35)),
    ),
    _task(
      id: 'coverage-task-no-due',
      goalId: 'coverage-goal-learning',
      title: '无截止时间：阅读键盘动画方案',
      description: '长期推进任务，应在计划页待完成区域可见。',
      priority: 'medium',
      status: 'pending',
      dueDateTime: null,
      sortOrder: 5000,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(hours: 2)),
    ),
    _task(
      id: 'coverage-task-tomorrow',
      goalId: 'coverage-goal-learning',
      title: '明天到期：验证具体时间选择器',
      description: '用于确认明天到期不会错误进入已延期。',
      priority: 'high',
      status: 'pending',
      dueDateTime: at(10, 30).add(const Duration(days: 1)),
      sortOrder: 6000,
      createdAt: now.subtract(const Duration(hours: 5)),
      updatedAt: now.subtract(const Duration(hours: 5)),
    ),
    _task(
      id: 'coverage-task-completed-today',
      goalId: 'coverage-goal-docs',
      title: '今天已完成：补充测试说明文档',
      description: '应出现在计划页今天已完成分组。',
      priority: 'medium',
      status: 'completed',
      dueDateTime: at(11),
      completedAt: at(11, 20),
      sortOrder: 7000,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: at(11, 20),
    ),
    _task(
      id: 'coverage-task-cancelled',
      goalId: 'coverage-goal-launch',
      title: '已取消：旧版测试入口',
      description: '取消任务不应出现在计划页主要列表。',
      priority: 'low',
      status: 'cancelled',
      dueDateTime: at(15),
      sortOrder: 8000,
      createdAt: now.subtract(const Duration(days: 4)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
  ];
}

List<Map<String, Object?>> _documents(DateTime now) {
  return [
    _document(
      id: 'coverage-doc-launch-note',
      title: '测试：发布检查清单',
      contentMarkdown: '''
# 发布检查清单

- [ ] 今日到期任务按高、中、低优先级展示
- [ ] 已延期任务独立展示
- [ ] 项目详情页保留已完成子任务
- [ ] Coach 能读取即将提醒的子任务
''',
      type: 'projectNote',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(minutes: 18)),
    ),
    _document(
      id: 'coverage-doc-review',
      title: '测试：UI 重构复盘',
      contentMarkdown: '''
# UI 重构复盘

这份文档用于验证文档库、项目关联、Markdown 预览和最近更新排序。
''',
      type: 'review',
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(hours: 1)),
    ),
  ];
}

List<Map<String, Object?>> _documentLinks(DateTime now) {
  final createdAt = _ms(now);
  return [
    {
      'id': 'coverage-doc-launch-note-goal-coverage-goal-launch',
      'document_id': 'coverage-doc-launch-note',
      'target_type': 'goal',
      'target_id': 'coverage-goal-launch',
      'created_at': createdAt,
    },
    {
      'id': 'coverage-doc-review-goal-coverage-goal-learning',
      'document_id': 'coverage-doc-review',
      'target_type': 'goal',
      'target_id': 'coverage-goal-learning',
      'created_at': createdAt,
    },
  ];
}

List<Map<String, Object?>> _reminders(DateTime now) {
  return [
    _reminder(
      id: 'coverage-reminder-task-soon',
      targetType: 'task',
      targetId: 'coverage-task-today-high',
      remindAt: now.add(const Duration(minutes: 20)),
      repeatRule: 'none',
      advanceMinutes: 10,
      enabled: true,
      firedAt: null,
      createdAt: now.subtract(const Duration(hours: 1)),
      updatedAt: now.subtract(const Duration(minutes: 5)),
    ),
    _reminder(
      id: 'coverage-reminder-goal-weekly',
      targetType: 'goal',
      targetId: 'coverage-goal-health',
      remindAt: now.add(const Duration(days: 2)),
      repeatRule: 'weekly',
      advanceMinutes: 0,
      enabled: true,
      firedAt: null,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
  ];
}

Map<String, Object?> _goal({
  required String id,
  required String title,
  required String description,
  required String type,
  required String priority,
  required String status,
  required DateTime startDate,
  required DateTime? dueDate,
  required double progress,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  return {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'priority': priority,
    'status': status,
    'start_date': _ms(startDate),
    'due_date': dueDate == null ? null : _ms(dueDate),
    'progress': progress,
    'created_at': _ms(createdAt),
    'updated_at': _ms(updatedAt),
  };
}

Map<String, Object?> _task({
  required String id,
  required String goalId,
  required String title,
  required String description,
  required String priority,
  required String status,
  required DateTime? dueDateTime,
  required int sortOrder,
  required DateTime createdAt,
  required DateTime updatedAt,
  int estimatedMinutes = 0,
  DateTime? completedAt,
}) {
  return {
    'id': id,
    'goal_id': goalId,
    'title': title,
    'description': description,
    'priority': priority,
    'status': status,
    'estimated_minutes': estimatedMinutes,
    'due_date_time': dueDateTime == null ? null : _ms(dueDateTime),
    'completed_at': completedAt == null ? null : _ms(completedAt),
    'created_at': _ms(createdAt),
    'updated_at': _ms(updatedAt),
    'sort_order': sortOrder,
  };
}

Map<String, Object?> _document({
  required String id,
  required String title,
  required String contentMarkdown,
  required String type,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  return {
    'id': id,
    'title': title,
    'content_markdown': contentMarkdown,
    'type': type,
    'created_at': _ms(createdAt),
    'updated_at': _ms(updatedAt),
    'deleted_at': null,
  };
}

Map<String, Object?> _reminder({
  required String id,
  required String targetType,
  required String targetId,
  required DateTime remindAt,
  required String repeatRule,
  required int advanceMinutes,
  required bool enabled,
  required DateTime? firedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  return {
    'id': id,
    'target_type': targetType,
    'target_id': targetId,
    'remind_at': _ms(remindAt),
    'repeat_rule': repeatRule,
    'advance_minutes': advanceMinutes,
    'enabled': enabled ? 1 : 0,
    'fired_at': firedAt == null ? null : _ms(firedAt),
    'created_at': _ms(createdAt),
    'updated_at': _ms(updatedAt),
  };
}

int _ms(DateTime value) => value.millisecondsSinceEpoch;
